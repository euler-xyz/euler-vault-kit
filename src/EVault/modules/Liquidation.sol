// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ILiquidation} from "../IEVault.sol";
import {Base} from "../shared/Base.sol";
import {BalanceUtils} from "../shared/BalanceUtils.sol";
import {LiquidityUtils} from "../shared/LiquidityUtils.sol";

import "../shared/types/Types.sol";

abstract contract LiquidationModule is ILiquidation, Base, BalanceUtils, LiquidityUtils {
    using TypesLib for uint256;

    // Maximum liquidation discount that can be awarded under any conditions.
    uint256 constant MAXIMUM_LIQUIDATION_DISCOUNT = 0.2 * 1e18;

    struct LiquidationCache {
        address liquidator;
        address violator;
        address collateral;
        address[] collaterals;
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
        nonReentrant
    {
        (MarketCache memory marketCache, address liquidator) = initOperation(OP_LIQUIDATE, ACCOUNTCHECK_CALLER);

        LiquidationCache memory liqCache =
            calculateLiquidation(marketCache, liquidator, violator, collateral, repayAssets);

        // liquidation is a no-op if there's no violation
        if (!liqCache.repay.isZero()) {
            executeLiquidation(marketCache, liqCache, minYieldBalance);
        }
    }

    function calculateLiquidation(
        MarketCache memory marketCache,
        address liquidator,
        address violator,
        address collateral,
        uint256 desiredRepay
    ) private view returns (LiquidationCache memory liqCache) {
        // Init cache

        liqCache.liquidator = liquidator;
        liqCache.violator = violator;
        liqCache.collateral = collateral;

        liqCache.repay = Assets.wrap(0);
        liqCache.yieldBalance = 0;
        liqCache.owed = getCurrentOwed(marketCache, violator).toAssetsUp();
        liqCache.collaterals = getCollaterals(violator);

        // Checks

        // Self liquidation is not allowed
        if (liqCache.violator == liqCache.liquidator) revert E_SelfLiquidation();
        // Only liquidate trusted collaterals to make sure yield transfer has no side effects.
        if (!isRecognizedCollateral(liqCache.collateral)) revert E_BadCollateral();
        // Verify this vault is the controller for the violator
        verifyController(liqCache.violator);
        // Violator must have enabled the collateral to be transferred to the liquidator
        if (!isCollateralEnabled(liqCache.violator, liqCache.collateral)) revert E_CollateralDisabled();
        // Violator's health check must not be deferred, meaning no prior operations on violator's account 
        // would possibly be forgiven after the enforced collateral transfer to the liquidator
        if (isAccountStatusCheckDeferred(violator)) revert E_ViolatorLiquidityDeferred();

        // Violator has no liabilities, liquidation is a no-op
        if (liqCache.owed.isZero()) return liqCache;

        // Calculate max yield and repay

        liqCache = calculateMaxLiquidation(liqCache, marketCache);
        if (liqCache.repay.isZero()) return liqCache; // no liquidation opportunity found

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
        (uint256 liquidityCollateralValue, uint256 liquidityLiabilityValue) = calculateLiquidity(marketCache, liqCache.violator, liqCache.collaterals, LTVType.LIQUIDATION);

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

        uint256 liabilityValue = liqCache.owed.toUint();
        if (address(marketCache.asset) != marketCache.unitOfAccount) {
            // liquidation, in contrast to liquidity calculation, uses mid-point pricing instead of bid/ask
            liabilityValue = marketCache.oracle.getQuote(liabilityValue, address(marketCache.asset), marketCache.unitOfAccount);
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

        // Impersonate violator on the EVC to seize collateral. The yield transfer will trigger a health check on the violator's
        // account, which should be forgiven, because the violator's account is not guaranteed to be healthy after liquidation.
        // This operation is safe, because:
        // 1. `liquidate` function is enforcing that the violator is not in deferred checks state,
        //    therefore there were no prior batch operations that could have registered a health check,
        //    and if the check is present now, it must have been triggered by the enforced transfer.
        // 2. Only collaterals with initialized LTV settings can be liquidated and they are assumed to be audited
        //    to have safe transfer methods, which make no external calls. In other words, yield transfer will not 
        //    have any side effects, which would be wrongly forgiven.
        // 3. Any additional operations on violator's account in a batch will register the health check again, and it
        //    will be executed normally at the end of the batch.

        enforceCollateralTransfer(
            liqCache.collateral, liqCache.yieldBalance, liqCache.violator, liqCache.liquidator
        );

        forgiveAccountStatusCheck(liqCache.violator);

        // Handle debt socialization

        if (
            !marketCache.disabledOps.check(OP_SOCIALIZE_DEBT) &&
            liqCache.owed > liqCache.repay &&
            checkNoCollateral(liqCache.violator, liqCache.collaterals)
        ) {
            Assets owedRemaining = liqCache.owed - liqCache.repay;
            decreaseBorrow(marketCache, liqCache.violator, owedRemaining);

            // decreaseBorrow emits Repay without any assets entering the vault. Emit Withdraw from and to zero address to cover the missing amount for offchain trackers.
            emit Withdraw(liqCache.liquidator, address(0), address(0), owedRemaining.toUint(), 0);
            emit DebtSocialized(liqCache.violator, owedRemaining.toUint());
        }

        emit Liquidate(
            liqCache.liquidator, liqCache.violator, liqCache.collateral, liqCache.repay.toUint(), liqCache.yieldBalance
        );
    }
}

contract Liquidation is LiquidationModule {
    constructor(Integrations memory integrations) Base(integrations) {}
}
