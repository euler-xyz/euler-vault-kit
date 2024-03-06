// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Base} from "./Base.sol";
import {DToken} from "../DToken.sol";


import "./types/Types.sol";

abstract contract BorrowUtils is Base {
    using TypesLib for uint256;

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
        Owed amount = assets.toOwed(); // alcueca: Move this line down, to where it is needed. Also, would this be `owedIncrease`?
        (Owed owed, Owed prevOwed) = updateUserBorrow(marketCache, account); // alcueca: We update the user borrows by the increase in the interestAccumulator

        owed = owed + amount;

        marketStorage.users[account].setOwed(owed); // alcueca: We add `amount` to the user borrows
        marketStorage.totalBorrows = marketCache.totalBorrows = marketCache.totalBorrows + amount; // alcueca: Where did we update the totalBorrows by the increase in the interestAccumulator applied to the user borrows?

        logBorrowChange(account, prevOwed, owed);
    }

    function decreaseBorrow(MarketCache memory marketCache, address account, Assets assets) internal {
        (Owed owed, Owed prevOwed) = updateUserBorrow(marketCache, account); // alcueca: Owed are Assets with increased precision
        Assets debtAssets = owed.toAssetsUp();

        if (assets > debtAssets) revert E_RepayTooMuch();
        Assets debtAssetsRemaining;
        unchecked {
            debtAssetsRemaining = debtAssets - assets; // alcueca: In `increaseBorrow` we do this operation in owed terms, here we do it in asset terms. Choose one pattern for both functions if possible.
        }

        if (owed > marketCache.totalBorrows) owed = marketCache.totalBorrows; // alcueca: What's the logic behind this?

        Owed owedRemaining = debtAssetsRemaining.toOwed();
        marketStorage.users[account].setOwed(owedRemaining);
        marketStorage.totalBorrows = marketCache.totalBorrows = marketCache.totalBorrows - owed + owedRemaining; // alcueca: This would be `totalBorrows - amount` if following the pattern from `increaseBorrow`

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
