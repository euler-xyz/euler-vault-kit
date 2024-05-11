// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVaultTestBase} from "test/unit/evault/EVaultTestBase.t.sol";
import {Errors} from "src/EVault/shared/Errors.sol";
import {IEVault} from "src/EVault/IEVault.sol";

contract Governance_SetNameSymbol is EVaultTestBase {
    address notGovernor;
    IEVault eTSTx;

    function setUp() public override {
        super.setUp();
        notGovernor = makeAddr("notGovernor");

        eTSTx = IEVault(factory.createProxy(true, abi.encodePacked(address(assetTST), address(oracle), unitOfAccount)));
    }

    function test_setNameShouldFailIfNotGovernor() public {
        vm.prank(notGovernor);
        vm.expectRevert(Errors.E_Unauthorized.selector);
        eTSTx.setName("new name");
    }

    function test_governorShouldBeAbleToSetName() public {
        eTSTx.setName("");

        string memory name = "new name";
        eTSTx.setName(name);
        assertEq(eTSTx.name(), name);

        vm.expectRevert(Errors.E_AlreadySet.selector);
        eTSTx.setName("different name");
    }

    function test_governorNameEmptyShouldReturnUnnamedEulerVault() public view {
        assertEq(eTSTx.name(), "Unnamed Euler Vault");
    }
}
