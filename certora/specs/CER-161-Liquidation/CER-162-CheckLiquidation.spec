/*
CER-162 / Verify EVK-31
If violator unhealthy, checkLiquidation returns the maximum amount of the debt 
asset the liquidator is allowed to liquidate (maxRepay) in exchange for the 
returned maximum amount of collateral shares from violator (maxYield).

If violator healthy, checkLiquidation returns maxRepay and maxYield as 0.

Unless violator healthy, considering the liquidator bonus is positive and grows 
linearly as the health of the violator deteriorates, the value of maxYield is 
greater than the value of maxRepay.

If needed, checkLiquidation must limit the maxRepay as per available amount of 
collateral to be seized from the violator.

If needed, checkLiquidation must limit the maxRepay and the maxYield as per 
desired amount to be repaid (desiredRepay) parameter.

checkLiquidation must revert if:
 - violator is the same account as liquidator
 - collateral is not accepted
 - collateral is not enabled collateral for the violator
 - liability vault is not enabled as the only controller of the violator
 - violator account status check is deferred
 - price oracle is not configured
 - price oracle is not configured
*/

import "../Base.spec";
methods {
    // envfree
    function isRecognizedCollateralExt(address collateral) external returns (bool) envfree;
    function isCollateralEnabledExt(address account, address market) external returns (bool) envfree;
    function vaultIsOnlyController(address account) external returns (bool) envfree;
    function isAccountStatusCheckDeferredExt(address account) external returns (bool) envfree;
    
}

// passing
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

// counterexample
rule checkLiquidation_maxYieldGreater {
    env e;
    address liquidator;
    address violator; 
    address collateral;
    uint256 maxRepay;
    uint256 maxYield;

    uint256 collateralValue;
    uint256 liabilityValue;
    (collateralValue, liabilityValue) =     
        calculateLiquidityExternal(e, violator);

    require oracleAddress != 0;
    require collateralValue > 0;
    require liabilityValue > 0;
    require collateralValue < liabilityValue;

    (maxRepay, maxYield) = checkLiquidation(e, liquidator, violator, collateral);
    assert maxRepay > 0 => maxRepay <= maxYield; 
}

// passing
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

// Passing. Assumptions can be reduced with Euler's fix.
rule getCollateralValue_borrowing_lower {
    env e;
    Liquidation.VaultCache vaultCache;
    address account;
    address collateral;

    // Not enough. Counterexample:
    // https://prover.certora.com/output/65266/83f92155749f42d98cadd58754511ebe/?anonymousKey=b3bbd7dcc5b9cec2dbc6104528456fd908ad9057
    // Need to also assume about ramp duration
    // Liquidation.LTVConfig ltvConfig = getLTVConfig(e, collateral);
    require LTVConfigAssumptions(e, getLTVConfig(e, collateral));

    uint256 collateralValue_borrowing = getCollateralValueExt(e, vaultCache, account, collateral, Liquidation.LTVType.BORROWING);

    uint256 collateralValue_liquidation = getCollateralValueExt(e, vaultCache, account, collateral, Liquidation.LTVType.LIQUIDATION);

    require collateralValue_liquidation > 0;
    require collateralValue_borrowing > 0;

    assert collateralValue_borrowing <= collateralValue_liquidation;

}