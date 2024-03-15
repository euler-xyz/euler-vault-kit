// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVault} from "../EVault/EVault.sol";
import {IERC20} from "../EVault/IEVault.sol";
import {ProxyUtils} from "../EVault/shared/lib/ProxyUtils.sol";
import {DisabledOps} from "../EVault/shared/types/Types.sol";
import "../EVault/shared/Constants.sol";

contract ESVault is EVault {
    constructor(
        Integrations memory integrations,
        address MODULE_INITIALIZE_,
        address MODULE_TOKEN_,
        address MODULE_VAULT_,
        address MODULE_BORROWING_,
        address MODULE_LIQUIDATION_,
        address MODULE_RISKMANAGER_,
        address MODULE_BALANCE_FORWARDER_,
        address MODULE_GOVERNANCE_
    ) EVault(
        integrations,
        MODULE_INITIALIZE_,
        MODULE_TOKEN_,
        MODULE_VAULT_,
        MODULE_BORROWING_,
        MODULE_LIQUIDATION_,
        MODULE_RISKMANAGER_,
        MODULE_BALANCE_FORWARDER_,
        MODULE_GOVERNANCE_
    ) {
    }

    // ----------------- Initialize ----------------

    function initialize(address proxyCreator) public override virtual reentrantOK {
        super.initialize(proxyCreator);

        // disable not supported operations
        uint32 newDisabledOps = OP_MINT | OP_REDEEM | OP_SKIM | OP_LOOP | OP_DELOOP | DisabledOps.unwrap(marketStorage.disabledOps);
        
        marketStorage.disabledOps = DisabledOps.wrap(newDisabledOps);
        emit GovSetDisabledOps(newDisabledOps);
    }

    // ----------------- Vault ----------------

    function deposit(uint256 amount, address receiver) public override virtual reentrantOK returns (uint256) {
        // only the synth contract can call it
        address account = EVCAuthenticate();
        (IERC20 synth,,) = ProxyUtils.metadata();
        if (account != address(synth)) revert E_Unauthorized();

        super.deposit(amount, receiver);
    }

    function withdraw(uint256 assets, address receiver, address owner) public override virtual reentrantOK returns (uint256) {
        // only the synth contract, the governor fee receiver and the protocol fee receiver can call it.
        // the governor fee receiver and the protocol fee receiver can call it to withdraw the fees
        address account = EVCAuthenticate();
        (IERC20 synth,,) = ProxyUtils.metadata();
        (address protocolReceiver,) = protocolConfig.feeConfig(address(this));
        if (account != address(synth) && account != protocolReceiver && account != marketStorage.feeReceiver) {
            revert E_Unauthorized();
        }

        super.withdraw(assets, receiver, owner);
    }
}