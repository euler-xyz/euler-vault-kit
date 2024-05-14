// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVaultTestBase} from "../../EVaultTestBase.t.sol";
import {Events} from "src/EVault/shared/Events.sol";

import "src/EVault/shared/types/Types.sol";
import "src/EVault/shared/Constants.sol";

contract VaultTest_LTV is EVaultTestBase {
    using TypesLib for uint256;

    address depositor;
    address borrower;

    function setUp() public override {
        super.setUp();

        // Setup

        oracle.setPrice(address(assetTST), unitOfAccount, 1e18);
        oracle.setPrice(address(assetTST2), unitOfAccount, 1e18);

        depositor = makeAddr("depositor");
        borrower = makeAddr("borrower");
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
        // ramping up is not allowed
        vm.expectRevert(Errors.E_LTVRamp.selector);
        eTST.setLTV(address(eTST2), 0.8e4, 1000);

        eTST.setLTV(address(eTST2), 0.8e4, 0);

        // ramping to stay the same is not allowed
        vm.expectRevert(Errors.E_LTVRamp.selector);
        eTST.setLTV(address(eTST2), 0.8e4, 1000);

        eTST.setLTV(address(eTST2), 0.1e4, 1000);

        skip(250);

        assertEq(eTST.borrowingLTV(address(eTST2)), 0.1e4);
        assertEq(eTST.liquidationLTV(address(eTST2)), 0.625e4);

        // ramp up on a way down is not allowed
        vm.expectRevert(Errors.E_LTVRamp.selector);
        eTST.setLTV(address(eTST2), 0.65e4, 1000);

        // can jump immediatelly
        eTST.setLTV(address(eTST2), 0.65e4, 0);

        // ramp down again
        eTST.setLTV(address(eTST2), 0.1e4, 1000);

        skip(250);

        assertEq(eTST.liquidationLTV(address(eTST2)), 0.5125e4);

        // can retarget - set a lower LTV with a new ramp
        eTST.setLTV(address(eTST2), 0.5e4, 100);

        skip(50);

        assertEq(eTST.borrowingLTV(address(eTST2)), 0.5e4);
        assertEq(eTST.liquidationLTV(address(eTST2)), 0.5062e4);

        skip(50);

        // on new target
        assertEq(eTST.borrowingLTV(address(eTST2)), 0.5e4);
        assertEq(eTST.liquidationLTV(address(eTST2)), 0.5e4);
    }

    function test_ltvSelfCollateral() public {
        vm.expectRevert(Errors.E_InvalidLTVAsset.selector);
        eTST.setLTV(address(eTST), 0.5e4, 0);
    }

    function test_ltvRange() public {
        vm.expectRevert(Errors.E_InvalidConfigAmount.selector);
        eTST.setLTV(address(eTST2), 1e4 + 1, 0);
    }

    function test_clearLtv() public {
        eTST.setLTV(address(eTST2), 0.5e4, 0);

        startHoax(borrower);
        evc.enableCollateral(borrower, address(eTST2));
        evc.enableController(borrower, address(eTST));
        skip(1);
        vm.stopPrank();

        // No borrow, liquidation is a no-op
        (uint256 maxRepay, uint256 maxYield) = eTST.checkLiquidation(depositor, borrower, address(eTST2));
        assertEq(maxRepay, 0);
        assertEq(maxYield, 0);

        // setting LTV to 0 doesn't change anything yet
        eTST.setLTV(address(eTST2), 0, 0);

        (maxRepay, maxYield) = eTST.checkLiquidation(depositor, borrower, address(eTST2));
        assertEq(maxRepay, 0);
        assertEq(maxYield, 0);

        // collateral without LTV
        vm.expectRevert(Errors.E_BadCollateral.selector);
        eTST.checkLiquidation(depositor, borrower, address(eTST));

        // same error after clearing LTV
        eTST.clearLTV(address(eTST2));
        vm.expectRevert(Errors.E_BadCollateral.selector);
        eTST.checkLiquidation(depositor, borrower, address(eTST2));
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
