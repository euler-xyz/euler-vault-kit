// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVaultTestBase} from "../../EVaultTestBase.t.sol";

import "src/EVault/shared/types/Types.sol";

contract ERC4626Test_Caps is EVaultTestBase {
    using TypesLib for uint256;

    address user;

    function setUp() public override {
        super.setUp();

        user = makeAddr("user");

        assetTST.mint(user, type(uint256).max);
        hoax(user);
        assetTST.approve(address(eTST), type(uint256).max);
    }

    function test_supplyCap() public {
        eTST.setMarketPolicy(0, uint16((3.62e2 << 6) | 18), 0); // 3.62e18

        hoax(user);
        vm.expectRevert(Errors.RM_SupplyCapExceeded.selector);
        eTST.deposit(3.6200001e18, user);

        hoax(user);
        eTST.deposit(3.62e18, user);

        assertEq(eTST.totalSupply(), 3.62e18);

        // Reduce cap

        eTST.setMarketPolicy(0, uint16((2.00e2 << 6) | 18), 0); // 3.62e18

        // Withdraw is allowed, even if it doesn't solve cap violation:

        hoax(user);
        eTST.withdraw(1e18, user, user);
        assertEq(eTST.totalSupply(), 2.62e18);

        // Still in excess of new cap so new deposits prevented:

        hoax(user);
        vm.expectRevert(Errors.RM_SupplyCapExceeded.selector);
        eTST.deposit(0.000001e18, user);
    }
}
