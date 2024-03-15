// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Base} from "../../src/EVault/shared/Base.sol";
// import {ModuleDispatch} from "../../src/EVault/modules/ModuleDispatch.sol";

import {TokenModule} from "../../src/EVault/modules/Token.sol";
import {VaultModule} from "../../src/EVault/modules/Vault.sol";
import {BorrowingModule} from "../../src/EVault/modules/Borrowing.sol";
import {LiquidationModule} from "../../src/EVault/modules/Liquidation.sol";
import {InitializeModule} from "../../src/EVault/modules/Initialize.sol";
import {BalanceForwarderModule} from "../../src/EVault/modules/BalanceForwarder.sol";
import {GovernanceModule} from "../../src/EVault/modules/Governance.sol";
import {RiskManagerModule} from "../../src/EVault/modules/RiskManager.sol";

contract EVaultHarness is
    // ModuleDispatch,
    InitializeModule,
    TokenModule,
    VaultModule,
    BorrowingModule,
    LiquidationModule,
    RiskManagerModule,
    BalanceForwarderModule,
    GovernanceModule
{
    // address immutable MODULE_INITIALIZE;
    // address immutable MODULE_TOKEN;
    // address immutable MODULE_VAULT;
    // address immutable MODULE_BORROWING;
    // address immutable MODULE_LIQUIDATION;
    // address immutable MODULE_RISKMANAGER;
    // address immutable MODULE_BALANCE_FORWARDER;
    // address immutable MODULE_GOVERNANCE;

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
    ) Base(integrations) {
        // MODULE_INITIALIZE = MODULE_INITIALIZE_;
        // MODULE_TOKEN = MODULE_TOKEN_;
        // MODULE_VAULT = MODULE_VAULT_;
        // MODULE_BORROWING = MODULE_BORROWING_;
        // MODULE_LIQUIDATION = MODULE_LIQUIDATION_;
        // MODULE_RISKMANAGER = MODULE_RISKMANAGER_;
        // MODULE_BALANCE_FORWARDER = MODULE_BALANCE_FORWARDER_;
        // MODULE_GOVERNANCE = MODULE_GOVERNANCE_;
    }

    // Unlike EVault.sol, does not override methods with the useView pattern
}