// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Base} from "./Base.sol";
import {DToken} from "../DToken.sol";
import {IIRM} from "../../interestRateModels/IIRM.sol";

import "./types/Types.sol";

abstract contract BorrowUtils is Base {
    using TypesLib for uint256;

    function getCurrentOwed(MarketCache memory marketCache, address account, Owed owed) internal view returns (Owed) {
        // Don't bother loading the user's accumulator
        if (owed.isZero()) return Owed.wrap(0);

        // Can't divide by 0 here: If owed is non-zero, we must've initialized the user's interestAccumulator
        return owed.mulDiv(marketCache.interestAccumulator, marketStorage.users[account].interestAccumulator);
    }

    function getCurrentOwed(MarketCache memory marketCache, address account) internal view returns (Owed) {
        return getCurrentOwed(marketCache, account, marketStorage.users[account].getOwed());
    }

    function updateUserBorrow(MarketCache memory marketCache, address account)
        private
        returns (Owed newOwed, Owed prevOwed)
    {
        prevOwed = marketStorage.users[account].getOwed();
        newOwed = getCurrentOwed(marketCache, account, prevOwed);

        marketStorage.users[account].setOwed(newOwed);
        marketStorage.users[account].interestAccumulator = marketCache.interestAccumulator;
    }

    function increaseBorrow(MarketCache memory marketCache, address account, Assets assets) internal {
        (Owed owed, Owed prevOwed) = updateUserBorrow(marketCache, account);

        Owed amount = assets.toOwed();
        owed = owed + amount;

        marketStorage.users[account].setOwed(owed);
        marketStorage.totalBorrows = marketCache.totalBorrows = marketCache.totalBorrows + amount;

        logBorrowChange(account, prevOwed, owed);
    }

    function decreaseBorrow(MarketCache memory marketCache, address account, Assets amount) internal {
        (Owed owedExact, Owed prevOwed) = updateUserBorrow(marketCache, account);
        Assets owed = owedExact.toAssetsUp();

        if (amount > owed) revert E_RepayTooMuch();

        Owed owedRemaining;
        unchecked {
            owedRemaining = (owed - amount).toOwed();
        }

        marketStorage.users[account].setOwed(owedRemaining);
        marketStorage.totalBorrows = marketCache.totalBorrows = marketCache.totalBorrows > owedExact 
            ? marketCache.totalBorrows - owedExact + owedRemaining 
            : owedRemaining;

        logBorrowChange(account, prevOwed, owedRemaining);
    }

    function transferBorrow(MarketCache memory marketCache, address from, address to, Assets assets) internal {
        Owed amount = assets.toOwed();

        (Owed fromOwed, Owed fromOwedPrev) = updateUserBorrow(marketCache, from);
        (Owed toOwed, Owed toOwedPrev) = updateUserBorrow(marketCache, to);

        // If amount was rounded up, or dust is left over, transfer exact amount owed
        if ((amount > fromOwed && (amount - fromOwed).isDust()) ||
            (amount < fromOwed && (fromOwed - amount).isDust())) {
            amount = fromOwed;
        }

        if (amount > fromOwed) revert E_InsufficientBalance();

        unchecked {
            fromOwed = fromOwed - amount;
        }

        toOwed = toOwed + amount;

        marketStorage.users[from].setOwed(fromOwed);
        marketStorage.users[to].setOwed(toOwed);

        logBorrowChange(from, fromOwedPrev, fromOwed);
        logBorrowChange(to, toOwedPrev, toOwed);
    }

    function computeInterestRate(MarketCache memory marketCache) internal virtual returns (uint256) {
        // single sload
        address irm = marketStorage.interestRateModel;
        uint256 newInterestRate = marketStorage.interestRate;

        if (irm != address(0)) {
            (bool success, bytes memory data) = irm.call(abi.encodeCall(IIRM.computeInterestRate, (
                                                                            address(this),
                                                                            marketCache.cash.toUint(),
                                                                            marketCache.totalBorrows.toAssetsUp().toUint()
                                                                       )));

            if (success && data.length >= 32) {
                newInterestRate = abi.decode(data, (uint));
                if (newInterestRate > MAX_ALLOWED_INTEREST_RATE) newInterestRate = MAX_ALLOWED_INTEREST_RATE;
                marketStorage.interestRate = uint72(newInterestRate);
            }
        }

        return newInterestRate;
    }

    function computeInterestRateView(MarketCache memory marketCache) internal view virtual returns (uint256) {
        // single sload
        address irm = marketStorage.interestRateModel;
        uint256 newInterestRate = marketStorage.interestRate;

        if (irm != address(0) && isVaultStatusCheckDeferred()) {
            (bool success, bytes memory data) = irm.staticcall(abi.encodeCall(IIRM.computeInterestRateView, (
                                                                                address(this),
                                                                                marketCache.cash.toUint(),
                                                                                marketCache.totalBorrows.toAssetsUp().toUint()
                                                                        )));
            if (success && data.length >= 32) {
                newInterestRate = abi.decode(data, (uint));
                if (newInterestRate > MAX_ALLOWED_INTEREST_RATE) newInterestRate = MAX_ALLOWED_INTEREST_RATE;
            }
        }

        return newInterestRate;
    }

    function calculateDTokenAddress() internal view returns (address dToken) {
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

    function logBorrowChange(address account, Owed prevOwed, Owed owed) private {
        address dTokenAddress = calculateDTokenAddress();

        if (owed > prevOwed) {
            uint256 change = (owed.toAssetsUp() - prevOwed.toAssetsUp()).toUint();
            emit Borrow(account, change);
            DToken(dTokenAddress).emitTransfer(address(0), account, change);
        } else if (prevOwed > owed) {
            uint256 change = (prevOwed.toAssetsUp() - owed.toAssetsUp()).toUint();

            emit Repay(account, change);
            DToken(dTokenAddress).emitTransfer(account, address(0), change);
        }
    }
}
