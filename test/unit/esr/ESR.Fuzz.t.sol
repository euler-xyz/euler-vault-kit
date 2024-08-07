// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import "./lib/ESRTest.sol";

import "forge-std/Test.sol";

contract ESRFuzzTest is ESRTest {
    function invariant_interestLeftGreaterThanAccruedInterest() public view {
        EulerSavingsRate.ESRSlot memory esrSlot = esr.getESRSlot();
        uint256 accruedInterest = esr.interestAccrued();
        assertGe(esrSlot.interestLeft, accruedInterest);
    }

    //totalAssets should be equal to the balance after SMEAR has passed
    function invariant_totalAssetsShouldBeEqualToBalanceAfterSMEAR() public {
        if (asset.totalSupply() > type(uint248).max) return;
        if (asset.balanceOf(address(esr)) == 0 || asset.balanceOf(address(esr)) > type(uint168).max - 1e7) return;

        // min deposit requirement before gulp
        doDeposit(user, 1e7);

        uint256 balance = asset.balanceOf(address(esr));

        esr.gulp();
        skip(esr.INTEREST_SMEAR()); // make sure smear has passed

        assertEq(esr.totalAssets(), balance);
    }

    function testFuzz_interestAccrued_under_uint168(uint256 interestAmount, uint256 depositAmount, uint256 timePassed)
        public
    {
        depositAmount = bound(depositAmount, 0, type(uint112).max);
        // this makes sure that the mint won't cause overflow in token accounting
        interestAmount = bound(interestAmount, 0, type(uint112).max - depositAmount);
        timePassed = bound(timePassed, block.timestamp, type(uint40).max);
        doDeposit(user, depositAmount);
        asset.mint(address(esr), interestAmount);
        esr.gulp();
        vm.warp(timePassed);
        uint256 interestAccrued = esr.interestAccrued();
        assertLe(interestAccrued, type(uint168).max);
    }

    // this tests shows that when you have a very small deposit and a very large interestAmount minted to the contract
    function testFuzz_gulp_under_uint168(uint256 interestAmount, uint256 depositAmount) public {
        uint256 MIN_SHARES_FOR_GULP = 10 * 1e6;
        depositAmount = bound(depositAmount, 0, type(uint112).max);
        interestAmount = bound(interestAmount, 0, type(uint256).max - depositAmount); // this makes sure that the mint
            // won't cause overflow

        asset.mint(address(esr), interestAmount);
        doDeposit(user, depositAmount);

        esr.gulp();

        EulerSavingsRate.ESRSlot memory esrSlot = esr.updateInterestAndReturnESRSlotCache();

        if (depositAmount >= MIN_SHARES_FOR_GULP) {
            if (interestAmount <= type(uint168).max) {
                assertEq(esrSlot.interestLeft, interestAmount);
            } else {
                assertEq(esrSlot.interestLeft, type(uint168).max);
            }
        } else {
            assertEq(esrSlot.interestLeft, 0);
        }
    }

    function testFuzz_conditionalAccruedInterestUpdate(uint32 interestAmount) public {
        // min deposit requirement before gulp
        doDeposit(user, 1e7);

        // mint some interest to be distributed
        asset.mint(address(esr), interestAmount);

        uint256 balance = asset.balanceOf(address(esr));
        uint256 totalAssets = esr.totalAssets();

        esr.gulp();
        skip(1);

        if (interestAmount < esr.INTEREST_SMEAR()) {
            assertEq(esr.totalAssets(), totalAssets);
            assertEq(esr.totalAssets() + interestAmount, balance);
        } else {
            uint256 accruedInterest = interestAmount / esr.INTEREST_SMEAR();
            assertEq(esr.totalAssets() + interestAmount - accruedInterest, balance);
            vm.expectEmit();
            emit EulerSavingsRate.InterestUpdated(accruedInterest, interestAmount - accruedInterest);
        }

        vm.recordLogs();
        esr.gulp();

        Vm.Log[] memory logs = vm.getRecordedLogs();
        if (interestAmount < esr.INTEREST_SMEAR()) {
            assertEq(logs.length, 1);
            assertNotEq(logs[0].topics[0], EulerSavingsRate.InterestUpdated.selector);
        } else {
            assertEq(logs.length, 2);
            assertEq(logs[0].topics[0], EulerSavingsRate.InterestUpdated.selector);
        }
    }

    // fuzz test that any deposits added are added to the totalAssetsDeposited
    function testFuzz_deposit(uint256 depositAmount, uint256 depositAmount2) public {
        depositAmount = bound(depositAmount, 0, type(uint112).max);
        depositAmount2 = bound(depositAmount2, 0, type(uint112).max - depositAmount); // prevents overflow
        doDeposit(address(1), depositAmount);
        doDeposit(address(2), depositAmount2);
        assertEq(esr.totalAssets(), depositAmount + depositAmount2);
    }

    // fuzz test that any withdraws are subtracted from the totalAssetsDeposited
    function testFuzz_withdraw(uint256 depositAmount, uint256 withdrawAmount) public {
        depositAmount = bound(depositAmount, 0, type(uint112).max);
        withdrawAmount = bound(withdrawAmount, 0, depositAmount);
        doDeposit(address(1), depositAmount);
        vm.startPrank(address(1));
        esr.withdraw(withdrawAmount, address(1), address(1));
        vm.stopPrank();
        assertEq(esr.totalAssets(), depositAmount - withdrawAmount);
    }
}
