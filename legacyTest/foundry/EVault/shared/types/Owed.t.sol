// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.17;

import {Test, stdError} from "forge-std/Test.sol";

import "../../../../../contracts/EVault/shared/types/Types.sol";

contract OwedFuzzTest is Test {
    using TypesLib for uint256;

    //positive tests

    function test_toOwed(uint256 amount) public {
        vm.assume(amount <= MAX_SANE_DEBT_AMOUNT);

        Owed owed = amount.toOwed();

        assertEq(owed.toUint(), amount);
    }

    function test_addOwed(uint256 amount1, uint256 amount2) public {
        vm.assume(amount1 <= MAX_SANE_DEBT_AMOUNT);
        vm.assume(amount2 <= MAX_SANE_DEBT_AMOUNT);
        vm.assume(amount1 + amount2 <= MAX_SANE_DEBT_AMOUNT);

        uint256 result = amount1 + amount2;

        Owed owed1 = amount1.toOwed();
        Owed owed2 = amount2.toOwed();

        Owed resultOwed = owed1 + owed2;

        assertEq(resultOwed.toUint(), result);
    }

    function test_subOwed(uint256 amount1, uint256 amount2) public {
        vm.assume(amount1 <= MAX_SANE_DEBT_AMOUNT);
        vm.assume(amount2 <= MAX_SANE_DEBT_AMOUNT);
        vm.assume(amount1 >= amount2);

        uint256 result = amount1 - amount2;

        Owed owed1 = amount1.toOwed();
        Owed owed2 = amount2.toOwed();

        Owed resultOwed = owed1 - owed2;

        assertEq(resultOwed.toUint(), result);
    }

    function test_eqOwed(uint256 amount1, uint256 amount2) public {
        vm.assume(amount1 <= MAX_SANE_DEBT_AMOUNT);
        vm.assume(amount2 <= MAX_SANE_DEBT_AMOUNT);

        bool result = amount1 == amount2;

        Owed owed1 = amount1.toOwed();
        Owed owed2 = amount2.toOwed();

        bool resultEq = owed1 == owed2;

        assertEq(resultEq, result);
    }

    function test_neqOwed(uint256 amount1, uint256 amount2) public {
        vm.assume(amount1 <= MAX_SANE_DEBT_AMOUNT);
        vm.assume(amount2 <= MAX_SANE_DEBT_AMOUNT);

        bool result = amount1 != amount2;

        Owed owed1 = amount1.toOwed();
        Owed owed2 = amount2.toOwed();

        bool resultNeq = owed1 != owed2;

        assertEq(resultNeq, result);
    }

    function test_gtOwed(uint256 amount1, uint256 amount2) public {
        vm.assume(amount1 <= MAX_SANE_DEBT_AMOUNT);
        vm.assume(amount2 <= MAX_SANE_DEBT_AMOUNT);

        bool result = amount1 > amount2;

        Owed owed1 = amount1.toOwed();
        Owed owed2 = amount2.toOwed();

        bool resultGt = owed1 > owed2;

        assertEq(resultGt, result);
    }

    function test_ltOwed(uint256 amount1, uint256 amount2) public {
        vm.assume(amount1 <= MAX_SANE_DEBT_AMOUNT);
        vm.assume(amount2 <= MAX_SANE_DEBT_AMOUNT);

        bool result = amount1 > amount2;

        Owed owed1 = amount1.toOwed();
        Owed owed2 = amount2.toOwed();

        bool resultLt = owed1 > owed2;

        assertEq(resultLt, result);
    }

    function test_isZero(uint256 amount) public {
        vm.assume(amount <= MAX_SANE_DEBT_AMOUNT);

        Owed owed = amount.toOwed();

        bool result = owed.isZero();

        assertEq(result, amount == 0);
    }

    function test_isDust(uint256 amount) public {
        vm.assume(amount <= MAX_SANE_DEBT_AMOUNT);

        Owed owed = amount.toOwed();

        bool result = owed.isDust();

        assertEq(result, amount < 1e9);
    }

    function test_mulDiv(uint256 amount, uint256 multiplier, uint256 divisor) public {
        vm.assume(amount <= MAX_SANE_DEBT_AMOUNT);
        vm.assume(multiplier <= uint256(MAX_SANE_DEBT_AMOUNT) / (amount + 1));
        vm.assume(divisor != 0 && divisor <= type(uint144).max);

        Owed owed = amount.toOwed();

        Owed resultOwed = owed.mulDiv(multiplier, divisor);

        uint256 result = amount * multiplier / divisor;

        assertEq(resultOwed.toUint(), result);
    }

    function test_toAssetsUp(uint256 amount) public pure {
        vm.assume(amount <= type(uint144).max);

        Owed owed = amount.toOwed();

        vm.assume(owed.toAssetsUp().toUint() <= type(uint112).max);

        owed.toAssetsUp().toUint();
    }

    //negative tests

    function test_RevertWhenOverflowOwed_toOwed(uint256 amount) public {
        vm.assume(amount > MAX_SANE_DEBT_AMOUNT);

        vm.expectRevert(Errors.E_DebtAmountTooLargeToEncode.selector);

        amount.toOwed();
    }

    function test_RevertWhenOverflowOwed_addOwed() public {
        uint256 amount = type(uint144).max / 2 + 1;

        Owed owed = amount.toOwed();

        vm.expectRevert(Errors.E_DebtAmountTooLargeToEncode.selector);
        owed + owed;
    }

    function test_RevertWhenUnderflowShare_subOwed() public {
        uint256 amount1 = 0;
        uint256 amount2 = 1;

        Owed owed1 = amount1.toOwed();
        Owed owed2 = amount2.toOwed();

        vm.expectRevert(stdError.arithmeticError);
        owed1 - owed2;
    }
}
