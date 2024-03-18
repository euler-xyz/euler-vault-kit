// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ESVaultTestBase, ESynth} from "./ESVaultTestBase.t.sol";
import {Errors} from "../../../src/EVault/shared/Errors.sol";

contract ESVaultTestDeposit is ESVaultTestBase {

    function setUp() public override {
        super.setUp();

        assetTSTAsSynth.setCapacity(address(this), 10000e18);
    }

    function test_deposit_from_non_synth() public {
        vm.expectRevert(Errors.E_Unauthorized.selector);
        eTST.deposit(100, address(this));
    }

    function test_deposit_from_synth() public {
        assetTSTAsSynth.mint(address(assetTSTAsSynth), 100);
        assetTSTAsSynth.deposit(address(eTST), 100);

        assertEq(assetTST.balanceOf(address(eTST)), 100);
        assertEq(eTST.balanceOf(address(assetTST)), 100);
    }
}
