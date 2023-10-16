// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IBorrowing} from "../IEVault.sol";
import {Base} from "../shared/Base.sol";
import {BorrowUtils} from "../shared/BorrowUtils.sol";

import "../shared/types/Types.sol";

abstract contract BorrowingModule is IBorrowing, Base, BorrowUtils {
    using TypesLib for uint;

    /// @inheritdoc IBorrowing
    function totalBorrows() external view virtual returns (uint) {
        MarketCache memory marketCache = loadMarketNonReentrant();

        return marketCache.totalBorrows.toAssetsUp().toUint();
    }

    /// @inheritdoc IBorrowing
    function totalBorrowsExact() external view virtual returns (uint) {
        return loadMarketNonReentrant().totalBorrows.toUint();
    }

    /// @inheritdoc IBorrowing
    function debtOf(address account) external view virtual returns (uint) {
        MarketCache memory marketCache = loadMarketNonReentrant();

        return getCurrentOwed(marketCache, account).toAssetsUp().toUint();
    }

    /// @inheritdoc IBorrowing
    function checkVaultStatus() external virtual reentrantOK returns (bool, bytes memory) {
        if (msg.sender != address(cvc)) return (false, "e/invalid-caller");
        return (true, "");
        // MarketCache memory marketCache = loadMarket();
        // updateInterestParams(marketCache);

        // MarketSnapshot memory currentSnapshot = getMarketSnapshot(0, marketCache);
        // MarketSnapshot memory oldSnapshot = marketStorage.marketSnapshot;
        // delete marketStorage.marketSnapshot.performedOperations;

        // if (oldSnapshot.performedOperations == 0) return (false, "e/snaphot-tampered");
        // if (oldSnapshot.interestAccumulator != currentSnapshot.interestAccumulator) return (false, "e/interest-accumulator-invariant");

        // int totalDelta;

        // // TODO can the invariant be broken with exchange rates and decimals? Total balances are converted. Exchange rate < 1 will break totalDelta <= 1?
        // // TODO rename total balances to totalBalancesInAssets?
        // unchecked {
        //     int poolSizeDelta = int(currentSnapshot.poolSize.toUint()) - int(oldSnapshot.poolSize.toUint());
        //     int totalBalancesDelta = int(currentSnapshot.totalBalances.toUint()) - int(oldSnapshot.totalBalances.toUint());
        //     int totalBorrowsDelta = int(currentSnapshot.totalBorrows.toUint()) - int(oldSnapshot.totalBorrows.toUint());
        //     totalDelta = poolSizeDelta + totalBorrowsDelta - totalBalancesDelta;
        //     totalDelta = totalDelta > 0 ? totalDelta : -totalDelta;
        // }
        // if (totalDelta > 1) return (false, "e/balances-invariant");

        // return IRiskManager(marketCache.riskManager)
        //     .checkMarketStatus(
        //         oldSnapshot.performedOperations, 
        //         IRiskManager.Snapshot({
        //             totalBalances: Assets.unwrap(oldSnapshot.totalBalances),
        //             totalBorrows: Assets.unwrap(oldSnapshot.totalBorrows)
        //         }),
        //         IRiskManager.Snapshot({
        //             totalBalances: Assets.unwrap(currentSnapshot.totalBalances),
        //             totalBorrows: Assets.unwrap(currentSnapshot.totalBorrows)
        //         })
        //     );
    }
}

contract Borrowing is BorrowingModule {
    constructor(address factory, address cvc) Base(factory, cvc) {}
}