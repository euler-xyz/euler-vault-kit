// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

// Test Helpers
import {Pretty, Strings} from "../utils/Pretty.sol";

// Test Contracts
import {BaseHooks} from "../base/BaseHooks.t.sol";

/// @title Token Before After Hooks
/// @notice Helper contract for before and after hooks
/// @dev This contract is inherited by handlers
abstract contract TokenBeforeAfterHooks is BaseHooks {
    using Strings for string;
    using Pretty for uint256;
    using Pretty for int256;
    using Pretty for bool;

    struct TokenVars {
        uint256 totalSupplyBefore;
        uint256 totalSupplyAfter;
    }

    TokenVars tokenVars;

    function _tokenHooksBefore() internal {
        tokenVars.totalSupplyBefore = eTST.totalSupply();
    }

    function _tokenHooksAfter() internal {
        tokenVars.totalSupplyAfter = eTST.totalSupply();
    }

    /*/////////////////////////////////////////////////////////////////////////////////////////////
    //                                     POST CONDITIONS                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    VaultSimple
        Post Condition A: 
            (supplyCapAfter != 0) && (totalSupplyAfter >= totalSupplyBefore) => supplyCapAfter >= totalSupplyAfter
            
        */

    /////////////////////////////////////////////////////////////////////////////////////////////*/

    /*     function assert_VaultSimple_PcA() internal {
        assertTrue(
            (svVars.totalSupplyAfter > svVars.totalSupplyBefore && svVars.supplyCapAfter != 0)
                ? (svVars.supplyCapAfter >= svVars.totalSupplyAfter)
                : true,
            "(totalSupplyAfter > totalSupplyBefore)"
        );
    } */
}
