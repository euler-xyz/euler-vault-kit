// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;
import "../../../src/interfaces/IPriceOracle.sol";
import "../../../certora/harness/AbstractBaseHarness.sol";
import "../../../src/EVault/modules/RiskManager.sol";
import "../../../src/EVault/modules/Initialize.sol";

// To prove the Health Status rule we need to include the RiskManager module
// which implemeants the status check
contract InitializeHSHarness is InitializeModule, RiskManagerModule, 
    AbstractBaseHarness {
    constructor(Integrations memory integrations) Base(integrations) {}
}