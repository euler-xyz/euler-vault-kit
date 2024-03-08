// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Actor} from "../utils/Actor.sol";
import {HandlerAggregator} from "../HandlerAggregator.t.sol";

/// @title VaultBorrowableWETHInvariants
/// @notice Implements Invariants for the protocol
/// @notice Implements View functions assertions for the protocol, checked in assertion testing mode
/// @dev Inherits HandlerAggregator for checking actions in assertion testing mode
abstract contract VaultBorrowableWETHInvariants is HandlerAggregator {
///////////////////////////////////////////////////////////////////////////////////////////////
//                   INVARIANTS SPEC: Handwritten / pseudo-code invariants                   //
///////////////////////////////////////////////////////////////////////////////////////////////

/*

    E.g. of an invariant spec
    Area 1
    Invariant A: totalSupply = sum of all balances
    Invariant B: totalSupply = sum of all balances
    
    */

/* 

    E.g. of an invariant   

    function assert_invariant_Area1_A(address _poolOwner) internal view {
        uint256 totalSupply = pool.totalSupply();
        uint256 sumBalances = 0;
        for (uint256 i = 0; i < pool.numAccounts(); i++) {
            sumBalances += pool.balances(pool.account(i));
        }
        assert(totalSupply == sumBalances);
    } 
    */
}

