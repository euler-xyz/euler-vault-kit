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


    // https://prover.certora.com/output/65266/e834a7e7775443ffbe26577bfbc97f87?anonymousKey=98085ba3f887e9b0fd2b22683e73af45bc1a106b

    // assignment to newTotalBorrows, overflows
    // Note: MAX_SANE_AMOUNT does not work as a bound for these:
    // https://prover.certora.com/output/65266/e1aab12acdb5435d80e70e661299c504?anonymousKey=c6c63c10fa9ddb5c16b86cd2073643768d3d96e4
    require getTotalBorrows(e) < 1267650600228229401496703205375; //2**100-1

    require getInterestAcc(e) < 1267650600228229401496703205375;
    // newTotalBorrows assigment, prevent divide by zero
    require getInterestAcc(e) > 0;

    updateVaultExt@withrevert(e);
    assert !lastReverted;
}