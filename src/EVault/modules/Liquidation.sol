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
        Assets owed; // Not an Owed type?

        Assets repay;
        uint256 yieldBalance; // This is the collateral obtained by the liquidator. Maybe we can call it `reward`? Or `award`? Or `yield`?
        // Why is `yieldBalance` not Assets type?
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
        (MarketCache memory marketCache, address liquidator) = initOperationForBorrow(OP_LIQUIDATE);

        LiquidationCache memory liqCache =
            calculateLiquidation(marketCache, liquidator, violator, collateral, repayAssets);

        // liquidation is a no-op if there's no violation
        if (!liqCache.repay.isZero()) { // This means that if `calculateMaxLiquidation` returns with zero repay because the collateral is worthless, or there is no collateral, we don't continue to the bad debt socialization code block. In other words, bad debt socialization can only happen if liquidators get to liquidate some of the debt in time.
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

        // Checks


        // Self liquidation is not allowed
        if (liqCache.violator == liqCache.liquidator) revert E_SelfLiquidation(); // Wouldn't be easy to sidestep this?
        // Only liquidate audited collaterals to make sure yield transfer has no side effects. // Is "audited" the right word?
        if (!marketStorage.ltvLookup[liqCache.collateral].initialised()) revert E_BadCollateral();
        // Verify this vault is the controller for the violator
        verifyController(liqCache.violator);
        // Violator must have enabled the collateral to be transferred to the liquidator
        if (!isCollateralEnabled(liqCache.violator, liqCache.collateral)) revert E_CollateralDisabled();
        // Violator's health check must not be deferred, meaning no prior operations on violator's account 
        // would possibly be forgiven after the enforced collateral transfer to the liquidator
        if (isAccountStatusCheckDeferred(violator)) revert E_ViolatorLiquidityDeferred();

        // Calculate max yield and repay

        liqCache = calculateMaxLiquidation(liqCache, marketCache);
        if (liqCache.repay.isZero()) return liqCache; // no liquidation opportunity found -- Maybe check liqCache.yieldBalance.isZero() instead if you want to let liquidations progress to bad debt socialization

        // Adjust for desired repay

        if (desiredRepay != type(uint256).max) { // The liquidator can enter `type(uint256).max` as `repayAssets` to repay the whole debt.
            uint256 maxRepay = liqCache.repay.toUint(); // `maxRepay` means repaying the maximum allowed by the liquidation algorithm, not necessarily the whole debt
            if (desiredRepay > maxRepay) revert E_ExcessiveRepayAmount(); // Why don't we cap to `maxRepay` instead of reverting?

            liqCache.yieldBalance = desiredRepay * liqCache.yieldBalance / maxRepay; // `liqCache.yieldBalance` was calculated as the collateral transferred for repaying `maxRepay`, so if the liquidator wants to repay less, we award a proportional amount of collateral. 
            liqCache.repay = desiredRepay.toAssets(); // BorrowUtils.transferBorrow takes Assets as a parameter.
        }
    }

    function calculateMaxLiquidation(
        LiquidationCache memory liqCache,
        MarketCache memory marketCache
    ) private view returns (LiquidationCache memory) {
        liqCache.owed = getCurrentOwed(marketCache, liqCache.violator).toAssetsUp();
        // violator has no liabilities
        if (liqCache.owed.isZero()) return liqCache; // This means liqCache.repay will still be zero, and there will be no liquidation

        liqCache.collaterals = getCollaterals(liqCache.violator); // A bit weird to assign this here

        (uint256 liquidityCollateralValue, uint256 liquidityLiabilityValue) = calculateLiquidity(marketCache, liqCache.violator, liqCache.collaterals, LTVType.LIQUIDATION);

        // no violation
        if (liquidityCollateralValue >= liquidityLiabilityValue) return liqCache; // This means liqCache.repay will still be zero, and there will be no liquidation

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
        liqCache.debtSocialization = marketStorage.debtSocialization; // A bit weird to assign this here

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
            liqCache.debtSocialization &&
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
