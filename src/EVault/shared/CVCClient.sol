// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Storage} from "./Storage.sol";
import {Events} from "./Events.sol";
import {Errors} from "./Errors.sol";
import {ProxyUtils} from "./lib/ProxyUtils.sol";

import {IERC20} from "../IEVault.sol";
import {ICVC} from "euler-cvc/interfaces/ICreditVaultConnector.sol";
import {ICreditVault} from "euler-cvc/interfaces/ICreditVault.sol";

abstract contract CVCClient is Storage, Events, Errors {
    ICVC immutable cvc;

    bytes4 constant ACCOUNT_STATUS_CHECK_RETURN_VALUE = ICreditVault.checkAccountStatus.selector;
    bytes4 constant VAULT_STATUS_CHECK_RETURN_VALUE = ICreditVault.checkVaultStatus.selector;

    modifier onlyCVCChecks() {
        if ( msg.sender != address(cvc) || !cvc.areChecksInProgress())
            revert E_CheckUnauthorized();

        _;
    }

    modifier routedThroughCVC() {
        if (msg.sender == address(cvc)) {
            _;
        } else {
            bytes memory result = cvc.callback(msg.sender, 0, ProxyUtils.originalCalldata());

            assembly {
                return(add(32, result), mload(result))
            }
        }
    }

    constructor(address _cvc) {
        cvc = ICVC(_cvc);
    }

    function CVCAuthenticate(bool checkController) internal view returns (address) {
        if (msg.sender == address(cvc)) {
            (address onBehalfOfAccount, bool controllerEnabled) = cvc.getCurrentOnBehalfOfAccount(address(this));

            if (checkController && !controllerEnabled) revert E_ControllerDisabled();

            return onBehalfOfAccount;
        }

        if (checkController && !cvc.isControllerEnabled(msg.sender, address(this))) revert E_ControllerDisabled();
        return msg.sender;
    }

    function CVCRequireStatusChecks(address account) internal {
        if (account == address(0)) {
            cvc.requireVaultStatusCheck();
        } else {
            cvc.requireAccountAndVaultStatusCheck(account);
        }
    }
}
