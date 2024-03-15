// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Test Contracts
import {Actor} from "../../utils/Actor.sol";
import {BaseHandler} from "../../base/BaseHandler.t.sol";

// Interfaces
import {IBorrowing, IERC4626} from "src/EVault/IEVault.sol";

/// @title BorrowingModuleHandler
/// @notice Handler test contract for the BorrowingModule actions
contract BorrowingModuleHandler is BaseHandler {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      STATE VARIABLES                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       GHOST VARAIBLES                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           ACTIONS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function borrowTo(uint256 assets, uint256 i) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address receiver = _getRandomActor(i);

        address target = address(eTST);

        bool isAccountHealthyBefore = isAccountHealthy(receiver);

        _before();
        (success, returnData) =
            actor.proxy(target, abi.encodeWithSelector(IBorrowing.borrow.selector, assets, receiver));

        if (!isAccountHealthyBefore) {
            /// @dev BM_INVARIANT_E
            assertFalse(success, BM_INVARIANT_E);
        } else {
            if (success) {
                _after();
            }
        }
    }

    function repayTo(uint256 assets, uint256 i) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address receiver = _getRandomActor(i);

        address target = address(eTST);

        (, uint256 liabilityValueBefore) = _getAccountLiquidity(receiver, false);

        _before();
        (success, returnData) =
            actor.proxy(target, abi.encodeWithSelector(IBorrowing.repay.selector, assets, receiver));

        if (success) {
            _after();

            (, uint256 liabilityValueAfter) = _getAccountLiquidity(receiver, false);


            /// @dev BM_INVARIANT_D
            assertLe(liabilityValueAfter, liabilityValueBefore, BM_INVARIANT_D);
        }
    }

    function loop(uint256 assets, uint256 i) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address receiver = _getRandomActor(i);

        address target = address(eTST);

        _before();
        (success, returnData) =
            actor.proxy(target, abi.encodeWithSelector(IBorrowing.loop.selector, assets, receiver));

        if (success) {
            assert(true);
        }
    }

    function deloop(uint256 assets, uint256 i) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address receiver = _getRandomActor(i);

        address target = address(eTST);

        _before();
        (success, returnData) =
            actor.proxy(target, abi.encodeWithSelector(IBorrowing.deloop.selector, assets, receiver));

        if (success) {
            assert(true);
        }
    }

    function pullDebt(uint256 i, uint256 assets) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address from = _getRandomActor(i);

        address target = address(eTST);

        _before();
        (success, returnData) =
            actor.proxy(target, abi.encodeWithSelector(IBorrowing.pullDebt.selector, from, assets));

        if (success) {
            _after();
        }
    }

    function touch() external {
        uint256 totalBorrowsBefore = eTST.totalBorrows();

        eTST.touch();

        uint256 totalBorrowsAfter = eTST.totalBorrows();

        /// @dev I_INVARIANT_C
        assertGe(totalBorrowsAfter, totalBorrowsBefore, I_INVARIANT_C);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                     ROUNDTRIP PROPERTIES                                  //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function aasert_BM_INVARIANT_G() external setup {
        bool success;
        bytes memory returnData;

        if (eTST.debtOf(address(actor)) == 0) {
            uint256 balanceBefore = eTST.balanceOf(address(actor));
            (success, returnData) = actor.proxy(address(eTST), abi.encodeWithSelector(IERC4626.withdraw.selector, balanceBefore, address(actor)));
            
            assertTrue(success, BM_INVARIANT_G);
        }
    }

    function assert_BM_INVARIANT_P() external setup {
        bool success;
        bytes memory returnData;

        uint256 totalOwed = eTST.debtOf(address(actor));

        if (totalOwed == 0) {
            return;
        }

        (success, returnData) = actor.proxy(address(eTST), abi.encodeWithSelector(IBorrowing.repay.selector, totalOwed, address(actor)));

        assertTrue(success, BM_INVARIANT_P);
        assertEq(eTST.debtOf(address(actor)), 0, BM_INVARIANT_P);
    }

    function assert_BM_INVARIANT_N(uint256 amount) external setup {
        bool success;
        bytes memory returnData;


        uint256 debtBefore = eTST.debtOf(address(actor)); 
        uint256 balanceBefore = eTST.balanceOf(address(actor));

        (success, returnData) = actor.proxy(address(eTST), abi.encodeWithSelector(IBorrowing.loop.selector, amount, address(actor)));

        if (success) {
            (success, returnData) = actor.proxy(address(eTST), abi.encodeWithSelector(IBorrowing.deloop.selector, amount, address(actor)));
        }

        if (success) {
            uint256 debtAfter = eTST.debtOf(address(actor));
            uint256 balanceAfter = eTST.balanceOf(address(actor));

            assertEq(debtBefore, debtAfter, BM_INVARIANT_N);
            assertEq(balanceBefore, balanceAfter, BM_INVARIANT_N);
        }
 }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         OWNER ACTIONS                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////
}
