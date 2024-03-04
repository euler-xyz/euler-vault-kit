// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BorrowUtils} from "./BorrowUtils.sol";

import "./types/Types.sol";

abstract contract LiquidityUtils is BorrowUtils {
    using TypesLib for uint256;

    // alcueca: Calculate the value of liabilities, and the liquidation or borrowing tvl adjusted collateral value.
    function liquidityCalculate(MarketCache memory marketCache, address account, address[] memory collaterals, bool isLiquidation)
        internal
        view
        returns (uint256 collateralValue, uint256 liabilityValue)
    {
        validateOracle(marketCache);
        liabilityValue = getLiabilityValue(marketCache, account);

        // alcueca: You are going to get told off in the audit for not caching the length of the arrays to save gas
        for (uint256 i; i < collaterals.length; ++i) {
            collateralValue += getCollateralValue(marketCache, account, collaterals[i], isLiquidation);
        }
    }

    // alcueca: Check that the value of the collateral, adjusted for borrowing TVL, is equal or greater than the liability value.
    function liquidityCheck(address account, address[] memory collaterals)
        internal
        view
    {
        MarketCache memory marketCache = loadMarket();
        validateOracle(marketCache);

        if (marketStorage.users[account].getOwed().isZero()) return;

        uint256 liabilityValue = getLiabilityValue(marketCache, account);
        if (liabilityValue == 0) return;

        uint collateralValue;
        for (uint256 i; i < collaterals.length; ++i) {
            collateralValue += getCollateralValue(marketCache, account, collaterals[i], false);
            if (collateralValue >= liabilityValue) return;
        }

        revert E_AccountLiquidity();
    }

    // alcueca: Check if the account has no collateral of value, used for debt socialization. Maybe rename as `noCollateralCheck` or `zeroCollateralValue`.
    function liquidityNoCollateralExists(address account, address[] memory collaterals)
        internal
        view
        returns (bool)
    {
        for (uint256 i; i < collaterals.length; ++i) {
            address collateral = collaterals[i];

            uint256 ltv = ltvLookup[collateral].getRampedLTV(); // TODO confirm ramped, not target
            if (ltv == 0) continue;

            uint256 balance = IERC20(collateral).balanceOf(account);
            if (balance > 0) return false;
        }

        return true;
    }

    function getLiabilityValue(MarketCache memory marketCache, address account) internal view returns (uint value) {
        uint256 owed = getCurrentOwed(marketCache, account).toAssetsUp().toUint();

        if (address(marketCache.asset) == marketCache.unitOfAccount) {
            value = owed;
        } else {
            // ask price for liability
            (, value) = marketCache.oracle.getQuotes(owed, address(marketCache.asset), marketCache.unitOfAccount);
        }
    }

    // alcueca: Technically, you are returning the tvl-adjusted collateral value.
    // `isLiquidation` should be an enum TVL {LIQUIDATION, BORROWING} for clarity. It would be even nicer to get rid of the `isLiquidation` flag
    // but code gets quite messy.
    function getCollateralValue(MarketCache memory marketCache, address account, address collateral, bool isLiquidation) internal view returns (uint value) {
            // alcueca: indent left
            uint256 ltv = isLiquidation ? ltvLookup[collateral].getRampedLTV() : ltvLookup[collateral].getLTV();
            if (ltv == 0) return 0;

            uint256 balance = IERC20(collateral).balanceOf(account);
            if (balance == 0) return 0;

            // bid price for collateral
            (uint256 currentCollateralValue,) = marketCache.oracle.getQuotes(balance, collateral, marketCache.unitOfAccount);

            return currentCollateralValue * ltv / CONFIG_SCALE;
    }

    function validateOracle(MarketCache memory marketCache) private pure {
        if (address(marketCache.oracle) == address(0)) revert E_NoPriceOracle();
    }
}
