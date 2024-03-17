// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ESynthTest} from "./lib/ESynthTest.sol";

contract ESynthGeneralTest is ESynthTest {
    function testFuzz_mintShouldIncreaseTotalSupplyAndBalance(uint256 amount) public {
        amount = bound(amount, 0, type(uint256).max);
        uint256 balanceBefore = esynth.balanceOf(user1);
        uint256 totalSupplyBefore = esynth.totalSupply();
        esynth.mint(user1, amount);
        assertEq(esynth.balanceOf(user1), balanceBefore + amount);
        assertEq(esynth.totalSupply(), totalSupplyBefore + amount);
    }

    function testFuzz_burnShouldDecreaseTotalSupplyAndBalance(uint256 initialAmount, uint256 burnAmount) public {
        initialAmount = bound(initialAmount, 0, type(uint256).max);
        esynth.mint(user1, initialAmount);
        burnAmount = bound(burnAmount, 0, initialAmount);

        vm.startPrank(user1);
        esynth.approve(address(this), burnAmount);
        vm.stopPrank();

        uint256 allowanceBefore = esynth.allowance(user1, address(this));
        uint256 balanceBefore = esynth.balanceOf(user1);
        uint256 totalSupplyBefore = esynth.totalSupply();
        esynth.burn(user1, burnAmount);

        assertEq(esynth.balanceOf(user1), balanceBefore - burnAmount);
        assertEq(esynth.totalSupply(), totalSupplyBefore - burnAmount);
        if (allowanceBefore != type(uint256).max) {
            assertEq(esynth.allowance(user1, address(this)), allowanceBefore - burnAmount);
        } else {
            assertEq(esynth.allowance(user1, address(this)), type(uint256).max);
        }
    }
}
