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

// using SafeERC20Lib as safeERC20;
using ERC20 as erc20;

methods {
    // envfree
    function isRecognizedCollateralExt(address collateral) external returns (bool) envfree;
    function isCollateralEnabledExt(address account, address market) external returns (bool) envfree;
    function vaultIsOnlyController(address account) external returns (bool) envfree;
    function isAccountStatusCheckDeferredExt(address account) external returns (bool) envfree;
    
    function ProxyUtils.metadata() internal returns (address, address, address)=> CVLProxyMetadata();
    // Workaround for lack of ability to summarize metadata
    // function Cache.loadVault() internal returns (Liquidation.VaultCache memory) => CVLLoadVault();

    // function LiquidityUtils.calculateLiquidity(
    //     Liquidation.VaultCache memory vaultCache,
    //     address account,
    //     address[] memory collaterals,
    //     Liquidation.LTVType ltvType
    // ) internal returns (uint256, uint256) => calcLiquidity(account, collaterals, ltvType);

    // IPriceOracle
    function _.getQuote(uint256 amount, address base, address quote) external => CVLGetQuote(amount, base, quote) expect (uint256);
    function _.getQuotes(uint256 amount, address base, address quote) external => CVLGetQuotes(amount, base, quote) expect (uint256, uint256);


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

// ghost CVLGetQuotes_bidOut(uint256, address, address) returns uint256;
// ghost CVLGetQuotes_askOut(uint256, address, address) returns uint256;

ghost CVLGetQuote(uint256, address, address) returns uint256 {
    // The total value returned by the oracle is assumed < 2**230-1.
    // There will be overflows without an upper bound on this number.
    // (For example, it must be less than 2**242-1 to avoid overflow in
    // LTVConfig.mul)
    axiom forall uint256 x. forall address y. forall address z. 
        CVLGetQuote(x, y, z) < 1725436586697640946858688965569256363112777243042596638790631055949823;
}


function CVLGetQuotes(uint256 amount, address base, address quote) returns (uint256, uint256) {
    return (
        CVLGetQuote(amount, base, quote),
        CVLGetQuote(amount, base, quote)
    );
}

ghost address oracleAddress;
ghost address unitOfAccount;
function CVLProxyMetadata() returns (address, address, address) {
    return (erc20, oracleAddress, unitOfAccount);
}

// CRITICAL: [main] ERROR ALWAYS - Found errors in certora/specs/CER-161-Liquidation/CER-162-CheckLiquidation.spec:
// CRITICAL: [main] ERROR ALWAYS - Error in spec file (CER-162-CheckLiquidation.spec:87:1): The type VaultCache is not allowed in a return position of a ghost functio
// ghost CVLLoadVaultUninterp() returns Liquidation.VaultCache;

function CVLLoadVault() returns Liquidation.VaultCache {
    Liquidation.VaultCache vaultCache;
    require vaultCache.oracle != 0;
    return vaultCache;
}

persistent ghost uint256 dummy_collateral;
persistent ghost uint256 dummy_liquidity;
function calcLiquidity(address account, address[] collaterals, Liquidation.LTVType ltvType) returns (uint256, uint256) {
    // unconstrained but same value for same returns
    return (dummy_collateral, dummy_liquidity);
}

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

function LTVConfigAssumptions(env e, address collateral) returns bool {
    Liquidation.LTVConfig ltvConfig = getLTVConfig(e, collateral);
    // the LTV should be less than 1. Here 1e4 is the scaling factor.
    // So we assume governance sets these GT 1.
    bool targetLTVLessOne = ltvConfig.targetLTV < 10000;
    bool originalLTVLessOne = ltvConfig.originalLTV < 10000;
    bool target_less_original = ltvConfig.targetLTV < ltvConfig.originalLTV;
    mathint timeRemaining = ltvConfig.targetTimestamp - e.block.timestamp;
    return targetLTVLessOne &&
        originalLTVLessOne &&
        target_less_original && 
        require_uint32(timeRemaining) < ltvConfig.rampDuration;
}

rule getCollateralValue_borrowing_lower {
    env e;
    Liquidation.VaultCache vaultCache;
    address account;
    address collateral;

    // require getLTVConfig(e, collateral).targetLTV < getLTVConfig(e, collateral).originalLTV;
    // Not enough. Counterexample:
    // https://prover.certora.com/output/65266/83f92155749f42d98cadd58754511ebe/?anonymousKey=b3bbd7dcc5b9cec2dbc6104528456fd908ad9057
    // Need to also assume about ramp duration and the LTVs
    require LTVConfigAssumptions(e, collateral);

    uint256 collateralValue_borrowing = getCollateralValueExt(e, vaultCache, account, collateral, Liquidation.LTVType.BORROWING);

    uint256 collateralValue_liquidation = getCollateralValueExt(e, vaultCache, account, collateral, Liquidation.LTVType.LIQUIDATION);

    require collateralValue_liquidation > 0;
    require collateralValue_borrowing > 0;

    assert collateralValue_borrowing <= collateralValue_liquidation;

}