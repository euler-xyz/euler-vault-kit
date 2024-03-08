// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Base Contracts
import {Actor} from "../utils/Actor.sol";
import {HandlerAggregator} from "../HandlerAggregator.t.sol";

/// @title VaultBorrowableWETHInvariants
/// @notice Implements Invariants for the protocol
/// @notice Implements View functions assertions for the protocol, checked in assertion testing mode
/// @dev Inherits HandlerAggregator for checking actions in assertion testing mode
abstract contract VaultRegularBorrowableInvariants is HandlerAggregator {
    /*/////////////////////////////////////////////////////////////////////////////////////////////
    //                   INVARIANTS SPEC: Handwritten / pseudo-code invariants                   //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    VaultRegularBorrowable
        Invariant A: liquidation can only succed if violator is unhealthy (Post condition)
        
    */

    /////////////////////////////////////////////////////////////////////////////////////////////*/

}
