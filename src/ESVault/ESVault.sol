// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVault} from "../EVault/EVault.sol";
import {IGovernance} from "../EVault/IEVault.sol";
import {InitializeModule} from "../EVault/modules/Initialize.sol";
import {VaultModule} from "../EVault/modules/Vault.sol";
import {IERC20} from "../EVault/IEVault.sol";
import {ProxyUtils} from "../EVault/shared/lib/ProxyUtils.sol";
import {Operations} from "../EVault/shared/types/Types.sol";
import {console2} from "forge-std/Test.sol";
import "../EVault/shared/Constants.sol";

contract ESVault is EVault {
    constructor(Integrations memory integrations, DeployedModules memory modules) EVault(integrations, modules) {}

    uint32 public constant SYNTH_VAULT_DISABLED_OPS = OP_MINT | OP_REDEEM | OP_SKIM | OP_LOOP | OP_DELOOP;

    // ----------------- Initialize ----------------

    function initialize(address proxyCreator) public override virtual reentrantOK {
        InitializeModule.initialize(proxyCreator);

        // disable not supported operations
        marketStorage.disabledOps = Operations.wrap(SYNTH_VAULT_DISABLED_OPS | Operations.unwrap(marketStorage.disabledOps));
        emit GovSetDisabledOps(SYNTH_VAULT_DISABLED_OPS);
    }

    // ----------------- Governance ----------------

    /// @inheritdoc IGovernance
    function setDisabledOps(uint32 newDisabledOps) public override reentrantOK {
        // Enforce that ops that are not supported by the synth vault are not enabled.
        uint32 filteredOps = newDisabledOps | SYNTH_VAULT_DISABLED_OPS;
        console2.log("ESVault.setDisabledOps.filteredOps", filteredOps);
        super.setDisabledOps(filteredOps);
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
