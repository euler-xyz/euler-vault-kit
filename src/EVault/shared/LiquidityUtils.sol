// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BorrowUtils} from "./BorrowUtils.sol";

import "./types/Types.sol";

abstract contract LiquidityUtils is BorrowUtils {
    using TypesLib for uint256;

    // Calculate the value of liabilities, and the liquidation or borrowing LTV adjusted collateral value.
    function calculateLiquidity(MarketCache memory marketCache, address account, address[] memory collaterals, LTVType ltvType)
        internal
        view
        returns (uint256 collateralValue, uint256 liabilityValue)
    {
        validateOracle(marketCache);

        Owed owed = marketStorage.users[account].getOwed();
        liabilityValue = owed.isZero() ? 0 : getLiabilityValue(marketCache, account, owed);

        for (uint256 i; i < collaterals.length; ++i) {
            collateralValue += getCollateralValue(marketCache, account, collaterals[i], ltvType);
        }
    }

    // Check that the value of the collateral, adjusted for borrowing TVL, is equal or greater than the liability value.
    function checkLiquidity(MarketCache memory marketCache, address account, address[] memory collaterals)
        internal
        view
    {
        validateOracle(marketCache);

        Owed owed = marketStorage.users[account].getOwed();
        if (owed.isZero()) return;

        uint256 liabilityValue = getLiabilityValue(marketCache, account, owed);
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



    function getLiabilityValue(MarketCache memory marketCache, address account, Owed owed) internal view returns (uint value) {
        // update owed with interest accrued
        uint256 owedAssets = getCurrentOwed(marketCache, account, owed).toAssetsUp().toUint();

        if (address(marketCache.asset) == marketCache.unitOfAccount) {
            value = owedAssets;
        } else {
            // ask price for liability
            (, value) = marketCache.oracle.getQuotes(owedAssets, address(marketCache.asset), marketCache.unitOfAccount);
        }
    }

    function getCollateralValue(MarketCache memory marketCache, address account, address collateral, LTVType ltvType) internal view returns (uint value) {
            ConfigAmount ltv = marketStorage.ltvLookup[collateral].getLTV(ltvType);

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
