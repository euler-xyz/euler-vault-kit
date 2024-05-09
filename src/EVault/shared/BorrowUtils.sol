// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Base} from "./Base.sol";
import {DToken} from "../DToken.sol";
import {IIRM} from "../../InterestRateModels/IIRM.sol";

import "./types/Types.sol";

/// @title BorrowUtils
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Utilities for tracking debt and interest rates
abstract contract BorrowUtils is Base {
    using TypesLib for uint256;

    function getCurrentOwed(VaultCache memory vaultCache, address account, Owed owed) internal view returns (Owed) {
        // Don't bother loading the user's accumulator
        if (owed.isZero()) return Owed.wrap(0);

        // Can't divide by 0 here: If owed is non-zero, we must've initialized the user's interestAccumulator
        return owed.mulDiv(vaultCache.interestAccumulator, vaultStorage.users[account].interestAccumulator);
    }

    function getCurrentOwed(VaultCache memory vaultCache, address account) internal view returns (Owed) {
        return getCurrentOwed(vaultCache, account, vaultStorage.users[account].getOwed());
    }

    function loadUserBorrow(VaultCache memory vaultCache, address account)
        private
        view
        returns (Owed newOwed, Owed prevOwed)
    {
        prevOwed = vaultStorage.users[account].getOwed();
        newOwed = getCurrentOwed(vaultCache, account, prevOwed);
    }

    function setUserBorrow(VaultCache memory vaultCache, address account, Owed newOwed) private {
        UserStorage storage user = vaultStorage.users[account];

        user.setOwed(newOwed);
        user.interestAccumulator = vaultCache.interestAccumulator;
    }

    function increaseBorrow(VaultCache memory vaultCache, address account, Assets assets) internal virtual {
        (Owed owed, Owed prevOwed) = loadUserBorrow(vaultCache, account);

        Owed amount = assets.toOwed();
        Owed newOwed = owed + amount;

        setUserBorrow(vaultCache, account, newOwed);
        vaultStorage.totalBorrows = vaultCache.totalBorrows = vaultCache.totalBorrows + amount;

        logBorrowChange(account, prevOwed, owed, newOwed);
    }

    function decreaseBorrow(VaultCache memory vaultCache, address account, Assets amount) internal virtual {
        (Owed owedExact, Owed prevOwed) = loadUserBorrow(vaultCache, account);
        Assets owed = owedExact.toAssetsUp();

        if (amount > owed) revert E_RepayTooMuch();

        Owed owedRemaining = owed.subUnchecked(amount).toOwed();

        setUserBorrow(vaultCache, account, owedRemaining);
        vaultStorage.totalBorrows = vaultCache.totalBorrows =
            vaultCache.totalBorrows > owedExact ? vaultCache.totalBorrows - owedExact + owedRemaining : owedRemaining;

        logBorrowChange(account, prevOwed, owed.toOwed(), owedRemaining);
    }

    function transferBorrow(VaultCache memory vaultCache, address from, address to, Assets assets) internal virtual {
        Owed amount = assets.toOwed();

        (Owed fromOwed, Owed fromOwedPrev) = loadUserBorrow(vaultCache, from);
        (Owed toOwed, Owed toOwedPrev) = loadUserBorrow(vaultCache, to);

        // If amount was rounded up, or dust is left over, transfer exact amount owed
        if ((amount > fromOwed && (amount - fromOwed).isDust()) || (amount < fromOwed && (fromOwed - amount).isDust()))
        {
            amount = fromOwed;
        }

        if (amount > fromOwed) revert E_InsufficientBalance();

        Owed newfromOwed = fromOwed.subUnchecked(amount);
        Owed newToOwed = toOwed + amount;

        setUserBorrow(vaultCache, from, newfromOwed);
        setUserBorrow(vaultCache, to, newToOwed);

        logBorrowChange(from, fromOwedPrev, fromOwed, newfromOwed);
        logBorrowChange(to, toOwedPrev, toOwed, newToOwed);
    }

    function computeInterestRate(VaultCache memory vaultCache) internal virtual returns (uint256) {
        // single sload
        address irm = vaultStorage.interestRateModel;
        uint256 newInterestRate = vaultStorage.interestRate;

        if (irm != address(0)) {
            (bool success, bytes memory data) = irm.call(
                abi.encodeCall(
                    IIRM.computeInterestRate,
                    (address(this), vaultCache.cash.toUint(), vaultCache.totalBorrows.toAssetsUp().toUint())
                )
            );

            if (success && data.length >= 32) {
                newInterestRate = abi.decode(data, (uint256));
                if (newInterestRate > MAX_ALLOWED_INTEREST_RATE) newInterestRate = MAX_ALLOWED_INTEREST_RATE;
                vaultStorage.interestRate = uint72(newInterestRate);
            }
        }

        return newInterestRate;
    }

    function computeInterestRateView(VaultCache memory vaultCache) internal view virtual returns (uint256) {
        // single sload
        address irm = vaultStorage.interestRateModel;
        uint256 newInterestRate = vaultStorage.interestRate;

        if (irm != address(0) && isVaultStatusCheckDeferred()) {
            (bool success, bytes memory data) = irm.staticcall(
                abi.encodeCall(
                    IIRM.computeInterestRateView,
                    (address(this), vaultCache.cash.toUint(), vaultCache.totalBorrows.toAssetsUp().toUint())
                )
            );

            if (success && data.length >= 32) {
                newInterestRate = abi.decode(data, (uint256));
                if (newInterestRate > MAX_ALLOWED_INTEREST_RATE) newInterestRate = MAX_ALLOWED_INTEREST_RATE;
            }
        }

        return newInterestRate;
    }

    function getDToken() internal view virtual returns (DToken dToken) {
        // inspired by https://github.com/Vectorized/solady/blob/229c18cfcdcd474f95c30ad31b0f7d428ee8a31a/src/utils/CREATE3.sol#L82-L90
        assembly ("memory-safe") {
            mstore(0x14, address())
            // 0xd6 = 0xc0 (short RLP prefix) + 0x16 (length of: 0x94 ++ address(this) ++ 0x01).
            // 0x94 = 0x80 + 0x14 (0x14 = the length of an address, 20 bytes, in hex).
            mstore(0x00, 0xd694)
            // Nonce of the contract when DToken was deployed (1).
            mstore8(0x34, 0x01)

            dToken := keccak256(0x1e, 0x17)
        }
    }

    function logBorrowChange(address account, Owed prevOwed, Owed owed, Owed newOwed) private {
        (bool increased, uint256 amount) = debtDiff(owed, newOwed);
        if (amount > 0) {
            if (increased) {
                emit Borrow(account, owed.toAssetsUp().toUint(), amount);
            } else {
                emit Repay(account, owed.toAssetsUp().toUint(), amount);
            }
        }

        (increased, amount) = debtDiff(prevOwed, newOwed);
        if (amount > 0) {
            if (increased) {
                getDToken().emitTransfer(address(0), account, amount);
            } else {
                getDToken().emitTransfer(account, address(0), amount);
            }
        }
    }

    function debtDiff(Owed a, Owed b) internal pure returns (bool increased, uint256 amount) {
        return b > a
            ? (true, b.toAssetsUp().subUnchecked(a.toAssetsUp()).toUint())
            : (false, a.toAssetsUp().subUnchecked(b.toAssetsUp()).toUint());
    }
}
