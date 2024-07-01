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

// run: https://prover.certora.com/output/65266/d21dd88f07684b01930ff44d737378d7/?anonymousKey=660fbbe1c86127afc78c999a9ddd58c156ac7dad

import "Base.spec";
methods {
    function isRecognizedCollateralExt(address collateral) external returns (bool) envfree;
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

    require LTVConfigAssumptions(e, getLTVConfig(e, collateral));

    uint256 collateralValue_borrowing = getCollateralValueExt(e, vaultCache, account, collateral, false);

    uint256 collateralValue_liquidation = getCollateralValueExt(e, vaultCache, account, collateral, true);

    require collateralValue_liquidation > 0;
    require collateralValue_borrowing > 0;

    assert collateralValue_borrowing <= collateralValue_liquidation;

}

// passing (though I believe this was only introduced for debugging)
rule calculateLiquidation_setViolator {
    env e;
    Liquidation.VaultCache vaultCache;
    address liquidator;
    address violator;
    address collateral;
    uint256 desiredRepay;
    LiquidationModule.LiquidationCache liqCache = calculateLiquidationExt(e,
        vaultCache,
        liquidator,
        violator,
        collateral,
        desiredRepay);
    assert liqCache.violator == violator;
    assert liqCache.liquidator == liquidator;
    assert violator != liquidator;
}

// passed
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

