// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title InvariantsSpec
/// @notice Invariants specification for the protocol
/// @dev Contains pseudo code and description for the invariants in the protocol
/// @dev Invariants for Token, Vault, Borrowing, Liquidations mechanics
abstract contract InvariantsSpec {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          BASE                                             //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    string constant BASE_INVARIANT_A = "BASE_INVARIANT_A: reentrancyLock == REENTRANCY_UNLOCKED";

    string constant BASE_INVARIANT_B = "BASE_INVARIANT_B: snapshot == 0";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       TOKEN MODULE                                        //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    string constant TM_INVARIANT_A = "TM_INVARIANT_A: totalSupply = sum of all balances";

    string constant TM_INVARIANT_B = "TM_INVARIANT_B: totalSupply = sum of all balances";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       VAULT MODULE                                        //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    string constant VM_INVARIANT_A = "VM_INVARIANT_A: reentrancyLock == REENTRANCY_UNLOCKED";

    string constant VM_INVARIANT_B = "VM_INVARIANT_B: snapshot == 0";

    string constant VM_INVARIANT_C = "VM_INVARIANT_C: at most we can only have one liability between calls";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                     BORROWING MODULE                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    string constant BM_INVARIANT_A = "BM_INVARIANT_A: totalBorrowed = sum of all borrow balances";

    string constant BM_INVARIANT_B = "BM_INVARIANT_B: totalBorrowed = sum of all borrow balances";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                    LIQUIDATIONS MODULE                                    //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    string constant LM_INVARIANT_A = "LM_INVARIANT_A: totalLiquidated = sum of all liquidation balances";

}