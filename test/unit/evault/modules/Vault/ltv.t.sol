// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVaultTestBase} from "../../EVaultTestBase.t.sol";
import {Events} from "src/EVault/shared/Events.sol";

import "src/EVault/shared/types/Types.sol";
import "src/EVault/shared/Constants.sol";

contract ERC4626Test_LTV is EVaultTestBase {
    using TypesLib for uint256;

    address depositor;
    address borrower;

    function setUp() public override {
        super.setUp();

        // Setup

        oracle.setPrice(address(assetTST), unitOfAccount, 1e18);
        oracle.setPrice(address(eTST2), unitOfAccount, 1e18);
    }

    function test_rampDown() public {
        eTST.setLTV(address(eTST2), 0.9e4, 0);

        assertEq(eTST.borrowingLTV(address(eTST2)), 0.9e4);

        eTST.setLTV(address(eTST2), 0.4e4, 1000);

        assertEq(eTST.borrowingLTV(address(eTST2)), 0.4e4);
        assertEq(eTST.liquidationLTV(address(eTST2)), 0.9e4);

        skip(200);

        assertEq(eTST.borrowingLTV(address(eTST2)), 0.4e4);
        assertEq(eTST.liquidationLTV(address(eTST2)), 0.8e4);

        skip(300);

        assertEq(eTST.borrowingLTV(address(eTST2)), 0.4e4);
        assertEq(eTST.liquidationLTV(address(eTST2)), 0.65e4);

        skip(500);

        assertEq(eTST.borrowingLTV(address(eTST2)), 0.4e4);
        assertEq(eTST.liquidationLTV(address(eTST2)), 0.4e4);
    }

    function test_rampUp() public {
        eTST.setLTV(address(eTST2), 0.8e4, 1000);

        assertEq(eTST.borrowingLTV(address(eTST2)), 0.8e4);
        assertEq(eTST.liquidationLTV(address(eTST2)), 0.0e4);

        skip(250);

        assertEq(eTST.borrowingLTV(address(eTST2)), 0.8e4);
        assertEq(eTST.liquidationLTV(address(eTST2)), 0.2e4);

        skip(500);

        assertEq(eTST.borrowingLTV(address(eTST2)), 0.8e4);
        assertEq(eTST.liquidationLTV(address(eTST2)), 0.6e4);

        skip(5000);

        assertEq(eTST.borrowingLTV(address(eTST2)), 0.8e4);
        assertEq(eTST.liquidationLTV(address(eTST2)), 0.8e4);
    }

    function test_rampRetarget() public {
        eTST.setLTV(address(eTST2), 0.8e4, 1000);

        assertEq(eTST.borrowingLTV(address(eTST2)), 0.8e4);
        assertEq(eTST.liquidationLTV(address(eTST2)), 0.0e4);

        skip(250);

        assertEq(eTST.borrowingLTV(address(eTST2)), 0.8e4);
        assertEq(eTST.liquidationLTV(address(eTST2)), 0.2e4);

        eTST.setLTV(address(eTST2), 0.1e4, 1000);

        assertEq(eTST.borrowingLTV(address(eTST2)), 0.1e4);
        assertEq(eTST.liquidationLTV(address(eTST2)), 0.2e4);

        skip(500);

        assertEq(eTST.borrowingLTV(address(eTST2)), 0.1e4);
        assertEq(eTST.liquidationLTV(address(eTST2)), 0.15e4);

        skip(600);

        assertEq(eTST.borrowingLTV(address(eTST2)), 0.1e4);
        assertEq(eTST.liquidationLTV(address(eTST2)), 0.1e4);
    }

    function test_ltvRange() public {
        vm.expectRevert(Errors.E_InvalidConfigAmount.selector);
        eTST.setLTV(address(eTST2), 1e4 + 1, 0);
    }

    function test_ltvList() public {
        assertEq(eTST.LTVList().length, 0);

        eTST.setLTV(address(eTST2), 0.8e4, 0);

        assertEq(eTST.LTVList().length, 1);
        assertEq(eTST.LTVList()[0], address(eTST2));

        eTST.setLTV(address(eTST2), 0.0e4, 0);

        assertEq(eTST.LTVList().length, 1);
        assertEq(eTST.LTVList()[0], address(eTST2));

        eTST.setLTV(address(eTST2), 0.4e4, 0);

        assertEq(eTST.LTVList().length, 1);
        assertEq(eTST.LTVList()[0], address(eTST2));
    }

    function test_ltvList_explicitZero() public {
        assertEq(eTST.LTVList().length, 0);

        eTST.setLTV(address(eTST2), 0.0e4, 0);

        assertEq(eTST.borrowingLTV(address(eTST2)), 0.0e4);
        assertEq(eTST.liquidationLTV(address(eTST2)), 0.0e4);

        assertEq(eTST.LTVList().length, 1);
        assertEq(eTST.LTVList()[0], address(eTST2));

        eTST.setLTV(address(eTST2), 0.0e4, 0);

        assertEq(eTST.LTVList().length, 1);
        assertEq(eTST.LTVList()[0], address(eTST2));
    }
}
