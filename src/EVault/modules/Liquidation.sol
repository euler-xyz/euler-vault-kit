// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ILiquidation} from "../IEVault.sol";
import {Base} from "../shared/Base.sol";
import {BalanceUtils} from "../shared/BalanceUtils.sol";
import {BorrowUtils} from "../shared/BorrowUtils.sol";

import "../shared/types/Types.sol";

abstract contract LiquidationModule is ILiquidation, Base, BalanceUtils, BorrowUtils {
    using TypesLib for uint256;

    struct LiquidationCache {
        address liquidator;
        address violator;
        address collateral;
        uint256 repayAssets;
        uint256 yieldBalance;
        bytes accountSnapshot;
    }

    /// @inheritdoc ILiquidation
    function checkLiquidation(address liquidator, address violator, address collateral)
        external
        view
        virtual
        nonReentrantView
        returns (uint256 maxRepay, uint256 maxYield)
    {
        LiquidationCache memory liqCache =
            calculateLiquidation(loadMarket(), liquidator, violator, collateral, type(uint256).max);

        maxRepay = liqCache.repayAssets;
        maxYield = liqCache.yieldBalance;
    }

    /// @inheritdoc ILiquidation
    function liquidate(address violator, address collateral, uint256 repayAssets, uint256 minYieldBalance)
        external
        virtual
        reentrantOK
    {
        // non-reentrant
        (MarketCache memory marketCache, address liquidator) = initLiquidation(violator);

        // static call
        LiquidationCache memory liqCache =
            calculateLiquidation(marketCache, liquidator, violator, collateral, repayAssets);

        // liquidation is a no-op if there's no violation
        if (liqCache.repayAssets > 0) {
            // non-reentrant
            executeLiquidation(marketCache, liqCache, minYieldBalance);

            // static call
            verifyLiquidation(marketCache, liqCache);
        }
    }

    function initLiquidation(address violator)
        private
        nonReentrant
        returns (MarketCache memory marketCache, address account)
    {
        (marketCache, account) = initOperationForBorrow(OP_LIQUIDATE);

        if (isAccountStatusCheckDeferred(violator)) revert E_ViolatorLiquidityDeferred();
    }

    function calculateLiquidation(
        MarketCache memory marketCache,
        address liquidator,
        address violator,
        address collateral,
        uint256 desiredRepay
    ) private view returns (LiquidationCache memory liqCache) {
        liqCache.liquidator = liquidator;
        liqCache.violator = violator;
        liqCache.collateral = collateral;

        if (liqCache.violator == liqCache.liquidator) revert E_SelfLiquidation();
        if (getController(liqCache.violator) != address(this)) revert E_ControllerDisabled();
        if (!isCollateralEnabled(liqCache.violator, liqCache.collateral)) revert E_CollateralDisabled();

        Assets owed = getCurrentOwed(marketCache, liqCache.violator).toAssetsUp();
        // violator has no liabilities
        if (owed.isZero()) return liqCache;

        IRiskManager.Liability memory liability =
            IRiskManager.Liability({market: address(this), asset: address(marketCache.asset), owed: owed.toUint()});

        (liqCache.repayAssets, liqCache.yieldBalance, liqCache.accountSnapshot) = marketCache
            .riskManager
            .calculateLiquidation(liqCache.liquidator, liqCache.violator, liqCache.collateral, liability, desiredRepay);
    }

    function executeLiquidation(
        MarketCache memory marketCache,
        LiquidationCache memory liqCache,
        uint256 minYieldBalance
    ) private nonReentrant {
        if (minYieldBalance > liqCache.yieldBalance) revert E_MinYield();

        // Handle yield

        if (liqCache.collateral != address(this)) {
            enforceCollateralTransfer(
                liqCache.collateral, liqCache.yieldBalance, liqCache.violator, liqCache.liquidator
            );

            // Remove scheduled health check for the violator's account. This operation is safe, because:
            // 1. `liquidate` function is enforcing that the violator is not in deferred checks state,
            //    therefore there were no prior batch operations that could have registered a health check,
            //    and if the check is present now, it must have been triggered by the enforced transfer.
            // 2. `verifyLiquidation` function is comparing the whole account state before and after yield transfer
            //    to make sure there were no side effects, effectively performing an equivalent of the health check immediately.
            // 3. Any additional operations on violator's account in a batch will register the health check again, and it
            //    will be executed normally at the end of the batch.
            forgiveAccountStatusCheck(liqCache.violator);
        } else {
            transferBalance(liqCache.violator, liqCache.liquidator, liqCache.yieldBalance.toShares());
        }

        // Handle repay: liquidator takes on violator's debt:

        transferBorrow(marketCache, liqCache.violator, liqCache.liquidator, liqCache.repayAssets.toAssets());

        emitLiquidationLog(liqCache);
    }

    function verifyLiquidation(MarketCache memory marketCache, LiquidationCache memory liqCache) private view {
        if (liqCache.collateral != address(this)) {
            marketCache.riskManager.verifyLiquidation(
                liqCache.liquidator,
                liqCache.violator,
                liqCache.collateral,
                liqCache.yieldBalance,
                liqCache.repayAssets,
                getRMLiability(marketCache, liqCache.violator),
                liqCache.accountSnapshot
            );
        }
    }

    function emitLiquidationLog(LiquidationCache memory liqCache) private {
        emit Liquidate(
            liqCache.liquidator, liqCache.violator, liqCache.collateral, liqCache.repayAssets, liqCache.yieldBalance
        );
    }

    function increaseFees(MarketCache memory marketCache, uint256 amount) private {
        uint256 newFeesBalance = marketCache.feesBalance.toUint() + amount;
        uint256 newTotalShares = marketCache.totalShares.toUint() + amount;

        if (newFeesBalance <= MAX_SANE_SMALL_AMOUNT && newTotalShares <= MAX_SANE_AMOUNT) {
            marketStorage.feesBalance = marketCache.feesBalance = newFeesBalance.toFees();
            marketStorage.totalShares = marketCache.totalShares = newTotalShares.toShares();
        }
    }
}

contract Liquidation is LiquidationModule {
    constructor(address evc, address protocolAdmin, address balanceTracker) Base(evc, protocolAdmin, balanceTracker) {}
}
