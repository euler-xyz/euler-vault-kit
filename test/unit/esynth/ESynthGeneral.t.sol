// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {ESynthTest} from "./lib/ESynthTest.sol";
import {stdError} from "forge-std/Test.sol";
import {Errors} from "../../../src/EVault/shared/Errors.sol";
import {ESynth} from "../../../src/Synths/ESynth.sol";
import {MockWrongEVC} from "../../mocks/MockWrongEVC.sol";

contract ESynthGeneralTest is ESynthTest {
    uint128 constant MAX_ALLOWED = type(uint128).max;

    MockWrongEVC public wrongEVC = new MockWrongEVC();

    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);

    function testFuzz_mintShouldIncreaseTotalSupplyAndBalance(uint128 amount) public {
        amount = uint128(bound(amount, 0, MAX_ALLOWED));
        uint256 balanceBefore = esynth.balanceOf(user1);
        uint256 totalSupplyBefore = esynth.totalSupply();
        esynth.setCapacity(address(this), MAX_ALLOWED);

        esynth.mint(user1, amount);
        assertEq(esynth.balanceOf(user1), balanceBefore + amount);
        assertEq(esynth.totalSupply(), totalSupplyBefore + amount);
    }

    function testFuzz_burnShouldDecreaseTotalSupplyAndBalance(uint128 initialAmount, uint128 burnAmount) public {
        initialAmount = uint128(bound(initialAmount, 1, MAX_ALLOWED));
        esynth.setCapacity(address(this), MAX_ALLOWED);
        esynth.mint(user1, initialAmount);
        burnAmount = uint128(bound(burnAmount, 1, initialAmount));

        vm.expectRevert(abi.encodeWithSelector(ERC20InsufficientAllowance.selector, user2, 0, burnAmount));
        vm.prank(user2);
        esynth.burn(user1, burnAmount);

        vm.prank(user1);
        esynth.approve(user2, burnAmount);

        uint256 allowanceBefore = esynth.allowance(user1, user2);
        uint256 balanceBefore = esynth.balanceOf(user1);
        uint256 totalSupplyBefore = esynth.totalSupply();

        vm.prank(user2);
        esynth.burn(user1, burnAmount);

        assertEq(esynth.balanceOf(user1), balanceBefore - burnAmount);
        assertEq(esynth.totalSupply(), totalSupplyBefore - burnAmount);
        if (allowanceBefore != type(uint256).max) {
            assertEq(esynth.allowance(user1, address(this)), allowanceBefore - burnAmount);
        } else {
            assertEq(esynth.allowance(user1, address(this)), type(uint256).max);
        }
    }

    function testFuzz_mintCapacityReached(uint128 capacity, uint128 amount) public {
        capacity = uint128(bound(capacity, 0, MAX_ALLOWED));
        amount = uint128(bound(amount, 0, MAX_ALLOWED));
        vm.assume(capacity < amount);
        esynth.setCapacity(address(this), capacity);
        vm.expectRevert(ESynth.E_CapacityReached.selector);
        esynth.mint(user1, amount);
    }

    // burn of amount more then minted shoud reset minterCache.minted to 0
    function testFuzz_burnMoreThanMinted(uint128 amount) public {
        amount = uint128(bound(amount, 0, MAX_ALLOWED / 2));
        // one minter mints
        esynth.setCapacity(user2, amount); // we set the cap to less then
        vm.prank(user2);
        esynth.mint(address(esynth), amount);

        // another minter mints
        esynth.setCapacity(user1, amount); // we set the cap to less then
        vm.prank(user1);
        esynth.mint(address(esynth), amount);

        // the owner of the synth can always burn from synth
        esynth.burn(address(esynth), amount * 2);

        (, uint128 minted) = esynth.minters(address(this));
        assertEq(minted, 0);
    }

    function testFuzz_burnFromOwner(uint128 amount) public {
        amount = uint128(bound(amount, 1, MAX_ALLOWED));
        esynth.setCapacity(user1, MAX_ALLOWED);
        vm.prank(user1);
        esynth.mint(user1, amount);

        // the owner of the synth can always burn from synth but cannot from other accounts without allowance
        vm.expectRevert(abi.encodeWithSelector(ERC20InsufficientAllowance.selector, address(this), 0, amount));
        esynth.burn(user1, amount);

        vm.prank(user1);
        esynth.approve(address(this), amount);
        esynth.burn(user1, amount);

        assertEq(esynth.balanceOf(user1), 0);
    }

    function testFuzz_depositSimple(uint128 amount) public {
        amount = uint128(bound(amount, 1, type(uint112).max)); // amount needs to be less then MAX_SANE_AMOUNT
        esynth.setCapacity(address(this), MAX_ALLOWED);
        esynth.mint(address(esynth), amount); // address(this) should be owner
        esynth.allocate(address(eTST), amount);
    }

    function testFuzz_depositTooLarge(uint128 amount) public {
        amount = uint128(bound(amount, uint256(type(uint112).max) + 1, MAX_ALLOWED));
        esynth.setCapacity(address(this), MAX_ALLOWED);
        esynth.mint(address(esynth), amount);
        vm.expectRevert(Errors.E_AmountTooLargeToEncode.selector);
        esynth.allocate(address(eTST), amount);
    }

    function testFuzz_withdrawSimple(uint128 amount) public {
        amount = uint128(bound(amount, 1, type(uint112).max));
        esynth.setCapacity(address(this), MAX_ALLOWED);
        esynth.mint(address(esynth), amount);
        esynth.allocate(address(eTST), amount);
        esynth.deallocate(address(eTST), amount);
    }

    function test_AllocateInCompatibleVault() public {
        uint256 amount = 100e18;
        esynth.setCapacity(address(this), MAX_ALLOWED);
        esynth.mint(address(esynth), amount);
        vm.expectRevert(ESynth.E_NotEVCCompatible.selector);
        esynth.allocate(address(wrongEVC), amount);
    }

    function test_GovernanceModifiers(address owner, uint8 id, address nonOwner, uint128 amount) public {
        vm.assume(owner != address(0) && owner != address(evc));
        vm.assume(!evc.haveCommonOwner(owner, nonOwner) && nonOwner != address(evc));
        vm.assume(id != 0);

        vm.prank(owner);
        esynth = ESynth(address(new ESynth(address(evc), "Test Synth", "TST")));

        // succeeds if called directly by an owner
        vm.prank(owner);
        esynth.setCapacity(address(this), amount);

        // fails if called by a non-owner
        vm.prank(nonOwner);
        vm.expectRevert();
        esynth.setCapacity(address(this), amount);

        // succeeds if called by an owner through the EVC
        vm.prank(owner);
        evc.call(address(esynth), owner, 0, abi.encodeCall(ESynth.setCapacity, (address(this), amount)));

        // fails if called by non-owner through the EVC
        vm.prank(nonOwner);
        vm.expectRevert();
        evc.call(address(esynth), nonOwner, 0, abi.encodeCall(ESynth.setCapacity, (address(this), amount)));

        // fails if called by a sub-account of an owner through the EVC
        vm.prank(owner);
        vm.expectRevert();
        evc.call(
            address(esynth),
            address(uint160(owner) ^ id),
            0,
            abi.encodeCall(ESynth.setCapacity, (address(this), amount))
        );

        // fails if called by the owner operator through the EVC
        vm.prank(owner);
        evc.setAccountOperator(owner, nonOwner, true);
        vm.prank(nonOwner);
        vm.expectRevert();
        evc.call(address(esynth), owner, 0, abi.encodeCall(ESynth.setCapacity, (address(this), amount)));
    }

    function test_RenounceTransferOwnership() public {
        address OWNER = makeAddr("OWNER");
        address OWNER2 = makeAddr("OWNER2");
        address OWNER3 = makeAddr("OWNER3");

        vm.prank(OWNER);
        esynth = ESynth(address(new ESynth(address(evc), "Test Synth", "TST")));
        assertEq(esynth.owner(), OWNER);

        vm.prank(OWNER2);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, OWNER2));
        esynth.renounceOwnership();

        vm.prank(OWNER2);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, OWNER2));
        esynth.transferOwnership(OWNER2);

        vm.prank(OWNER);
        esynth.transferOwnership(OWNER2);
        assertEq(esynth.owner(), OWNER2);

        vm.prank(OWNER2);
        esynth.transferOwnership(OWNER3);
        assertEq(esynth.owner(), OWNER3);

        vm.prank(OWNER2);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, OWNER2));
        esynth.renounceOwnership();

        vm.prank(OWNER3);
        esynth.renounceOwnership();
        assertEq(esynth.owner(), address(0));
    }
}
