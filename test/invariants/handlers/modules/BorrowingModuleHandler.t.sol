// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Test Contracts
import {Actor} from "../../utils/Actor.sol";
import {BaseHandler} from "../../base/BaseHandler.t.sol";

// Interfaces
import {IBorrowing} from "src/EVault/IEVault.sol";

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

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         OWNER ACTIONS                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////
}
