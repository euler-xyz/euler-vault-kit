// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Actor} from "../utils/Actor.sol";
import {HandlerAggregator} from "../HandlerAggregator.t.sol";

// Contracts

/// @title BaseInvariants
/// @notice Implements Invariants for the protocol
/// @notice Implements View functions assertions for the protocol, checked in assertion testing mode
/// @dev Inherits HandlerAggregator for checking actions in assertion testing mode
abstract contract BaseInvariants is HandlerAggregator {
    /*/////////////////////////////////////////////////////////////////////////////////////////////
    //                   INVARIANTS SPEC: Handwritten / pseudo-code invariants                   //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    BaseInvariants
        Invariant A: reentrancyLock == REENTRANCY_UNLOCKED
        Invariant B: snapshot == 0
        TODO: at most we can only have one liability between calls
    */

    /////////////////////////////////////////////////////////////////////////////////////////////*/

/*     function assert_VaultBase_invariantA(address _vault) internal {
        assertEq(VaultSimple(_vault).getReentrancyLock(), 1, string.concat("VaultBase_invariantA: ", vaultNames[_vault]));
    }

    function assert_VaultBase_invariantB(address _vault) internal {
        assertEq(VaultSimple(_vault).getSnapshotLength(), 0, string.concat("VaultBase_invariantB: ", vaultNames[_vault]));
    } */
}
