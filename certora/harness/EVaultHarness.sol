// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Base} from "../../src/EVault/shared/Base.sol";

import {TokenModule} from "../../src/EVault/modules/Token.sol";
import {VaultModule} from "../../src/EVault/modules/Vault.sol";
import {BorrowingModule} from "../../src/EVault/modules/Borrowing.sol";
import {LiquidationModule} from "../../src/EVault/modules/Liquidation.sol";
import {InitializeModule} from "../../src/EVault/modules/Initialize.sol";
import {BalanceForwarderModule} from "../../src/EVault/modules/BalanceForwarder.sol";
import {GovernanceModule} from "../../src/EVault/modules/Governance.sol";
import {RiskManagerModule} from "../../src/EVault/modules/RiskManager.sol";

import "../../certora/harness/AbstractBaseHarness.sol";

contract EVaultHarness is
    Base,
    InitializeModule,
    TokenModule,
    VaultModule,
    BorrowingModule,
    LiquidationModule,
    RiskManagerModule,
    BalanceForwarderModule,
    GovernanceModule,
    AbstractBaseHarness
{

    constructor(
        Integrations memory integrations
    ) Base(integrations) {}

    // Unlike EVault.sol, does not override methods with the useView pattern
}