// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Base Contracts
import {HandlerAggregator} from "../HandlerAggregator.t.sol";

/// @title BorrowingModuleInvariants
/// @notice Implements Invariants for the protocol borrowing module
/// @dev Inherits HandlerAggregator for checking actions in assertion testing mode
abstract contract BorrowingModuleInvariants is HandlerAggregator {

    function assert_BM_INVARIANT_A(
        address _borrower
    ) internal {
        assertGe(
            eTST.totalBorrows(),
            eTST.debtOf(_borrower),
            BM_INVARIANT_A
        );
    }

    function assert_BM_INVARIANT_B() internal {
        assertApproxEqAbs(
            eTST.totalBorrows(),
            _getDebtSum(),
            NUMBER_OF_ACTORS,
            BM_INVARIANT_B
        );
    }

    function assert_BM_INVARIANT_C() internal {
        if (_getDebtSum() == 0) {
            assertEq(
                eTST.totalBorrows(),
                0,
                BM_INVARIANT_C
            );
        }
    }

    //////////////////////////////////////////////////////////////////////////////////////////////
    //                                       DISCARDED                                          //
    //////////////////////////////////////////////////////////////////////////////////////////////


    /*     function assert_BM_INVARIANT_F() internal {
        if (eTST.totalBorrows() > 0) {
            assertGt(
                ERC20(address(eTST.asset())).balanceOf(_vault),
                0,
                BM_INVARIANT_F
            );
        }
    } */

    //////////////////////////////////////////////////////////////////////////////////////////////
    //                                        HELPERS                                           //
    //////////////////////////////////////////////////////////////////////////////////////////////

    function _getDebtSum() internal view returns (uint256 totalDebt) {
        for (uint256 i; i < NUMBER_OF_ACTORS; i++) {
            totalDebt += eTST.debtOf(address(actorAddresses[i]));
        }
    }
}
