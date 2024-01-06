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

    function EVCAuthenticate(bool checkController) internal view returns (address) {
        if (msg.sender == address(evc)) {
            (address onBehalfOfAccount, bool controllerEnabled) = evc.getCurrentOnBehalfOfAccount(address(this));

            if (checkController && !controllerEnabled) revert E_ControllerDisabled();

            return onBehalfOfAccount;
        }

        if (checkController && !evc.isControllerEnabled(msg.sender, address(this))) revert E_ControllerDisabled();
        return msg.sender;
    }

    function EVCRequireStatusChecks(address account) internal {
        if (account == ACCOUNT_CHECK_NONE) {
            evc.requireVaultStatusCheck();
        } else {
            evc.requireAccountAndVaultStatusCheck(account);
        }
    }
}
