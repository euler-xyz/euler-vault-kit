// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

// Test Helpers
import {Pretty, Strings} from "../utils/Pretty.sol";

// Test Contracts
import {BaseHooks} from "../base/BaseHooks.t.sol";

/// @title Borrowing Before After Hooks
/// @notice Helper contract for before and after hooks
/// @dev This contract is inherited by handlers
abstract contract BorrowingBeforeAfterHooks is BaseHooks {
    using Strings for string;
    using Pretty for uint256;
    using Pretty for int256;
    using Pretty for bool;

    struct BorrowingVars {
        // Debt Accounting
        uint256 totalBorrowsBefore;
        uint256 totalBorrowsAfter;
        uint256 totalBorrowsExactBefore;
        uint256 totalBorrowsExactAfter;
        uint256 cashBefore;
        uint256 cashAfter;
        // Interest
        uint256 interestRateBefore;
        uint256 interestRateAfter;
        uint256 interestAccumulatorBefore;
        uint256 interestAccumulatorAfter;
        // User Debt
        uint256 userDebtBefore;
        uint256 userDebtAfter;
        //TODO: borrow caps
    }

    BorrowingVars borrowingVars;

    function _borrowingHooksBefore() internal {
        // Debt Accounting
        borrowingVars.totalBorrowsBefore = eTST.totalBorrows();
        borrowingVars.totalBorrowsExactBefore = eTST.totalBorrowsExact();
        borrowingVars.cashBefore = eTST.cash();
        // Interest
        borrowingVars.interestRateBefore = eTST.interestRate();
        borrowingVars.interestAccumulatorBefore = eTST.interestAccumulator();
    }

    function _borrowingHooksAfter() internal {
        // Debt Accounting
        borrowingVars.totalBorrowsAfter = eTST.totalBorrows();
        borrowingVars.totalBorrowsExactAfter = eTST.totalBorrowsExact();
        borrowingVars.cashAfter = eTST.cash();
        // Interest
        borrowingVars.interestRateAfter = eTST.interestRate();
        borrowingVars.interestAccumulatorAfter = eTST.interestAccumulator();
    }

    /*/////////////////////////////////////////////////////////////////////////////////////////////
    //                                     POST CONDITIONS                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    VaultRegularBorrowable
        Post Condition A: Interest rate monotonically increases
        Post Condition B: A healthy account cant never be left unhealthy after a transaction

    */

    /////////////////////////////////////////////////////////////////////////////////////////////*/

    /*     function assert_rvbPostConditionA() internal {
        assertGe(
            rvbVars.interestAccumulatorAfter,
            rvbVars.interestAccumulatorBefore,
            "Interest rate must monotonically increase"
        );
    }

    function assert_rvbPostConditionB() internal {
        if (isAccountHealthy(rvbVars.liabilityValueBefore, rvbVars.collateralValueBefore)) {
            assertTrue(isAccountHealthy(rvbVars.liabilityValueAfter, rvbVars.collateralValueAfter), "Account cannot be left unhealthy");
        }
    } */
}
