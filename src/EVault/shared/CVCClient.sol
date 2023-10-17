// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Storage} from "./Storage.sol";
import {Events} from "./Events.sol";
import {Errors} from "./Errors.sol";

import {IERC20} from "../IEVault.sol";
import {ICVC} from "euler-cvc/interfaces/ICreditVaultConnector.sol";

abstract contract CVCClient is Storage, Events, Errors {
    ICVC immutable cvc;
    uint8 constant BATCH_DEPTH_INIT = 1;

    constructor(address _cvc) {
        cvc = ICVC(_cvc);
    }

    // function releaseController(address account) internal virtual {
    //     cvc.disableController(account);

    //     emit ReleaseController(account);
    // }

    function CVCAuthenticate() internal view returns (address) {
        if (msg.sender == address(cvc)) {
            (address onBehalfOfAccount,) = cvc.getExecutionContext(address(0));
            return onBehalfOfAccount;
        }

        return msg.sender;
    }

    // function CVCAuthenticateForBorrow() internal view returns (address) {
    //     if (msg.sender == address(cvc)) {
    //         (address onBehalfOfAccount, bool controllerEnabled) = cvc.getExecutionContext(address(this));

    //         if (!controllerEnabled) revert E_ControllerDisabled();

    //         return onBehalfOfAccount;
    //     }

    //     if (!cvc.isControllerEnabled(msg.sender, address(this))) revert E_ControllerDisabled();
    //     return msg.sender;
    // }

    // function getAccountOwner(address account) internal view returns (address owner) {
    //     if (msg.sender == address(cvc)) {
    //         owner = cvc.getAccountOwner(account);
    //     } else {
    //         owner = account;
    //     }
    // }

    // function checkMarketStatus() internal {
    //     cvc.requireVaultStatusCheck();
    // }

    function checkAccountAndMarketStatus(address account) internal {
        if (account == address(0)) {
            cvc.requireVaultStatusCheck();
        } else {
            cvc.requireAccountAndVaultStatusCheck(account);
        }
    }

    // function enforceExternalCollateralTransfer(address collateral, uint amount, address from, address receiver) internal returns (bytes memory data) {
    //     bool success;
    //     (success, data) = cvc.impersonate(collateral, from, abi.encodeCall(IERC20.transfer, (receiver, amount)));
    //     if(!success) revertBytes(data);
    // }

    // function forgiveAccountStatusCheck(address account) internal {
    //     cvc.forgiveAccountStatusCheck(account);
    // }

    // function getController(address account) internal view returns (address) {
    //     address[] memory controllers = cvc.getControllers(account);

    //     if (controllers.length > 1) revert E_TransientState();

    //     return controllers.length == 1 ? controllers[0] : address(0);
    // }

    // function getCollaterals(address account) internal view returns (address[] memory) {
    //     return cvc.getCollaterals(account);
    // }

    // function isCollateralEnabled(address account, address market) internal view returns (bool) {
    //     return cvc.isCollateralEnabled(account, market);
    // }

    // function isControllerEnabled(address account) internal view returns (bool) {
    //     return cvc.isControllerEnabled(account, address(this));
    // }

    // function isAccountStatusCheckDeferred(address account) internal view returns (bool) {
    //     return cvc.isAccountStatusCheckDeferred(account);
    // }

    function revertBytes(bytes memory) internal pure virtual;
}
