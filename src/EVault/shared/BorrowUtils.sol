// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {CVCClient} from "./CVCClient.sol";
import {Cache} from "./Cache.sol";
import {DToken} from "../DToken.sol";
import {IRiskManager} from "../../IRiskManager.sol";

import "./types/Types.sol";

abstract contract BorrowUtils is CVCClient, Cache {
    using TypesLib for uint;

    function getCurrentOwed(MarketCache memory marketCache, address account, Owed owed) internal view returns (Owed) {
        // Don't bother loading the user's accumulator
        if (owed.isZero()) return Owed.wrap(0);

        // Can't divide by 0 here: If owed is non-zero, we must've initialised the user's interestAccumulator
        return owed.mulDiv(marketCache.interestAccumulator, marketStorage.users[account].interestAccumulator);
    }

    function getCurrentOwed(MarketCache memory marketCache, address account) internal view returns (Owed) {
        return getCurrentOwed(marketCache, account, marketStorage.users[account].owed);
    }

    // function updateUserBorrow(MarketCache memory marketCache, address account) private returns (Owed newOwed, Owed prevOwed) {
    //     prevOwed = marketStorage.users[account].owed;
    //     newOwed = getCurrentOwed(marketCache, account, prevOwed);

    //     marketStorage.users[account].owed = newOwed;
    //     marketStorage.users[account].interestAccumulator = marketCache.interestAccumulator;
    // }

    // function increaseBorrow(MarketCache memory marketCache, address account, Assets assets) internal {
    //     Owed amount = assets.toOwed();
    //     (Owed owed, Owed prevOwed) = updateUserBorrow(marketCache, account);

    //     owed = owed + amount;

    //     marketStorage.users[account].owed = owed;
    //     marketStorage.totalBorrows = marketCache.totalBorrows = marketCache.totalBorrows + amount;

    //     logBorrowChange(account, prevOwed, owed);
    // }

    // function decreaseBorrow(MarketCache memory marketCache, address account, Assets assets) internal {
    //     (Owed owed, Owed prevOwed) = updateUserBorrow(marketCache, account);
    //     Assets debtAssets = owed.toAssetsUp();

    //     if (assets > debtAssets) revert E_RepayTooMuch();
    //     Assets debtAssetsRemaining;
    //     unchecked { debtAssetsRemaining = debtAssets - assets; }

    //     if (owed > marketCache.totalBorrows) owed = marketCache.totalBorrows; // TODO ?

    //     if (debtAssetsRemaining.isZero()) releaseController(account);

    //     Owed owedRemaining = debtAssetsRemaining.toOwed();
    //     marketStorage.users[account].owed = owedRemaining;
    //     marketStorage.totalBorrows = marketCache.totalBorrows = marketCache.totalBorrows - owed + owedRemaining;

    //     logBorrowChange(account, prevOwed, owedRemaining);
    // }

    // function transferBorrow(MarketCache memory marketCache, address from, address to, Assets assets) internal {
    //     Owed amount = assets.toOwed();

    //     (Owed fromOwed, Owed fromOwedPrev) = updateUserBorrow(marketCache, from);
    //     (Owed toOwed, Owed toOwedPrev) = updateUserBorrow(marketCache, to);

    //     // If amount was rounded up, transfer exact amount owed
    //     if (amount > fromOwed && (amount - fromOwed).isDust()) amount = fromOwed;

    //     if (amount > fromOwed) revert E_InsufficientBalance();

    //     unchecked { fromOwed = fromOwed - amount; }

    //     // Transfer any residual dust
    //     if (fromOwed.isDust()) {
    //         amount = amount + fromOwed;
    //         fromOwed = Owed.wrap(0);
    //     }

    //     toOwed = toOwed + amount;

    //     marketStorage.users[from].owed = fromOwed;
    //     marketStorage.users[to].owed = toOwed;

    //     if (fromOwedPrev > Owed.wrap(0) && fromOwed == Owed.wrap(0)) releaseController(from);

    //     logBorrowChange(from, fromOwedPrev, fromOwed);
    //     logBorrowChange(to, toOwedPrev, toOwed);
    // }

    // // TODO revisit
    // function getLiquidityPayload(address account, address[] memory collateralMarkets) internal view returns (IRiskManager riskManager, IRiskManager.MarketAssets memory liability, IRiskManager.MarketAssets[] memory collaterals) {
    //     liability.market = address(this);

    //     MarketCache memory marketCache = loadMarket();

    //     riskManager = marketCache.riskManager;

    //     liability.assets = getCurrentOwed(marketCache, account).toAssetsUp().toUint();
    //     liability.assetsSet = true;

    //     collaterals = new IRiskManager.MarketAssets[](collateralMarkets.length);

    //     for (uint i = 0; i < collateralMarkets.length;) {
    //         address market = collateralMarkets[i];
    //         collaterals[i].market = market;
    //         if (market == address(this)) {
    //             collaterals[i].assets = marketStorage.users[account].balance.toAssetsDown(marketCache).toUint();
    //             collaterals[i].assetsSet = true;
    //         }

    //         unchecked { ++i; }
    //     }
    // }

    // function calculateDTokenAddress() internal view returns (address dToken) {
    //     // inspired by https://github.com/Vectorized/solady/blob/229c18cfcdcd474f95c30ad31b0f7d428ee8a31a/src/utils/CREATE3.sol#L82-L90
    //     assembly ("memory-safe") {
    //         mstore(0x14, address())
    //         // 0xd6 = 0xc0 (short RLP prefix) + 0x16 (length of: 0x94 ++ address(this) ++ 0x01).
    //         // 0x94 = 0x80 + 0x14 (0x14 = the length of an address, 20 bytes, in hex).
    //         mstore(0x00, 0xd694)
    //         // Nonce of the contract when DToken was deployed (1).
    //         mstore8(0x34, 0x01)

    //         dToken := keccak256(0x1e, 0x17)
    //     }
    // }

    // function logBorrowChange(address account, Owed prevOwed, Owed owed) private {
    //     address dTokenAddress = calculateDTokenAddress();

    //     if (owed > prevOwed) {
    //         Assets change = owed.toAssetsUp() - prevOwed.toAssetsUp();
    //         emit Borrow(account, change.toUint());
    //         DToken(dTokenAddress).emitTransfer(address(0), account, change.toUint());
    //     } else if (prevOwed > owed) {
    //         Assets change = prevOwed.toAssetsUp() - owed.toAssetsUp();
    //         emit Repay(account, change.toUint());
    //         DToken(dTokenAddress).emitTransfer(account, address(0), change.toUint());
    //     }
    // }
}
