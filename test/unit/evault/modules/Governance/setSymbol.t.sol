// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVaultTestBase} from "test/unit/evault/EVaultTestBase.t.sol";
import {Errors} from "src/EVault/shared/Errors.sol";

contract Governance_SetSymbol is EVaultTestBase {
    address notGovernor;

    function setUp() public override {
        super.setUp();
        notGovernor = makeAddr("notGovernor");
    }

    function testFuzz_setSymbolShouldFailIfNotGovernor(string memory symbol) public {
        vm.prank(notGovernor);
        vm.expectRevert(Errors.E_Unauthorized.selector);
        eTST.setSymbol(symbol);
    }

    function testFuzz_governorShouldBeAbleToSetSymbol(string memory symbol) public {
        vm.assume(bytes(symbol).length > 0);
        eTST.setSymbol(symbol);
        assertEq(eTST.symbol(), symbol);
    }

    function test_governorSetSymbolEmptyShouldReturnUNKNOWN() public {
        eTST.setSymbol("");
        assertEq(eTST.symbol(), "UNKNOWN");
    }
}
