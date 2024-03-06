// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BorrowUtils} from "./BorrowUtils.sol";

import "./types/Types.sol";

abstract contract LiquidityUtils is BorrowUtils {
    using TypesLib for uint256;

    enum LTVType {
        LIQUIDATION, BORROWING
    }

    // Calculate the value of liabilities, and the liquidation or borrowing LTV adjusted collateral value.
    function calculateLiquidity(MarketCache memory marketCache, address account, address[] memory collaterals, LTVType ltvType)
        internal
        view
        returns (uint256 collateralValue, uint256 liabilityValue)
    {
        validateOracle(marketCache);
        liabilityValue = getLiabilityValue(marketCache, account);

        for (uint256 i; i < collaterals.length; ++i) {
            collateralValue += getCollateralValue(marketCache, account, collaterals[i], ltvType);
        }
    }

    // Check that the value of the collateral, adjusted for borrowing TVL, is equal or greater than the liability value.
    function checkLiquidity(address account, address[] memory collaterals)
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
            collateralValue += getCollateralValue(marketCache, account, collaterals[i], LTVType.BORROWING);
            if (collateralValue >= liabilityValue) return;
        }

        revert E_AccountLiquidity();
    }


    // Check if the account has no collateral balance left, used for debt socialization
    // If LTV is zero, the collateral can still be liquidated.
    // If the price of collateral is zero, liquidations are not executed, so the check won't be performed.
    // If there is no collateral balance at all, then debt socialization can happen.
    function checkNoCollateral(address account, address[] memory collaterals)
        internal
        view
        returns (bool)
    {
        for (uint256 i; i < collaterals.length; ++i) {
            address collateral = collaterals[i];

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

    function getCollateralValue(MarketCache memory marketCache, address account, address collateral, LTVType ltvType) internal view returns (uint value) {
            ConfigAmount ltv = ltvType == LTVType.LIQUIDATION
                ? ltvLookup[collateral].getLiquidationLTV()
                : ltvLookup[collateral].getLTV();

            if (ltv.isZero()) return 0;

            uint256 balance = IERC20(collateral).balanceOf(account);
            if (balance == 0) return 0;

            // bid price for collateral
            (uint256 currentCollateralValue,) = marketCache.oracle.getQuotes(balance, collateral, marketCache.unitOfAccount);

            return ltv.mul(currentCollateralValue);
    }

    function validateOracle(MarketCache memory marketCache) private pure {
        if (address(marketCache.oracle) == address(0)) revert E_NoPriceOracle();
    }
}
