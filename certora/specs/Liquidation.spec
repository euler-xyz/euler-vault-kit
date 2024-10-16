// Passing
// run: https://prover.certora.com/output/65266/5f1f37520d824e1aa7ab738a0147745e?anonymousKey=9521c3759d1f018559d571cd2a1502b04504399d

import "Base.spec";
methods {
    function isRecognizedCollateralExt(address collateral) external returns (bool) envfree;
    // unresolved calls that havoc all contracts
    function _.isHookTarget() external => NONDET;
    function _.invokeHookTarget(address caller) internal => NONDET;
    function _.tryBalanceTrackerHook(address account, uint256 newAccountBalance, bool forfeitRecentReward) internal => NONDET;
    function _.balanceTrackerHook(address account, uint256 newAccountBalance, bool forfeitRecentReward) external => NONDET;
    function _.emitTransfer(address from, address to, uint256 value) external => NONDET;
    function EVCHarness.disableController(address account) external => NONDET;
    function _.computeInterestRate(address vault, uint256 cash, uint256 borrows) external => NONDET;
    function _.onFlashLoan(bytes data) external => NONDET;
    function _.safeTransferFrom(address token, address from, address to, uint256 value, address permit2) internal => NONDET;
    function _.enforceCollateralTransfer(address collateral, uint256 amount,
        address from, address receiver) internal =>  NONDET;


    function EthereumVaultConnector.checkAccountStatusInternal(address account) internal returns (bool, bytes memory) with (env e) => 
        CVLCheckAccountStatusInternal(e, account);
    function EthereumVaultConnector.checkVaultStatusInternal(address vault) internal returns (bool, bytes memory) with(env e) =>
        CVLCheckVaultStatusInternal(e);

    function _.EVCRequireStatusChecks(address account) internal => NONDET;
}


// This returns an arbitrary account status of the prover's choosing. It is 
// similar to NONDETing checkAccountStatus internal and is a worakround
// for the tool not supporting NONDET for byte return values.
persistent ghost bool accountStatusGhost;
function CVLCheckAccountStatusInternalBool(env e, address account) returns bool {
    return accountStatusGhost;
}

function CVLCheckAccountStatusInternal(env e, address account) returns (bool, bytes) {
    return (CVLCheckAccountStatusInternalBool(e, account), 
        checkAccountMagicValueMemory(e));
}

// This is using a similar pattern as CVLCheckAcountStatusInternal
persistent ghost bool vaultStatusBool;
function CVLCheckVaultStatusInternalBool(env e) returns bool {
    return vaultStatusBool;
}

function CVLCheckVaultStatusInternal(env e) returns (bool, bytes) {
    return (CVLCheckVaultStatusInternalBool(e),
        checkVaultMagicValueMemory(e));
}

// passing
// If violator healthy, checkLiquidation returns maxRepay and maxYield as 0.
rule checkLiquidation_healthy() {
    env e;
    address liquidator;
    address violator; 
    address collateral;
    uint256 maxRepay;
    uint256 maxYield;

    require oracleAddress != 0;

    uint256 liquidityCollateralValue;
    uint256 liquidityLiabilityValue;
    (liquidityCollateralValue, liquidityLiabilityValue) = 
        calculateLiquidityExternal(e, violator);

    require liquidityCollateralValue > liquidityLiabilityValue;

    (maxRepay, maxYield) = checkLiquidation(e, liquidator, violator, collateral);

    assert maxRepay == 0;
    assert maxYield == 0;
}

