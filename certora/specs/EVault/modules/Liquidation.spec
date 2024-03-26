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

methods {
    // This is defined in IPriceOracle which is in another codebase
    function _.getQuote(uint256 amount, address base, address quote) external => NONDET;
    function _.getQuotes(uint256 amount, address base, address quote) external => NONDET;
    function isRecognizedCollateralExt(address collateral) external returns (bool) envfree;

    function isCollateralEnabledExt(address account, address market) external returns (bool) envfree;

    function isAccountStatusCheckDeferredExt(address account) external returns (bool) envfree;
}

rule checkLiquidation_healthy() {
    env e;
    address liquidator;
    address violator; 
    address collateral;
    uint256 maxRepay;
    uint256 maxYield;

    Liquidation.MarketCache marketCache;
    require marketCache.oracle!= 0;

    address[] collaterals = getCollateralsExt(e, violator);

    uint256 liquidityCollateralValue = getLiquidityValue(e, violator, marketCache, collaterals);
    uint256 liquidityLiabilityValue = getLiabilityValue(e, violator, marketCache, collaterals);

    (maxRepay, maxYield) = checkLiquidation(e, liquidator, violator, collateral);

    require liquidityCollateralValue >= liquidityLiabilityValue;
    assert maxRepay == 0;
    assert maxYield == 0;
} 

/*
rule checkLiquidation_mustRevert {
    env e;
    address liquidator;
    address violator;
    address collateral;
    uint256 maxRepay;
    uint256 maxYield;
    (maxRepay, maxYield) = checkLiquidation@withrevert(e, liquidator, violator, collateral);
    bool reverted = lastReverted;

    bool selfLiquidate = liquidator == violator;
    bool badCollateral = !isRecognizedCollateralExt(collateral);
    bool notEnabledCollateral = !isCollateralEnabledExt(violator, collateral);
    bool violatorStatusCheckDeferred = isAccountStatusCheckDeferredExt(violator);

    assert selfLiquidate || 
        badCollateral || 
        notEnabledCollateral ||
        violatorStatusCheckDeferred => reverted;

}
*/