
methods {
    // It's not envfree. block time
    // function updateVaultExt() external returns (Cache.VaultCache) envfree;
}

// passing
// run: https://prover.certora.com/output/65266/e5dc6fb3648f45fdbe48597c69561bd1/?anonymousKey=12ed8515517a0998ef7af0ed86ecc7008537cec1
rule updateVault_no_unexpected_reverts {
    env e;

    // revert case run:
    // https://prover.certora.com/output/65266/8d688972399441b6baaca896f085402a?anonymousKey=0e79c1406bd82a2ad2672404bb8b62d184cd537b
    require e.msg.value == 0;
    uint256 lastInterestAccUpd = getlastInterestAccumulatorUpdate(e);

    // assignment to deltaT 
    require assert_uint256(lastInterestAccUpd) < e.block.timestamp;


    require getInterestAcc(e) > 0;
    
    require getAccumulatedFees(e) < getTotalShares(e);

    updateVaultExt@withrevert(e);
    assert !lastReverted;
}