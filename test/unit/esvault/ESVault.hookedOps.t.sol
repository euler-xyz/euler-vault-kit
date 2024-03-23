// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ESVaultTestBase, ESynth} from "./ESVaultTestBase.t.sol";
import {Errors} from "../../../src/EVault/shared/Errors.sol";

contract ESVaultTestHookedOps is ESVaultTestBase {
    function setUp() public override {
        super.setUp();
    }

    function test_hooked_ops_after_init() public view {
        uint32 hookedOps = eTST.hookedOps();
        assertEq(hookedOps, SYNTH_VAULT_HOOKED_OPS);
    }

    function test_hooked_ops_disabled_if_no_hook_target() public {
        eTST.setHookTarget(address(0));

        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.deposit(100, address(this));

        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.mint(100, address(this));

        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.redeem(100, address(this), address(this));

        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.skim(100, address(this));

        evc.enableController(address(this), address(eTST));
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.loop(100, address(this));

        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.deloop(100, address(this));
    }
}
