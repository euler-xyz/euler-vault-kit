// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Invariant Contracts
import {BaseInvariants} from "./invariants/BaseInvariants.t.sol";
import {VaultSimpleInvariants} from "./invariants/VaultSimpleInvariants.t.sol";
import {VaultSimpleBorrowableInvariants} from "./invariants/VaultSimpleBorrowableInvariants.t.sol";
import {VaultRegularBorrowableInvariants} from "./invariants/VaultRegularBorrowableInvariants.t.sol";
import {VaultBorrowableWETHInvariants} from "./invariants/VaultBorrowableWETHInvariants.t.sol";

/// @title Invariants
/// @notice Wrappers for the protocol invariants implemented in BaseInvariants
/// @dev recognised by Echidna when property mode is activated
/// @dev Inherits BaseInvariants that inherits HandlerAggregator
abstract contract Invariants is
    BaseInvariants,
    VaultSimpleInvariants,
    VaultSimpleBorrowableInvariants,
    VaultRegularBorrowableInvariants,
    VaultBorrowableWETHInvariants
{
    uint256 private constant REENTRANCY_UNLOCKED = 1;

    function echidna_invariant_tryA() public returns (bool) {
        return true;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                 BASE INVARIANTS                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////
/* 
    function echidna_invariant_Base_invariantAB() public targetVaultsFrom(VaultType.Simple) returns (bool) {
        for (uint256 i = limitVault; i < vaults.length; i++) {
            assert_VaultBase_invariantA(vaults[i]);
            assert_VaultBase_invariantB(vaults[i]);
        }
        return true;
    } */

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         ERC4626                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////
/* 
    function echidna_invariant_ERC4626_assets_invariantAB() public targetVaultsFrom(VaultType.Simple) returns (bool) {
        for (uint256 i = limitVault; i < vaults.length; i++) {
            assert_ERC4626_assets_invariantA(vaults[i]);
            assert_ERC4626_assets_invariantB(vaults[i]);
        }
        return true;
    }

    function echidna_invariant_ERC4626_invariantC() public targetVaultsFrom(VaultType.Simple) returns (bool) {
        for (uint256 i = limitVault; i < vaults.length; i++) {
            assert_ERC4626_assets_invariantC(vaults[i]);
        }
        return true;
    }

    function echidna_invariant_ERC4626_invariantD() public targetVaultsFrom(VaultType.Simple) returns (bool) {
        for (uint256 i = limitVault; i < vaults.length; i++) {
            assert_ERC4626_assets_invariantD(vaults[i]);
        }
        return true;
    }

    function echidna_invariant_ERC4626_depositMintWithdrawRedeem_invariantA()
        public
        targetVaultsFrom(VaultType.Simple)
        returns (bool)
    {
        for (uint256 i = limitVault; i < vaults.length; i++) {
            for (uint256 j; j < NUMBER_OF_ACTORS; j++) {
                assert_ERC4626_deposit_invariantA(vaults[i], actorAddresses[j]);
                assert_ERC4626_mint_invariantA(vaults[i], actorAddresses[j]);
                assert_ERC4626_withdraw_invariantA(vaults[i], actorAddresses[j]);
                assert_ERC4626_redeem_invariantA(vaults[i], actorAddresses[j]);
            }
        }
        return true;
    } */

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                 VAULT SIMPLE INVARIANTS                                   //
    ///////////////////////////////////////////////////////////////////////////////////////////////
/* 
    function echidna_invariant_VaultSimple_invariantABCD() public targetVaultsFrom(VaultType.Simple) returns (bool) {
        for (uint256 i = limitVault; i < vaults.length; i++) {
            assert_VaultSimple_invariantA(vaults[i]);
            assert_VaultSimple_invariantB(vaults[i]);

            uint256 _sumBalanceOf;
            for (uint256 j; j < NUMBER_OF_ACTORS; j++) {
                _sumBalanceOf += assert_VaultSimple_invariantC(vaults[i], actorAddresses[j]);
            }
        }
        return true;
    } */

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                            VAULT SIMPLE BORROWABLE INVARIANTS                             //
    ///////////////////////////////////////////////////////////////////////////////////////////////
/* 
    function echidna_invariant_VaultSimpleBorrowable_invariantAB()
        public
        targetVaultsFrom(VaultType.SimpleBorrowable)
        returns (bool)
    {
        for (uint256 i = limitVault; i < vaults.length; i++) {
            for (uint256 j; j < NUMBER_OF_ACTORS; j++) {
                assert_VaultSimpleBorrowable_invariantA(vaults[i], actorAddresses[j]);
            }
            assert_VaultSimpleBorrowable_invariantB(vaults[i]);
        }
        return true;
    } */

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                           VAULT REGULAR BORROWABLE INVARIANTS                             //
    ///////////////////////////////////////////////////////////////////////////////////////////////

/*     function echidna_invariant_VaultRegularBorrowable_invariantA()
        public
        targetVaultsFrom(VaultType.RegularBorrowable)
        returns (bool)
    {
        for (uint256 i = limitVault; i < vaults.length; i++) {
            for (uint256 j; j < NUMBER_OF_ACTORS; j++) {
            }
        }
        return true;
    } */

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                            VAULT BORROWABLE WETH INVARIANTS                               //
    ///////////////////////////////////////////////////////////////////////////////////////////////
}
