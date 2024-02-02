// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ILiquidation} from "../IEVault.sol";
import {Base} from "../shared/Base.sol";
import {BalanceUtils} from "../shared/BalanceUtils.sol";
import {BorrowUtils} from "../shared/BorrowUtils.sol";
import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";
import "../../IPriceOracle.sol";

import "../shared/types/Types.sol";

abstract contract LiquidationModule is ILiquidation, Base, BalanceUtils, BorrowUtils {
    using TypesLib for uint256;

    struct LiquidationCache {
        address liquidator;
        address violator;
        address collateral;
        uint256 repayAssets;
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

        Liability memory liability =
            Liability({market: address(this), asset: address(marketCache.asset), owed: owed.toUint()});

        (liqCache.repayAssets, liqCache.yieldBalance) =
            calculateLiquidationInternal(liqCache.liquidator, liqCache.violator, liqCache.collateral, liability, desiredRepay);
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
            // 2. Markets with collateral factor 0 are never invoked during liquidation, and markets with
            //    non-zero collateral factors are assumed to have trusted transfer methods that make no external calls
            //    FIXME FIXME make sure this is true ^^^
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




    struct CalculateLiquidationCache {
        uint256 collateralBalance;
        uint256 repay;
        uint256 yield;
    }

    function calculateLiquidationInternal(
        address,
        address violator,
        address collateral,
        Liability memory liability,
        uint256 desiredRepay
    ) internal view returns (uint256, uint256) {
        address[] memory collaterals = IEVC(evc).getCollaterals(violator);

        CalculateLiquidationCache memory cache = calculateMaxLiquidation(violator, collateral, liability, collaterals);
        if (cache.repay == 0) return (0, 0);

        // Adjust for desired repay

        if (desiredRepay != type(uint256).max) {
            if (desiredRepay > cache.repay) revert RM_ExcessiveRepayAmount();

            cache.yield = desiredRepay * cache.yield / cache.repay;
            cache.repay = desiredRepay;
        }

        return (cache.repay, cache.yield);
    }

    function calculateMaxLiquidation(
        address violator,
        address collateral,
        Liability memory liability,
        address[] memory collaterals
    ) internal view virtual returns (CalculateLiquidationCache memory cache) {
        cache.repay = 0;
        cache.yield = 0;
        cache.collateralBalance = 0;

        (uint256 totalCollateralValueRA, uint256 liabilityValue) = computeLiquidity(violator, collaterals, liability);

        // no violation
        if (totalCollateralValueRA >= liabilityValue) return cache;

        // At this point healthScore must be < 1 since collateral < liability

        // Compute discount

        uint256 discountFactor = totalCollateralValueRA * 1e18 / liabilityValue; // 1 - health score

        if (discountFactor < 1e18 - MAXIMUM_LIQUIDATION_DISCOUNT) {
            discountFactor = 1e18 - MAXIMUM_LIQUIDATION_DISCOUNT;
        }

        // Compute maximum yield

        cache.collateralBalance = IERC20(collateral).balanceOf(violator);
        uint256 collateralValue = IPriceOracle(marketConfig.oracle).getQuote(cache.collateralBalance, collateral, marketConfig.unitOfAccount);

        uint256 maxRepayValue = liabilityValue;
        uint256 maxYieldValue = maxRepayValue * 1e18 / discountFactor;

        // Limit yield to borrower's available collateral, and reduce repay if necessary
        // This can happen when borrower has multiple collaterals and seizing all of this one won't bring the violator back to solvency

        if (collateralValue < maxYieldValue) {
            maxRepayValue = collateralValue * discountFactor / 1e18;
            maxYieldValue = collateralValue;
        }

        cache.repay = maxRepayValue * liability.owed / liabilityValue;
        cache.yield = maxYieldValue * cache.collateralBalance / collateralValue;
    }
}

contract Liquidation is LiquidationModule {
    constructor(address evc, address protocolAdmin, address balanceTracker) Base(evc, protocolAdmin, balanceTracker) {}
}
