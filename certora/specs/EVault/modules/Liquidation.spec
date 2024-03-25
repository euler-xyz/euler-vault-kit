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

rule checkLiquidation_healthy() {
    env e;
    address liquidator;
    address violator; 
    address collateral;
    MarketCache.MarketCache marketCache;
    uint256 maxRepay;
    uint256 maxYield;
    uint256 liquidityCollateralValue; 
    uint256 liquidityLiabilityValue;
    address[] collaterals;
    // (MarketCache memory marketCache, address liquidator) = initOperation(OP_LIQUIDATE, CHECKACCOUNT_CALLER);
    // (maxRepay, maxYield) = checkLiquidation(e, liquidator, violator, collateral);
    // (liquidityCollateralValue, liquidityLiabilityValue) =
    //        calculateLiquidity(e, violator, collaterals);
    require liquidityCollateralValue >= liquidityLiabilityValue;
    assert maxRepay == 0;
    assert maxYield == 0;
} 