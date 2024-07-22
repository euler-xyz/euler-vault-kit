import "Base.spec";

// run: https://prover.certora.com/output/65266/4d1ba56cfd3c4aefbe2661e07fd5c95c/?anonymousKey=800abae52d40b2758c3f1f8c8a42ff82025533cd

methods {
    // envfree
    function vaultIsOnlyController(address account) external returns (bool) envfree;
        
}

// passing: https://prover.certora.com/output/65266/8b94c232c4b14e3aab917cd7e94d501c/?anonymousKey=27f680520b4d7cbb9f387563d3f1bb45de8fc9a7
rule ltv_borrowing_lower {
    env e;
    calldataarg args;

    address account;


    // based on loop bound        
    address[] collaterals = getCollateralsExt(account);
    require collaterals.length == 2;
    require LTVConfigAssumptions(e, getLTVConfig(collaterals[0]));
    require LTVConfigAssumptions(e, getLTVConfig(collaterals[1]));

    uint256 collateralValue_liquidation;
    uint256 liabilityValue_liquidation;
    (collateralValue_liquidation, liabilityValue_liquidation) = accountLiquidity(e, account, true);

    uint256 collateralValue_borrowing;
    uint256 liabilityValue_borrowing;
    (collateralValue_borrowing, liabilityValue_borrowing) = accountLiquidity(e, account, false);

    require collateralValue_liquidation > 0;
    require collateralValue_borrowing > 0;

    assert collateralValue_liquidation >= collateralValue_borrowing;
    
}

// Passing

rule accountLiquidityMustRevert {
    env e;
    calldataarg args;
    address account;
    bool liquidation;

    require oracleAddress != 0;

    bool vaultControlsAccount = vaultIsOnlyController(account);
    bool oracleConfigured = vaultCacheOracleConfigured(e);

    accountLiquidity(e, account, liquidation);
    // If we did not revert then: ...
    assert vaultControlsAccount;
    assert oracleConfigured;

}

// passing
rule accountLiquidityFullMustRevert {
    env e;
    calldataarg args;
    address account;
    bool liquidation;

    require oracleAddress != 0;

    bool vaultControlsAccount = vaultIsOnlyController(account);
    bool oracleConfigured = vaultCacheOracleConfigured(e);

    accountLiquidityFull(e, account, liquidation);
    // If we did not revert then: ...
    assert vaultControlsAccount;
    assert oracleConfigured;
}

// passing
rule checkAccountStatusMustRevert {
    env e;
    calldataarg args;
    address account;
    address[] collaterals;
    bool checksInProgress = evc.areChecksInProgress(e);
    checkAccountStatus(e, account, collaterals);
    assert e.msg.sender == evc;
    assert checksInProgress;
}

// passing
rule checkVaultStatusMustRevert {
    env e;
    calldataarg args;
    bool checksInProgress = evc.areChecksInProgress(e);
    checkVaultStatus(e);
    assert e.msg.sender == evc;
    assert checksInProgress;
}
