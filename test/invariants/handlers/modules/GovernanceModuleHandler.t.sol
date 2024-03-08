// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Test Contracts
import {Actor} from "../../utils/Actor.sol";
import {BaseHandler} from "../../base/BaseHandler.t.sol";

// Interfaces
import {IGovernance} from "src/EVault/IEVault.sol";

/// @title GovernanceModuleHandler
/// @notice Handler test contract for the governance module actions
contract GovernanceModuleHandler is BaseHandler {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      STATE VARIABLES                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           ACTIONS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function convertFees() external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address target = address(eTST);

        (success, returnData) =
            actor.proxy(target, abi.encodeWithSelector(IGovernance.convertFees.selector));

        if (success) {
            assert(true);
        }
    }

    function setLTV(uint256 i, uint16 ltv, uint24 rampDuration) external {
        address collateral;
        //TODO make a function to select a random collateral form the ones on the deployment

        eTST.setLTV(collateral, ltv, rampDuration);

        assert(true);
    }

    function clearLTV(uint256 i) external {
        address collateral;
        //TODO make a function to select a random collateral form the ones on the deployment

        eTST.clearLTV(collateral);

        assert(true);
    }

    //TODO
    // - setIRM
    // - setDisabledOps
    // - setCaps
    // - setInterestFee
    // - setDebtSocialization

}
