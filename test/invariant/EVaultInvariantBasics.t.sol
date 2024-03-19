// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {EVaultHandler} from "test/invariant/handlers/EVaultHandler.t.sol";
import "forge-std/console2.sol";

contract EVaultInvariantBasicsTest is Test {
    EVaultHandler handler;

    function setUp() public {
        handler = new EVaultHandler();
        handler.setUp();
        targetContract(address(handler));
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = handler.deposit.selector;
        selectors[1] = handler.redeem.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    function invariant_assetBalance() public {
        uint256 assetBalanceOf_Ghost = handler.ghost_assetTST1Balance();
        console2.log("assetBalanceOf_Ghost: ", assetBalanceOf_Ghost);
        uint256 assetBalanceOf_Real = handler.assetTST1().balanceOf(address(handler));
        console2.log("assetBalanceOf_Real: ", assetBalanceOf_Real);
        assertEq(assetBalanceOf_Ghost, assetBalanceOf_Real);
    }
}
