
methods {
    // It's not envfree. block time
    // function updateVaultExt() external returns (Cache.VaultCache) envfree;
}

// passing
// run: https://prover.certora.com/output/65266/974f262c8ca84582909b12e83849003b/?anonymousKey=b8fc04fbb6a3a2aa0cca1151da309eaea9f64252
rule updateVault_no_unexpected_reverts {
    env e;

    // revert case run:
    // https://prover.certora.com/output/65266/8d688972399441b6baaca896f085402a?anonymousKey=0e79c1406bd82a2ad2672404bb8b62d184cd537b
    require e.msg.value == 0;
    uint256 lastInterestAccUpd = getlastInterestAccumulatorUpdate(e);

    // assignment to deltaT 
    require assert_uint256(lastInterestAccUpd) < e.block.timestamp;
    // https://prover.certora.com/output/65266/e834a7e7775443ffbe26577bfbc97f87?anonymousKey=98085ba3f887e9b0fd2b22683e73af45bc1a106b

    // assignment to newTotalBorrows, overflows
    // Note: MAX_SANE_AMOUNT does not work as a bound for these:
    // https://prover.certora.com/output/65266/e1aab12acdb5435d80e70e661299c504?anonymousKey=c6c63c10fa9ddb5c16b86cd2073643768d3d96e4
    require getTotalBorrows(e) < 1152921504606846975; //2**60-1
    require getInterestAcc(e) < 1152921504606846975;
    // newTotalBorrows assigment, prevent divide by zero
    require getInterestAcc(e) > 0;

    // typecast of newAccumulatedFees
    // Also MAX_SANE_AMOUNT is not a sufficient bound for this 
    // (because the bounded var is from storage not the new accumulated fees)
    // https://prover.certora.com/output/65266/8c53d45891374c4692ea7597de239ba1?anonymousKey=551bfa1d1460c56f30002f5de8aeab4bd49a0fcb
    require getAccumulatedFees(e) < 1152921504606846975;

    updateVaultExt@withrevert(e);
    assert !lastReverted;
}