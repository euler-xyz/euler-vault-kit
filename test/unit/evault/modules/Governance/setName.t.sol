// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVaultTestBase} from "test/unit/evault/EVaultTestBase.t.sol";
import {Errors} from "src/EVault/shared/Errors.sol";

contract Governance_SetName is EVaultTestBase {
    address notGovernor;

    function setUp() public override {
        super.setUp();
        notGovernor = makeAddr("notGovernor");
    }

    function testFuzz_setNameShouldFailIfNotGovernor(string memory name) public {
        vm.prank(notGovernor);
        vm.expectRevert(Errors.E_Unauthorized.selector);
        eTST.setName(name);
    }

    function testFuzz_governorShouldBeAbleToSetName(string memory name) public {
        vm.assume(bytes(name).length > 0);
        eTST.setName(name);
        assertEq(eTST.name(), name);
    }

    function test_governorSetNameEmptyShouldReturnUnnamedEulerVault() public {
        eTST.setName("");
        assertEq(eTST.name(), "Unnamed Euler Vault");
    }
}
