// passing
// run: https://prover.certora.com/output/65266/7c027fe6b03f4ead8d1fc08b876c8e75?anonymousKey=475104b4504c765772a29b9124ee15355a4cf2c9
rule updateVault_no_unexpected_reverts {
    env e;

    // revert case run:
    // https://prover.certora.com/output/65266/8d688972399441b6baaca896f085402a?anonymousKey=0e79c1406bd82a2ad2672404bb8b62d184cd537b
    require e.msg.value == 0;
    uint256 lastInterestAccUpd = getlastInterestAccumulatorUpdate(e);

    // assignment to deltaT 
    require lastInterestAccUpd <= e.block.timestamp;

    // newTotalBorrows assigment, prevent divide by zero
    require getInterestAcc(e) > 0;

    // typecast of newAccumulatedFees
    require getAccumulatedFees(e) < getTotalShares(e);

    updateVaultExt@withrevert(e);
    assert !lastReverted;
}