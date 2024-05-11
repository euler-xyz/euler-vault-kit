// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVaultTestBase} from "test/unit/evault/EVaultTestBase.t.sol";
import {Errors} from "src/EVault/shared/Errors.sol";
import {IEVault} from "src/EVault/IEVault.sol";

contract Governance_SetSymbol is EVaultTestBase {
    address notGovernor;
    IEVault eTSTx;

    function setUp() public override {
        super.setUp();
        notGovernor = makeAddr("notGovernor");

        eTSTx = IEVault(factory.createProxy(true, abi.encodePacked(address(assetTST), address(oracle), unitOfAccount)));
    }

    function test_setSymbolShouldFailIfNotGovernor() public {
        vm.prank(notGovernor);
        vm.expectRevert(Errors.E_Unauthorized.selector);
        eTSTx.setSymbol("new symbol");
    }

    function test_governorShouldBeAbleToSetSymbol() public {
        eTSTx.setSymbol("");

        string memory symbol = "some symbol";
        eTSTx.setSymbol(symbol);
        assertEq(eTSTx.symbol(), symbol);

        vm.expectRevert(Errors.E_AlreadySet.selector);
        eTSTx.setSymbol("different symbol");
    }

    function test_governorSymbolEmptyShouldReturnUNKNOWN() public view {
        assertEq(eTSTx.symbol(), "UNKNOWN");
    }
}
