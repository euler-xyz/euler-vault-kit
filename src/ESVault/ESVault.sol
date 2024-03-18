// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVault} from "../EVault/EVault.sol";
import {InitializeModule} from "../EVault/modules/Initialize.sol";
import {VaultModule} from "../EVault/modules/Vault.sol";
import {IERC20} from "../EVault/IEVault.sol";
import {ProxyUtils} from "../EVault/shared/lib/ProxyUtils.sol";
import {Operations} from "../EVault/shared/types/Types.sol";
import {console2} from "forge-std/Test.sol";
import "../EVault/shared/Constants.sol";

contract ESVault is EVault {
    constructor(Integrations memory integrations, DeployedModules memory modules) EVault(integrations, modules) {}

    // ----------------- Initialize ----------------

    function initialize(address proxyCreator) public override virtual reentrantOK {
        InitializeModule.initialize(proxyCreator);

        // disable not supported operations
        uint32 newDisabledOps = OP_MINT | OP_REDEEM | OP_SKIM | OP_LOOP | OP_DELOOP;
        
        marketStorage.disabledOps = Operations.wrap(newDisabledOps | Operations.unwrap(marketStorage.disabledOps));
        emit GovSetDisabledOps(newDisabledOps);
    }

    // ----------------- Vault ----------------

    function deposit(uint256 amount, address receiver) public override virtual reentrantOK returns (uint256) {
        // only the synth contract can call this function.
        address account = EVCAuthenticate();
        (IERC20 synth,,) = ProxyUtils.metadata();

        if (account != address(synth)) revert E_Unauthorized();

        super.deposit(amount, receiver);
    }

}
