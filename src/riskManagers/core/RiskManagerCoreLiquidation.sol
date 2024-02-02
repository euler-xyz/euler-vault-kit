// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./RiskManagerCoreGovernance.sol";
import "../../IPriceOracle.sol";
import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";

abstract contract RiskManagerCoreLiquidation is RiskManagerCoreGovernance {
    function computeLiquidity(address account, address[] memory collaterals, Liability memory liability)
        internal
        view
        virtual
        returns (uint256, uint256);

    struct CalculateLiquidationCache {
        uint256 collateralBalance;
        uint256 repay;
        uint256 yield;
    }

    function calculateLiquidation(
        address,
        address violator,
        address collateral,
        Liability memory liability,
        uint256 desiredRepay
    ) external view returns (uint256, uint256, bytes memory) {
        address[] memory collaterals = IEVC(evc).getCollaterals(violator);

        CalculateLiquidationCache memory cache = calculateMaxLiquidation(violator, collateral, liability, collaterals);
        if (cache.repay == 0) return (0, 0, "");

        // Adjust for desired repay

        if (desiredRepay != type(uint256).max) {
            if (desiredRepay > cache.repay) revert RM_ExcessiveRepayAmount();

            cache.yield = desiredRepay * cache.yield / cache.repay;
            cache.repay = desiredRepay;
        }

        // Snapshot violator's account for subsequent verification

        bytes memory accountSnapshot =
            snapshotAccount(violator, collateral, cache.collateralBalance, liability, collaterals);

        return (cache.repay, cache.yield, accountSnapshot);
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
        uint256 collateralValue = IPriceOracle(oracle).getQuote(cache.collateralBalance, collateral, referenceAsset);

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

    struct MarketBalance {
        address market;
        uint256 balance;
    }

    struct AccountSnapshot {
        MarketBalance collateral;
        MarketBalance liability;
        MarketBalance[] collaterals;
    }

    function snapshotAccount(
        address account,
        address collateral,
        uint256 collateralBalance,
        Liability memory liability,
        address[] memory collaterals
    ) internal view returns (bytes memory) {
        // TODO check gas and optimize if needed
        // - pass through compute liquidity

        AccountSnapshot memory snapshot;
        snapshot.collateral = MarketBalance(collateral, collateralBalance);
        snapshot.liability = MarketBalance(liability.market, liability.owed);
        snapshot.collaterals = new MarketBalance[](collaterals.length);

        for (uint256 i; i < collaterals.length;) {
            snapshot.collaterals[i] = collaterals[i] == collateral
                ? snapshot.collateral
                : MarketBalance(collaterals[i], IERC20(collaterals[i]).balanceOf(account)); // TODO low level - everywhere
            unchecked {
                ++i;
            }
        }
        return abi.encode(snapshot);
    }

    function isEqualMarketBalance(MarketBalance memory mb, address market, uint256 balance)
        private
        pure
        returns (bool)
    {
        return mb.market == market && mb.balance == balance;
    }

    function verifyLiquidation(
        address,
        address violator,
        address collateral,
        uint256 yieldBalance,
        uint256 repayAssets,
        Liability memory liability,
        bytes memory accountSnapshot
    ) external view {
        // TODO inverse - make snapshot abi encode, compare hashes
        // TODO assume liability wasn't re-entered and the balances are correct?
        address[] memory collaterals = IEVC(evc).getCollaterals(violator);
        (AccountSnapshot memory snapshot) = abi.decode(accountSnapshot, (AccountSnapshot));
        if (snapshot.collaterals.length != collaterals.length) revert RM_InvalidLiquidationState();

        if (snapshot.liability.balance < repayAssets) revert RM_ExcessiveRepay();
        unchecked {
            snapshot.liability.balance -= repayAssets;
        }
        if (!isEqualMarketBalance(snapshot.liability, liability.market, liability.owed)) {
            revert RM_InvalidLiquidationState();
        }

        if (snapshot.collateral.balance < yieldBalance) revert RM_ExcessiveYield();
        unchecked {
            snapshot.collateral.balance -= yieldBalance;
        }
        uint256 balance = IERC20(collateral).balanceOf(violator);
        if (!isEqualMarketBalance(snapshot.collateral, collateral, balance)) revert RM_InvalidLiquidationState();

        for (uint256 i = 0; i < collaterals.length;) {
            if (collaterals[i] == collateral) {
                if (snapshot.collaterals[i].market != collaterals[i]) revert RM_InvalidLiquidationState();
            } else {
                balance = IERC20(collaterals[i]).balanceOf(violator);
                if (!isEqualMarketBalance(snapshot.collaterals[i], collaterals[i], balance)) {
                    revert RM_InvalidLiquidationState();
                }
            }

            unchecked {
                ++i;
            }
        }
    }
}
