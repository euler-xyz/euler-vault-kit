// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Base} from "./Base.sol";
import {DToken} from "../DToken.sol";
import {IRiskManager} from "../../IRiskManager.sol";

import "./types/Types.sol";

abstract contract BorrowUtils is Base {
    using TypesLib for uint256;
    using UserStorageLib for UserStorage;

    function getCurrentOwed(MarketCache memory marketCache, address account, Owed owed) internal view returns (Owed) {
        // Don't bother loading the user's accumulator
        if (owed.isZero()) return Owed.wrap(0);

        // Can't divide by 0 here: If owed is non-zero, we must've initialised the user's interestAccumulator
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
        Owed amount = assets.toOwed();
        (Owed owed, Owed prevOwed) = updateUserBorrow(marketCache, account);

        owed = owed + amount;

        marketStorage.users[account].setOwed(owed);
        marketStorage.totalBorrows = marketCache.totalBorrows = marketCache.totalBorrows + amount;

        logBorrowChange(account, prevOwed, owed);
    }

    function decreaseBorrow(MarketCache memory marketCache, address account, Assets assets) internal {
        (Owed owed, Owed prevOwed) = updateUserBorrow(marketCache, account);
        Assets debtAssets = owed.toAssetsUp();

        if (assets > debtAssets) revert E_RepayTooMuch();
        Assets debtAssetsRemaining;
        unchecked {
            debtAssetsRemaining = debtAssets - assets;
        }

        if (owed > marketCache.totalBorrows) owed = marketCache.totalBorrows;

        Owed owedRemaining = debtAssetsRemaining.toOwed();
        marketStorage.users[account].setOwed(owedRemaining);
        marketStorage.totalBorrows = marketCache.totalBorrows = marketCache.totalBorrows - owed + owedRemaining;

        logBorrowChange(account, prevOwed, owedRemaining);
    }

    function transferBorrow(MarketCache memory marketCache, address from, address to, Assets assets) internal {
        Owed amount = assets.toOwed();

        (Owed fromOwed, Owed fromOwedPrev) = updateUserBorrow(marketCache, from);
        (Owed toOwed, Owed toOwedPrev) = updateUserBorrow(marketCache, to);

        // If amount was rounded up, transfer exact amount owed
        if (amount > fromOwed && (amount - fromOwed).isDust()) amount = fromOwed;

        if (amount > fromOwed) revert E_InsufficientBalance();

        unchecked {
            fromOwed = fromOwed - amount;
        }

        // Transfer any residual dust
        if (fromOwed.isDust()) {
            amount = amount + fromOwed;
            fromOwed = Owed.wrap(0);
        }

        toOwed = toOwed + amount;

        marketStorage.users[from].setOwed(fromOwed);
        marketStorage.users[to].setOwed(toOwed);

        logBorrowChange(from, fromOwedPrev, fromOwed);
        logBorrowChange(to, toOwedPrev, toOwed);
    }

    function getRMLiability(MarketCache memory marketCache, address account)
        internal
        view
        returns (IRiskManager.Liability memory liability)
    {
        Owed owed = marketStorage.users[account].getOwed();

        liability.market = address(this);
        liability.asset = address(marketCache.asset);
        liability.owed = getCurrentOwed(marketCache, account, owed).toAssetsUp().toUint();
    }

    function updateInterestParams(MarketCache memory marketCache) internal returns (uint72) {
        uint256 borrows = marketCache.totalBorrows.toAssetsUp().toUint();
        uint256 poolAssets = marketCache.poolSize.toUint() + borrows;

        uint32 utilisation = poolAssets == 0
            ? 0 // empty pool arbitrarily given utilisation of 0
            : uint32(borrows * (uint256(type(uint32).max) * 1e18) / poolAssets / 1e18);

        (uint256 newInterestRate, uint16 newInterestFee) =
            marketCache.riskManager.computeInterestParams(address(marketCache.asset), utilisation);
        uint16 interestFee = marketStorage.interestFee;

        if (newInterestFee != interestFee) {
            if (protocolAdmin.isValidInterestFee(address(this), newInterestFee)) {
                emit NewInterestFee(newInterestFee);
            } else {
                // ignore incorrect value
                newInterestFee = interestFee;
            }
        }

        if (newInterestRate > MAX_ALLOWED_INTEREST_RATE) newInterestRate = MAX_ALLOWED_INTEREST_RATE;

        marketStorage.interestRate = uint72(newInterestRate);
        marketStorage.interestFee = newInterestFee;

        return uint72(newInterestRate);
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
