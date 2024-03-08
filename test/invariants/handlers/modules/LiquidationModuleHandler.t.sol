// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Test Contracts
import {Actor} from "../../utils/Actor.sol";
import {BaseHandler} from "../../base/BaseHandler.t.sol";

// Interfaces
import {ILiquidation} from "src/EVault/IEVault.sol";

/// @title LiquidationModuleHandler
/// @notice Handler test contract for the VaultRegularBorrowable actions
contract LiquidationModuleHandler is BaseHandler {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      STATE VARIABLES                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       GHOST VARAIBLES                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           ACTIONS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function liquidate(uint256 repayAssets, uint256 i) external setup {//TODO: adapt liquidations to the current implementation
/*         bool success;
        bytes memory returnData;

        address target = address(eTST);

        address violator = _getActorWithDebt(target);

        require(violator != address(0), "VaultRegularBorrowableHandler: no violator");

        bool violatorStatus = isAccountHealthy(target, violator);

        repayAssets = clampBetween(repayAssets, 1, eTST.debtOf(violator));

        {
            address collateral = _getRandomAccountCollateral(i, address(actor));

            _before();
            (success, returnData) = actor.proxy(
                target,
                abi.encodeWithSelector(ILiquidation.liquidate.selector, violator, collateral, repayAssets)
            );
        }
        if (success) {
            _after();

            // VaultRegularBorrowable_invariantB
            assertFalse(violatorStatus);
        } */
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         OWNER ACTIONS                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

/*     function setCollateralFactor(uint256 collateralFactor) public {TODO: adapt this for the current implementation
        address target = address(eTST);

        _before();
        eTST.setCollateralFactor(target, collateralFactor);
        _after();

        assert(true);
    } */

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function _getActorWithDebt(address vaultAddress) internal view returns (address) {
        address _actor = address(actor);
        for (uint256 k; k < NUMBER_OF_ACTORS; k++) {
            if (_actor != actorAddresses[k] && eTST.debtOf(address(actorAddresses[k])) > 0) {
                return address(actorAddresses[k]);
            }
        }
        return address(0);
    }
}
