import "./Base.spec";
methods {
    function Cache.loadVault() internal returns (BaseHarness.VaultCache memory) with (env e) => CVLLoadVaultAssumeNoUpdate(e);

    function storage_lastInterestAccumulatorUpdate() external returns (uint48) envfree;
    function storage_cash() external returns (BaseHarness.Assets) envfree;
    function storage_supplyCap() external returns (uint256) envfree;
    function storage_borrowCap() external returns (uint256) envfree;
    function storage_hookedOps() external returns (BaseHarness.Flags) envfree;
    function storage_snapshotInitialized() external returns (bool) envfree;
    function storage_totalShares() external returns (BaseHarness.Shares) envfree;
    function storage_totalBorrows() external returns (BaseHarness.Owed) envfree;
    function storage_accumulatedFees() external returns (BaseHarness.Shares) envfree;
    function storage_interestAccumulator() external returns (uint256) envfree;
    function storage_configFlags() external returns (BaseHarness.Flags) envfree;
}



// need to make sure successive calls only return different values
// when this is actually possible in the real call...
//    * calls with the same env will return all the same values
// the passage of time is not actually relevant to the spec because
// in all the rules, only one env is ever created per rule.
// The parts of the cache about interest are not relevant to the specs

function CVLLoadVaultAssumeNoUpdate(env e) returns BaseHarness.VaultCache {
    BaseHarness.VaultCache vaultCache;
    uint48 lastUpdate = storage_lastInterestAccumulatorUpdate();
    BaseHarness.Owed oldTotalBorrows = storage_totalBorrows(); 
    BaseHarness.Shares oldTotalShares = storage_totalShares();
    require vaultCache.cash == storage_cash();
    uint48 timestamp48 = require_uint48(e.block.timestamp);
    bool updated = timestamp48 != lastUpdate;
    require !updated;
    require vaultCache.lastInterestAccumulatorUpdate == lastUpdate;
    require vaultCache.totalBorrows == oldTotalBorrows;
    require vaultCache.totalShares == oldTotalShares;
    require vaultCache.accumulatedFees == storage_accumulatedFees();
    require vaultCache.interestAccumulator == storage_interestAccumulator();

    // unmodified values
    require vaultCache.supplyCap == storage_supplyCap();
    require vaultCache.borrowCap == storage_borrowCap();
    require vaultCache.hookedOps == storage_hookedOps();
    require vaultCache.configFlags == storage_configFlags();
    require vaultCache.snapshotInitialized == storage_snapshotInitialized();

    require vaultCache.asset == erc20;
    require vaultCache.oracle == oracleAddress;
    require vaultCache.unitOfAccount == unitOfAccount;
    require oracleAddress != 0;
    require unitOfAccount != 0;

    return vaultCache;
}