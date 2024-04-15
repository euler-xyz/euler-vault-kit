// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BorrowUtils} from "./BorrowUtils.sol";
import {LTVUtils} from "./LTVUtils.sol";

import "./types/Types.sol";

/// @title LiquidityUtils
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Utilities for calculating account liquidity and health status
abstract contract LiquidityUtils is BorrowUtils, LTVUtils {
    using TypesLib for uint256;

    // Calculate the value of liabilities, and the liquidation or borrowing LTV adjusted collateral value.
    function calculateLiquidity(
        VaultCache memory vaultCache,
        address account,
        address[] memory collaterals,
        LTVType ltvType
    ) internal view virtual returns (uint256 collateralValue, uint256 liabilityValue) {
        validateOracle(vaultCache);

        for (uint256 i; i < collaterals.length; ++i) {
            collateralValue += getCollateralValue(vaultCache, account, collaterals[i], ltvType);
        }

        liabilityValue = getLiabilityValue(vaultCache, account, vaultStorage.users[account].getOwed());
    }

    // Check that the value of the collateral, adjusted for borrowing LTV, is equal or greater than the liability value.
    function checkLiquidity(VaultCache memory vaultCache, address account, address[] memory collaterals)
        internal
        view
        virtual
    {
        validateOracle(vaultCache);

        Owed owed = vaultStorage.users[account].getOwed();
        if (owed.isZero()) return;

        uint256 liabilityValue = getLiabilityValue(vaultCache, account, owed);

        uint256 collateralValue;
        for (uint256 i; i < collaterals.length; ++i) {
            collateralValue += getCollateralValue(vaultCache, account, collaterals[i], LTVType.BORROWING);
            if (collateralValue > liabilityValue) return;
        }

        revert E_AccountLiquidity();
    }

    // Check if the account has no collateral balance left, used for debt socialization
    // If LTV is zero, the collateral can still be liquidated.
    // If the price of collateral is zero, liquidations are not executed, so the check won't be performed.
    // If there is no collateral balance at all, then debt socialization can happen.
    function checkNoCollateral(address account, address[] memory collaterals) internal view virtual returns (bool) {
        for (uint256 i; i < collaterals.length; ++i) {
            address collateral = collaterals[i];

            if (!isRecognizedCollateral(collateral)) continue;

            uint256 balance = IERC20(collateral).balanceOf(account);
            if (balance > 0) return false;
        }

        return true;
    }

    function getLiabilityValue(VaultCache memory vaultCache, address account, Owed owed)
        internal
        view
        virtual
        returns (uint256 value)
    {
        // update owed with interest accrued
        uint256 owedAssets = getCurrentOwed(vaultCache, account, owed).toAssetsUp().toUint();

        if (owedAssets == 0) return 0;

        if (address(vaultCache.asset) == vaultCache.unitOfAccount) {
            value = owedAssets;
        } else {
            // ask price for liability
            (, value) = vaultCache.oracle.getQuotes(owedAssets, address(vaultCache.asset), vaultCache.unitOfAccount);
        }
    }

    function getCollateralValue(VaultCache memory vaultCache, address account, address collateral, LTVType ltvType)
        internal
        view
        virtual
        returns (uint256 value)
    {
        ConfigAmount ltv = getLTV(collateral, ltvType);
        if (ltv.isZero()) return 0;

        uint256 balance = IERC20(collateral).balanceOf(account);
        if (balance == 0) return 0;

        // bid price for collateral
        (uint256 currentCollateralValue,) = vaultCache.oracle.getQuotes(balance, collateral, vaultCache.unitOfAccount);

        // If collateral value is huge the following line can overflow. If the vault wasn't misconfigured, it should 
        // only be possible if the collateral value is manipulated on the oracle, by which point the vault is compromised anyway.
        return ltv.toUint16() * currentCollateralValue / 1e4;
    }

    function validateOracle(VaultCache memory vaultCache) internal pure {
        if (address(vaultCache.oracle) == address(0)) revert E_NoPriceOracle();
    }
}
