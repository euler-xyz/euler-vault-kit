// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ESVaultTestBase, ESynth} from "./ESVaultTestBase.t.sol";
import {Errors} from "../../../src/EVault/shared/Errors.sol";

contract ESVaultTestAllocate is ESVaultTestBase {
    function setUp() public override {
        super.setUp();

        assetTSTAsSynth.setCapacity(address(this), 10000e18);
    }

    function test_allocate_from_non_synth() public {
        // enable all the ops to show that when only asset is configured to deposit, mint and skim will fail
        eTST.setLockedOps(0);
        eTST.setDisabledOps(0);

        vm.expectRevert(Errors.E_OnlyAssetCanDeposit.selector);
        eTST.deposit(100, address(this));

        vm.expectRevert(Errors.E_OnlyAssetCanDeposit.selector);
        eTST.mint(100, address(this));

        assetTSTAsSynth.mint(address(eTST), 100);
        vm.expectRevert(Errors.E_OnlyAssetCanDeposit.selector);
        eTST.skim(100, address(this));
    }

    function test_allocate_from_synth() public {
        assetTSTAsSynth.mint(address(assetTSTAsSynth), 100);
        assetTSTAsSynth.allocate(address(eTST), 100);

        assertEq(assetTSTAsSynth.isIgnoredForTotalSupply(address(eTST)), true);
        assertEq(assetTST.balanceOf(address(eTST)), 100);
        assertEq(eTST.balanceOf(address(assetTST)), 100);
    }
}
