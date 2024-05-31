
// This provides a configuration for the VaultERC4626 rules
// that will use the `CVLLoadVault` summary which includes a model
// for the update for fees.

import "./LoadVaultSummary.spec";
import "./VaultERC4626.spec";

methods {
    function Cache.loadVault() internal returns (BaseHarness.VaultCache memory) with (env e) => CVLLoadVault(e);
}