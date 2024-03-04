// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ILiquidation} from "../IEVault.sol";
import {Base} from "../shared/Base.sol";
import {BalanceUtils} from "../shared/BalanceUtils.sol";
import {LiquidityUtils} from "../shared/LiquidityUtils.sol";

import "../shared/types/Types.sol";

abstract contract LiquidationModule is ILiquidation, Base, BalanceUtils, LiquidityUtils {
    using TypesLib for uint256;

    struct LiquidationCache {
        address liquidator;
        address violator;
        address collateral;
        address[] collaterals;
        bool debtSocialization;
        Assets owed;

        Assets repay;
        uint256 yieldBalance;
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

        maxRepay = liqCache.repay.toUint();
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

        // reentrancy allowed for static call
        LiquidationCache memory liqCache =
            calculateLiquidation(marketCache, liquidator, violator, collateral, repayAssets);

        // liquidation is a no-op if there's no violation
        if (!liqCache.repay.isZero()) {
            // non-reentrant
            executeLiquidation(marketCache, liqCache, minYieldBalance);
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

        liqCache.repay = Assets.wrap(0);
        liqCache.yieldBalance = 0;

        verifyController(liqCache.violator);
        if (liqCache.violator == liqCache.liquidator) revert E_SelfLiquidation();
        if (!isCollateralEnabled(liqCache.violator, liqCache.collateral)) revert E_CollateralDisabled();
        // critical security check - only liquidate audited collaterals to make sure yield transfer has no side effects.
        if (!ltvLookup[liqCache.collateral].initialised()) revert E_BadCollateral();


        liqCache.owed = getCurrentOwed(marketCache, violator).toAssetsUp();
        // violator has no liabilities
        if (liqCache.owed.isZero()) return liqCache;

        liqCache.collaterals = getCollaterals(violator);

        liqCache = calculateMaxLiquidation(liqCache, marketCache);
        if (liqCache.repay.isZero()) return liqCache;

        // Adjust for desired repay

        if (desiredRepay != type(uint256).max) {
            uint256 maxRepay = liqCache.repay.toUint();
            if (desiredRepay > maxRepay) revert E_ExcessiveRepayAmount();

            liqCache.yieldBalance = desiredRepay * liqCache.yieldBalance / maxRepay;
            liqCache.repay = desiredRepay.toAssets();
        }
    }

    function calculateMaxLiquidation(
        LiquidationCache memory liqCache,
        MarketCache memory marketCache
    ) private view returns (LiquidationCache memory) {
        (uint256 liquidityCollateralValue, uint256 liquidityLiabilityValue) = liquidityCalculate(marketCache, liqCache.violator, liqCache.collaterals, true);

        // no violation
        if (liquidityCollateralValue >= liquidityLiabilityValue) return liqCache;

        // At this point healthScore must be < 1 since collateral < liability

        // Compute discount

        uint256 discountFactor = liquidityCollateralValue * 1e18 / liquidityLiabilityValue; // 1 - health score

        if (discountFactor < 1e18 - MAXIMUM_LIQUIDATION_DISCOUNT) {
            discountFactor = 1e18 - MAXIMUM_LIQUIDATION_DISCOUNT;
        }

        // Compute maximum yield

        uint256 collateralBalance = IERC20(liqCache.collateral).balanceOf(liqCache.violator);
        uint256 collateralValue = marketCache.oracle.getQuote(collateralBalance, liqCache.collateral, marketCache.unitOfAccount);

        // no collateral balance, or worthless collateral
        if (collateralValue == 0) return liqCache;

        uint256 liabilityValue;
        if (address(marketCache.asset) == marketCache.unitOfAccount) {
            liabilityValue = liqCache.owed.toUint();
        } else {
            // liquidation, in contract to liquidity calculation, uses mid-point pricing instead of bid/ask
            liabilityValue = marketCache.oracle.getQuote(liqCache.owed.toUint(), address(marketCache.asset), marketCache.unitOfAccount);
        }

        uint256 maxRepayValue = liabilityValue;
        uint256 maxYieldValue = maxRepayValue * 1e18 / discountFactor;

        // Limit yield to borrower's available collateral, and reduce repay if necessary
        // This can happen when borrower has multiple collaterals and seizing all of this one won't bring the violator back to solvency

        if (collateralValue < maxYieldValue) {
            maxRepayValue = collateralValue * discountFactor / 1e18;
            maxYieldValue = collateralValue;
        }

        liqCache.repay = (maxRepayValue * liqCache.owed.toUint() / liabilityValue).toAssets();
        liqCache.yieldBalance = maxYieldValue * collateralBalance / collateralValue;
        liqCache.debtSocialization = marketStorage.debtSocialization;

        return liqCache;
    }

    function executeLiquidation(
        MarketCache memory marketCache,
        LiquidationCache memory liqCache,
        uint256 minYieldBalance
    ) private {
        if (minYieldBalance > liqCache.yieldBalance) revert E_MinYield();

        // Handle repay: liquidator takes on violator's debt:

        transferBorrow(marketCache, liqCache.violator, liqCache.liquidator, liqCache.repay);

        // Handle yield: liquidator receives violator's collateral

        // Impersonate violator on the EVC to seize collateral and remove scheduled health check for the violator's account.
        // This operation is safe, because:
        // 1. `liquidate` function is enforcing that the violator is not in deferred checks state,
        //    therefore there were no prior batch operations that could have registered a health check,
        //    and if the check is present now, it must have been triggered by the enforced transfer.
        // 2. Markets with collateral factor 0 are never invoked during liquidation, and markets with
        //    non-zero collateral factors are assumed to have trusted transfer methods that make no external calls
        //    FIXME FIXME make sure this is true ^^^
        // 3. Any additional operations on violator's account in a batch will register the health check again, and it
        //    will be executed normally at the end of the batch.

        enforceCollateralTransfer(
            liqCache.collateral, liqCache.yieldBalance, liqCache.violator, liqCache.liquidator
        );

        forgiveAccountStatusCheck(liqCache.violator);

        // Handle debt socialization
        if (
            liqCache.debtSocialization &&
            liqCache.owed > liqCache.repay &&
            liquidityNoCollateralExists(liqCache.violator, liqCache.collaterals)
        ) {
            Assets owedRemaining = liqCache.owed - liqCache.repay;
            decreaseBorrow(marketCache, liqCache.violator, owedRemaining);

            // decreaseBorrow emits Repay without any assets entering the vault. Emit Withdraw from and to zero address to cover the missing amount for offchain trackers.
            emit Withdraw(liqCache.liquidator, address(0), address(0), owedRemaining.toUint(), 0);
            emit DebtSocialized(liqCache.violator, owedRemaining.toUint());
        }

        emitLiquidationLog(liqCache);
    }

    function emitLiquidationLog(LiquidationCache memory liqCache) private {
        emit Liquidate(
            liqCache.liquidator, liqCache.violator, liqCache.collateral, liqCache.repay.toUint(), liqCache.yieldBalance
        );
    }
}

contract Liquidation is LiquidationModule {
    constructor(address evc, address protocolConfig, address balanceTracker) Base(evc, protocolConfig, balanceTracker) {}
}
