import "./Base.spec";
methods {
    function Cache.loadVault() internal returns (BaseHarness.VaultCache memory) => CVLloadVault();
    function storage_lastInterestAccumulatorUpdate() external returns (uint48) envfree;
    function storage_cash() external returns (BaseHarness.Assets) envfree;
    function storage_supplyCap() external returns (BaseHarness.AmountCap) envfree;
    function storage_borrowCap() external returns (BaseHarness.AmountCap) envfree;
    function storage_hookedOps() external returns (BaseHarness.Flags) envfree;
    function storage_snapshotInitialized() external returns (bool) envfree;
    function storage_totalShares() external returns (BaseHarness.Shares) envfree;
    function storage_totalBorrows() external returns (BaseHarness.Owed) envfree;
    function storage_accumulatedFees() external returns (BaseHarness.Shares) envfree;
    function storage_interestAccumulator() external returns (uint256) envfree;
    function storage_configFlags() external returns (BaseHarness.Flags) envfree;
}

function CVLloadVault() returns BaseHarness.VaultCache {
    // for debugging performance
    BaseHarness.VaultCache vaultCache;

    // These are used more than once
    // not sure if our tool already de-duplicates these;
    BaseHarness.Owed oldTotalBorrows = storage_totalBorrows(); 
    BaseHarness.Shares oldTotalShares = storage_totalShares();

    require vaultCache.asset == erc20;
    require vaultCache.oracle == oracleAddress;
    require vaultCache.unitOfAccount == unitOfAccount;

    // try also directly setting to block.timestamp;
    require vaultCache.lastInterestAccumulatorUpdate >= 
        storage_lastInterestAccumulatorUpdate();
    require vaultCache.cash == storage_cash();
    // check if this is true. Assigned from newTotalBorrows
    require vaultCache.totalBorrows >= oldTotalBorrows;
    require vaultCache.totalBorrows <= max_uint112; // MAX_SANE_AMOUNT

    /////// summarize totalShares
    // simple summary
    // require vaultCache.totalShares  <= storage_totalShares();

    // more accurate summary 
    mathint newTotalAssets = vaultCache.cash + vaultCache.totalBorrows;
    uint16 feeScalar; //need to make higher than uint16 ?
    uint256 feeAssets = require_uint256(feeScalar * (vaultCache.totalBorrows - oldTotalBorrows));
    if (require_uint256(newTotalAssets) > feeAssets) { // This is not directly checked in the code
        require vaultCache.totalShares == require_uint112(oldTotalShares * newTotalAssets /
            (newTotalAssets - feeAssets));
    } else {
        require vaultCache.totalShares == oldTotalShares;
    }

    require vaultCache.accumulatedFees == require_uint112(storage_accumulatedFees() + vaultCache.totalShares - oldTotalShares);

    require vaultCache.interestAccumulator >= storage_interestAccumulator();

    require vaultCache.supplyCap == assert_uint256(storage_supplyCap());
    require vaultCache.borrowCap == assert_uint256(storage_borrowCap());
    require vaultCache.hookedOps == storage_hookedOps();
    require vaultCache.configFlags == storage_configFlags();

    // Runtime

    bool snapshotInitialized;

    return vaultCache;
}