import "Base.spec";

methods {
    function _.balanceTrackerHook(address account, uint256 newAccountBalance, bool forfeitRecentReward) external => NONDET;
}

//passing:
// https://prover.certora.com/output/65266/ee7d7eb1364e4589a271b46267aa4742?anonymousKey=82512541ee02ddf9a6830a9555878361946ac19a
rule enableBalanceForwarder {
    address account;
    env e1;
    env e2;
    require actualCaller(e1) == account;
    enableBalanceForwarder(e1);
    assert balanceForwarderEnabled(e2, account);
}

// passing:
// https://prover.certora.com/output/65266/ee7d7eb1364e4589a271b46267aa4742?anonymousKey=82512541ee02ddf9a6830a9555878361946ac19a
rule disableBalanceForwarder {
    address account;
    env e1;
    env e2;
    require actualCaller(e1) == account;
    disableBalanceForwarder(e1);
    assert !balanceForwarderEnabled(e2, account);
}