// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BorrowUtils} from "./BorrowUtils.sol";

import "./types/Types.sol";

abstract contract LiquidityUtils is BorrowUtils {
    using TypesLib for uint256;

    function liquidityCalculate(MarketCache memory marketCache, address account, address[] memory collaterals, bool isLiquidation)
        internal
        view
        returns (uint256 collateralValue, uint256 liabilityValue)
    {
        validateOracle(marketCache);
        liabilityValue = getLiabilityValue(marketCache, account);

        for (uint256 i; i < collaterals.length; ++i) {
            collateralValue += getCollateralValue(marketCache, account, collaterals[i], isLiquidation);
        }
    }

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


    function liquidityNoCollateralExists(address account, address[] memory collaterals)
        internal
        view
        returns (bool)
    {
        for (uint256 i; i < collaterals.length; ++i) {
            address collateral = collaterals[i];

            uint256 ltv = ltvLookup[collateral].getRampedLTV(); // TODO confirm ramped, not target
            if (ltv == 0) continue;

            uint256 balance = IERC20(collateral).balanceOf(account); // TODO Read directly for self collateral?
            if (balance > 0) return false;
        }

        return true;
    }



    function validateOracle(MarketCache memory marketCache) private pure {
        if (address(marketCache.oracle) == address(0)) revert E_NoPriceOracle();
    }

    function getLiabilityValue(MarketCache memory marketCache, address account) private view returns (uint value) {
        uint256 owed = getCurrentOwed(marketCache, account).toAssetsUp().toUint();

        if (address(marketCache.asset) == marketCache.unitOfAccount) {
            value = owed;
        } else {
            // ask price for liability
            (, value) = marketCache.oracle.getQuotes(owed, address(marketCache.asset), marketCache.unitOfAccount);
        }
    }

    function getCollateralValue(MarketCache memory marketCache, address account, address collateral, bool isLiquidation) private view returns (uint value) {
            uint256 ltv = isLiquidation ? ltvLookup[collateral].getRampedLTV() : ltvLookup[collateral].getLTV();
            if (ltv == 0) return 0;

            uint256 balance = IERC20(collateral).balanceOf(account); // TODO Read directly for self?
            if (balance == 0) return 0;

            // bid price for collateral
            (uint256 currentCollateralValue,) = marketCache.oracle.getQuotes(balance, collateral, marketCache.unitOfAccount);

            return currentCollateralValue * ltv / CONFIG_SCALE;
    }
}
