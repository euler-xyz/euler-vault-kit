// passing
// run: https://prover.certora.com/output/65266/11417156b83b43c0b03fc0e7cd7f84e9?anonymousKey=68ebc9dadced7038e1193557a50c2c9183abbd72
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