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

using SafeERC20Lib as safeERC20;

methods {
    // IPriceOracle
    function _.getQuote(uint256 amount, address base, address quote) external => CVLGetQuote(amount, base, quote) expect (uint256);
    function _.getQuotes(uint256 amount, address base, address quote) external => CVLGetQuotes(amount, base, quote) expect (uint256, uint256);
    function isRecognizedCollateralExt(address collateral) external returns (bool) envfree;

    function isCollateralEnabledExt(address account, address market) external returns (bool) envfree;

    function isAccountStatusCheckDeferredExt(address account) external returns (bool) envfree;
    // function Cache.initVaultCache(Liquidation.VaultCache memory vaultCache) internal returns (bool) => NONDET;
    // function LiquidityUtils.calculateLiquidity(
    //     Liquidation.VaultCache memory vaultCache,
    //     address account,
    //     address[] memory collaterals,
    //     Liquidation.LTVType ltvType
    // ) internal returns (uint256, uint256) => calcLiquidity(account, collaterals, ltvType);

    // function ProxyUtils.metadata() internal returns (address, address, address)=> NONDET;

    // Workaround for lack of ability to summarize metadata
    function Cache.loadVault() internal returns (Liquidation.VaultCache memory) => CVLLoadVault();

	// IERC20
	function _.name()                                external => DISPATCHER(true);
    function _.symbol()                              external => DISPATCHER(true);
    function _.decimals()                            external => DISPATCHER(true);
    function _.totalSupply()                         external => DISPATCHER(true);
    function _.balanceOf(address)                    external => DISPATCHER(true);
    function _.allowance(address,address)            external => DISPATCHER(true);
    function _.approve(address,uint256)              external => DISPATCHER(true);
    function _.transfer(address,uint256)             external => DISPATCHER(true);
    function _.transferFrom(address,address,uint256) external => DISPATCHER(true);
}

function CVLGetQuote(uint256 amount, address base, address quote) returns uint256 {
    uint256 out;
    return out;
}

function CVLGetQuotes(uint256 amount, address base, address quote) returns (uint256, uint256) {
    uint256 bidOut;
    uint256 askOut;
    return (bidOut, askOut);
}

ghost address oracleAddress;
ghost address unitOfAccount;
function CVLProxyMetadata() returns (address, address, address) {
    return (safeERC20, oracleAddress, unitOfAccount);
}

function CVLLoadVault() returns Liquidation.VaultCache {
    Liquidation.VaultCache vaultCache;
    require vaultCache.oracle != 0;
    return vaultCache;
}

rule checkLiquidation_healthy() {
    env e;
    address liquidator;
    address violator; 
    address collateral;
    uint256 maxRepay;
    uint256 maxYield;

    Liquidation.VaultCache vaultCache;
    require vaultCache.oracle != 0;

    address[] collaterals = getCollateralsExt(e, violator);

    uint256 liquidityCollateralValue = getLiquidityValue(e, violator, vaultCache, collaterals);
    uint256 liquidityLiabilityValue = getLiabilityValue(e, violator, vaultCache, collaterals);

    (maxRepay, maxYield) = checkLiquidation(e, liquidator, violator, collateral);

    require liquidityCollateralValue >= liquidityLiabilityValue;
    assert maxRepay == 0;
    assert maxYield == 0;
}

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

    require collateralValue > 0;
    require liabilityValue > 0;
    require collateralValue < liabilityValue;

    (maxRepay, maxYield) = checkLiquidation(e, liquidator, violator, collateral);

    assert maxYield >= maxRepay;

}

rule debugCheckLiquidation {
    env e;
    address violator;
    Liquidation.VaultCache vaultCache = loadVaultExt(e);

    Liquidation.Assets owed = getCurrentOwedExt(e, vaultCache, violator);
    // satisfy !isZero(owed);
    satisfy owed > 0;
}

rule alwaysRevert {
    env e;
    address liquidator;
    address violator; 
    address collateral;

    checkLiquidation@withrevert(e, liquidator, violator, collateral);
    satisfy !lastReverted;
}

rule loadVaultSanity {
    env e;
    // require oracleAddress != 0;
    Liquidation.VaultCache vaultCache = loadVaultExt(e);
    // validateOracleExt(e, vaultCache);
    assert vaultCache.oracle != 0;
}

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