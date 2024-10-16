// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;
import "../../../src/interfaces/IPriceOracle.sol";
import "../../../certora/harness/AbstractBaseHarness.sol";
import "../../../src/EVault/modules/RiskManager.sol";
import "../../../src/EVault/modules/Liquidation.sol";

// To prove the Health Status rule we need to include the RiskManager module
// which implemeants the status check
contract LiquidationHSHarness is LiquidationModule, RiskManagerModule, 
    AbstractBaseHarness {
    constructor(Integrations memory integrations) Base(integrations) {}

    function hasDebtSocialization() external returns (bool) {
        VaultCache memory vaultCache = loadVault();
        return vaultCache.configFlags.isNotSet(CFG_DONT_SOCIALIZE_DEBT);
    }
}