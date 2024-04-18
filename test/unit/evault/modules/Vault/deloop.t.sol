// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVaultTestBase} from "../../EVaultTestBase.t.sol";
import {Errors} from "src/EVault/shared/Errors.sol";
import {IRMTestZero} from "../../../../mocks/IRMTestZero.sol";
import {Events} from "src/EVault/shared/Events.sol";

contract VaultTest_Deloop is EVaultTestBase {
    address user1;
    address user2;

    function setUp() public override {
        super.setUp();

        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        assetTST.mint(user1, 100e18);
        assetTST.mint(user2, 100e18);
        assetTST2.mint(user2, 100e18);

        startHoax(user1);
        assetTST.approve(address(eTST), type(uint256).max);
        assetTST2.approve(address(eTST2), type(uint256).max);
        eTST.deposit(1e18, user1);

        startHoax(user2);
        assetTST.approve(address(eTST), type(uint256).max);
        assetTST2.approve(address(eTST2), type(uint256).max);
        eTST2.deposit(50e18, user2);
        evc.enableCollateral(user2, address(eTST2));

        oracle.setPrice(address(eTST), unitOfAccount, 0.01e18);
        oracle.setPrice(address(eTST2), unitOfAccount, 0.05e18);

        startHoax(address(this));
        eTST.setLTV(address(eTST2), 0.21e4, 0);

        skip(31 * 60);
    }

    //burn with max_uint256 repays the debt in full or up to the available underlying balance
    function test_deloop_withMaxRepays() public {
        eTST.setInterestRateModel(address(new IRMTestZero()));

        assertEq(evc.getCollaterals(user2)[0], address(eTST2));

        assertEq(assetTST.balanceOf(user2), 100e18);
        assertEq(eTST.balanceOf(user2), 0);
        assertEq(eTST.debtOf(user2), 0);

        // Two separate borrows, .4 and .1:
        startHoax(user2);
        evc.enableController(user2, address(eTST));

        vm.expectEmit();
        emit Events.Transfer(address(0), user2, 0.4e18);
        eTST.borrow(0.4e18, user2);
        eTST.borrow(0.1e18, user2);

        // Make sure the borrow market is recorded
        assertEq(evc.getCollaterals(user2)[0], address(eTST2));
        assertEq(evc.getControllers(user2)[0], address(eTST));

        assertEq(assetTST.balanceOf(user2), 100.5e18);
        assertEq(eTST.balanceOf(user2), 0);
        assertEq(eTST.debtOf(user2), 0.5e18);

        // Wait 1 day
        skip(86400);

        // No interest was charged
        assertEq(eTST.debtOf(user2), 0.5e18);

        // nothing to burn
        eTST.deloop(type(uint256).max, user2);

        assertEq(assetTST.balanceOf(user2), 100.5e18);
        assertEq(eTST.balanceOf(user2), 0);
        assertEq(eTST.debtOf(user2), 0.5e18);

        // eVault balance is less than debt
        eTST.deposit(0.1e18, user2);
        eTST.deloop(type(uint256).max, user2);

        assertEq(assetTST.balanceOf(user2), 100.4e18);
        assertEq(eTST.balanceOf(user2), 0);
        assertEq(eTST.maxWithdraw(user2), 0);
        assertEq(eTST.debtOf(user2), 0.4e18);

        // eVault balance is greater than debt
        eTST.deposit(1e18, user2);
        eTST.deloop(type(uint256).max, user2);

        assertEq(assetTST.balanceOf(user2), 99.4e18);
        assertEq(eTST.balanceOf(user2), 0.6e18);
        assertEq(eTST.maxWithdraw(user2), 0.6e18);
        assertEq(eTST.debtOf(user2), 0);
    }

    //burn when owed amount is 0 is a no-op
    function test_deloop_whenOwedAmountZero() public {
        eTST.setInterestRateModel(address(new IRMTestZero()));

        assertEq(evc.getCollaterals(user2)[0], address(eTST2));

        startHoax(user2);
        eTST.deposit(1e18, user2);

        assertEq(assetTST.balanceOf(user2), 99e18);
        assertEq(eTST.balanceOf(user2), 1e18);
        assertEq(eTST.debtOf(user2), 0);

        evc.enableController(user2, address(eTST));
        eTST.deloop(type(uint256).max, user2);

        assertEq(assetTST.balanceOf(user2), 99e18);
        assertEq(eTST.balanceOf(user2), 1e18);
        assertEq(eTST.debtOf(user2), 0);
    }

    //burn for 0 is a no-op
    function test_deloop_forZero() public {
        eTST.setInterestRateModel(address(new IRMTestZero()));

        assertEq(evc.getCollaterals(user2)[0], address(eTST2));

        assertEq(assetTST.balanceOf(user2), 100e18);
        assertEq(eTST.balanceOf(user2), 0);
        assertEq(eTST.debtOf(user2), 0);

        startHoax(user2);
        evc.enableController(user2, address(eTST));
        eTST.borrow(0.5e18, user2);

        assertEq(assetTST.balanceOf(user2), 100.5e18);
        assertEq(eTST.balanceOf(user2), 0);
        assertEq(eTST.debtOf(user2), 0.5e18);

        // burning 0 is a no-op
        eTST.deloop(0, user2);
    }
}
