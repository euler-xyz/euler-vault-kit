// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Storage} from "./Storage.sol";
import {Events} from "./Events.sol";
import {Errors} from "./Errors.sol";
import {ProxyUtils} from "./lib/ProxyUtils.sol";
import "./Constants.sol";

import {IERC20} from "../IEVault.sol";
import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";

abstract contract EVCClient is Storage, Events, Errors {
    IEVC immutable evc;

    modifier onlyEVCChecks() {
        if (msg.sender != address(evc) || !evc.areChecksInProgress()) {
            revert E_CheckUnauthorized();
        }

        _;
    }

    constructor(address _evc) {
        evc = IEVC(_evc);
    }

    function disableControllerInternal(address account) internal virtual {
        evc.disableController(account);

        emit DisableController(account);
    }

    // Authenticate account and controller, making sure the call is made through EVC and the status checks are deferred
    function EVCAuthenticateDeferred(bool checkController) internal view returns (address) {
        if (msg.sender != address(evc)) revert E_Unauthorized();

        (address onBehalfOfAccount, bool controllerEnabled) =
            evc.getCurrentOnBehalfOfAccount(checkController ? address(this) : address(0));

        if (checkController && !controllerEnabled) revert E_ControllerDisabled();

        return onBehalfOfAccount;
    }

    function EVCAuthenticate() internal view returns (address) {
        if (msg.sender == address(evc)) {
            (address onBehalfOfAccount,) = evc.getCurrentOnBehalfOfAccount(address(0));

            return onBehalfOfAccount;
        }
        return msg.sender;
    }

    function getAccountOwner(address account) internal view returns (address owner) {
        if (msg.sender == address(evc)) {
            owner = evc.getAccountOwner(account);
        } else {
            owner = account;
        }
    }

    function EVCRequireStatusChecks(address account) internal {
        if (account == ACCOUNTCHECK_NONE) {
            evc.requireVaultStatusCheck();
        } else {
            evc.requireAccountAndVaultStatusCheck(account);
        }
    }

    function enforceCollateralTransfer(address collateral, uint256 amount, address from, address receiver)
        internal
    {
        evc.controlCollateral(collateral, from, 0, abi.encodeCall(IERC20.transfer, (receiver, amount)));
    }

    function forgiveAccountStatusCheck(address account) internal {
        evc.forgiveAccountStatusCheck(account);
    }

    function getController(address account) internal view returns (address) {
        address[] memory controllers = evc.getControllers(account);

        if (controllers.length > 1) revert E_TransientState();

        return controllers.length == 1 ? controllers[0] : address(0);
    }

    function getCollaterals(address account) internal view returns (address[] memory) {
        return evc.getCollaterals(account);
    }

    function isCollateralEnabled(address account, address market) internal view returns (bool) {
        return evc.isCollateralEnabled(account, market);
    }

    function isControllerEnabled(address account) internal view returns (bool) {
        return evc.isControllerEnabled(account, address(this));
    }

    function isAccountStatusCheckDeferred(address account) internal view returns (bool) {
        return evc.isAccountStatusCheckDeferred(account);
    }

    function isVaultStatusCheckDeferred() internal view returns (bool) {
        return evc.isVaultStatusCheckDeferred(address(this));
    }

    function isControlCollateralInProgress() internal view returns (bool) {
        return evc.isControlCollateralInProgress();
    }

    function verifyController(address account) internal view {
        address[] memory controllers = IEVC(evc).getControllers(account);

        if (controllers.length > 1) revert E_TransientState();
        if (controllers.length == 0) revert E_NoLiability();
        if (controllers[0] != address(this)) revert E_NotController();
    }
}
