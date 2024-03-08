// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

// Test Helpers
import {Pretty, Strings} from "../utils/Pretty.sol";

// Test Contracts
import {BaseHooks} from "../base/BaseHooks.t.sol";

// Interfaces
import {IERC20} from "src/EVault/IEVault.sol";

/// @title Vault Before After Hooks
/// @notice Helper contract for before and after hooks
/// @dev This contract is inherited by handlers
abstract contract VaultBeforeAfterHooks is BaseHooks {
    using Strings for string;
    using Pretty for uint256;
    using Pretty for int256;
    using Pretty for bool;

    struct VaultVars {
        // Exchange Rate
        uint256 exchangeRateBefore;
        uint256 exchangeRateAfter;
        // ERC4626
        uint256 totalAssetsBefore;
        uint256 totalAssetsAfter;
        // Caps
        uint256 supplyCapBefore;
        uint256 supplyCapAfter;
        // Fees
        uint256 feesBalanceBefore;
        uint256 feesBalanceAfter;
        uint256 feesBalanceAssetsBefore;
        uint256 feesBalanceAssetsAfter;
    }
    // TODO: supply caps

    VaultVars vaultVars;

    function _vaultHooksBefore() internal {
        // Exchange Rate
        vaultVars.exchangeRateBefore = _calculateExchangeRate();
        // ERC4626
        vaultVars.totalAssetsBefore = eTST.totalAssets();
        // Caps
        //vaultVars.supplyCapBefore = eTST.supplyCap();
        // Fees
        vaultVars.feesBalanceBefore = eTST.feesBalance();
        vaultVars.feesBalanceAssetsBefore = eTST.feesBalanceAssets();
    }

    function _vaultHooksAfter() internal {
        // Exchange Rate
        vaultVars.exchangeRateAfter = _calculateExchangeRate();
        // ERC4626
        vaultVars.totalAssetsAfter = eTST.totalAssets();
        // Caps
        //vaultVars.supplyCapAfter = eTST.supplyCap();
        // Fees
        vaultVars.feesBalanceAfter = eTST.feesBalance();
        vaultVars.feesBalanceAssetsAfter = eTST.feesBalanceAssets();
    }

    /*/////////////////////////////////////////////////////////////////////////////////////////////
    //                                     POST CONDITIONS                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    VaultSimpleBorrowable
        Post Condition A: (borrowCapAfter != 0) && (totalBorrowedAfter >= totalBorrowedBefore) 
            => borrowCapAfter >= totalBorrowedAfter
        Post Condition B: Controller cannot be disabled if there is any liability  
    */

    /////////////////////////////////////////////////////////////////////////////////////////////*/

    /*     function assert_VaultSimpleBorrowable_PcA() internal {
        assertTrue(
            (svbVars.totalBorrowedAfter > svbVars.totalBorrowedBefore && svbVars.borrowCapAfter != 0)
                ? (svbVars.borrowCapAfter >= svbVars.totalBorrowedAfter)
                : true,
            "(totalBorrowedAfter > totalBorrowedBefore)"
        );
    }

    function assert_VaultSimpleBorrowable_PcB() internal {
        if (svbVars.userDebtBefore > 0) {
            assertEq(svbVars.controllerEnabledAfter, true, "Controller cannot be disabled if there is any liability");
        }
    } */
}