// passing run: https://prover.certora.com/output/65266/ed9699a14a114c0dbad76526a55ad493/?anonymousKey=f1f0a74c2c72ede7ce77f50fbf66541e8c4f03d7
rule checkLiquidation_healthy_reverts() {
    env e;
    address account;
    require oracleAddress != 0;

    uint256 liquidityCollateralValue;
    uint256 liquidityLiabilityValue;
    address[] collaterals = getCollateralsExt(account);
    require collaterals.length == 2; // loop unrolling bound
    (liquidityCollateralValue, liquidityLiabilityValue) = 
        calculateLiquidityLiquidation(e, account);

    // returns true if there is no liability
    require liquidityLiabilityValue > 0;

    // calculateLiquidity and checkLiquidity are only
    // the same if the unitOfAccount is the same
    // as the underlying asset -- otherwise the
    // value of the unitOfAccount could change the value
    // of the liability value returned by getLiabilityValue
    require unitOfAccount == erc20;

    // checkLiquidityReturning must return FALSE if collateral is not
    // greater than liability.
    assert checkLiquidityReturning(e, account, collaterals) <=>
        (liquidityCollateralValue > liquidityLiabilityValue);
}

// passing
// checkLiquidation must revert if:
//  - violator is the same account as liquidator
//  - collateral is not accepted
//  - collateral is not enabled collateral for the violator
//  - liability vault is not enabled as the only controller of the violator
//  - violator account status check is deferred
//  - price oracle is not configured
rule checkLiquidation_mustRevert {
    env e;
    address liquidator;
    address violator;
    address collateral;
    uint256 maxRepay;
    uint256 maxYield;
    
    require oracleAddress != 0;
    bool selfLiquidate = liquidator == violator;
    bool badCollateral = !isRecognizedCollateralExt(collateral);
    bool enabledCollateral = isCollateralEnabledExt(violator, collateral);
    bool vaultControlsViolator = vaultIsOnlyController(violator);
    bool violatorStatusCheckDeferred = isAccountStatusCheckDeferredExt(violator);
    bool oracleConfigured = vaultCacheOracleConfigured(e);

    (maxRepay, maxYield) = checkLiquidation(e, liquidator, violator, collateral);

    assert !selfLiquidate;
    assert !badCollateral;
    assert enabledCollateral;
    assert vaultControlsViolator;
    assert !violatorStatusCheckDeferred;
    assert oracleConfigured;

}

// Passing.
// The borrowing collateral value is lower than the liquidation collateral value
rule getCollateralValue_borrowing_lower {
    env e;
    Liquidation.VaultCache vaultCache;
    address account;
    address collateral;

    require LTVConfigAssumptions(e, getLTVConfig(e, collateral));

    uint256 collateralValue_borrowing = getCollateralValueExt(e, vaultCache, account, collateral, false);

    uint256 collateralValue_liquidation = getCollateralValueExt(e, vaultCache, account, collateral, true);

    require collateralValue_liquidation > 0;
    require collateralValue_borrowing > 0;

    assert collateralValue_borrowing <= collateralValue_liquidation;

}

// passed
// Liquidation must revert if:
// - the liquidator is the violator (self liquidation)
// - the collateral is not recognized
// - the collateral is not enabled
// - the vault does not control the liquidator 
// - the vault does not control the violator
// - the status checks are not deferred for the violator
// - the price oracle is not configured
rule liquidate_mustRevert {
    env e;
    address violator;
    address collateral; 
    uint256 repayAssets; 
    uint256 minYieldBalance;

    address liquidator = getLiquidator(e);
    bool selfLiquidation = violator == liquidator;
    bool recognizedCollateral = isRecognizedCollateralExt(collateral);
    bool enabledCollateral = isCollateralEnabledExt(violator, collateral);
    bool violatorStatusCheckDeferred = isAccountStatusCheckDeferredExt(violator);
    bool vaultControlsLiquidator = vaultIsController(liquidator);
    bool vaultControlsViolator = vaultIsOnlyController(violator);
    bool oracleConfigured = vaultCacheOracleConfigured(e);

    liquidate(e, violator, collateral, repayAssets, minYieldBalance);
    assert !selfLiquidation;
    assert recognizedCollateral;
    assert enabledCollateral;
    assert vaultControlsLiquidator;
    assert vaultControlsViolator;
    assert !violatorStatusCheckDeferred;
    assert oracleConfigured;
}

