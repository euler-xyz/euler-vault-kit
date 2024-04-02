/*
CER-163 / Verify EVK-7
If operation enabled AND violator unhealthy, liquidate:

liquidates the debt of the violator and transfers it to the liquidator, up to
the amount returned by checkLiquidation as per desired amount to be repaid
specified (repayAssets)

seizes the collateral shares of the violator and transfers them to the
liquidator, up to the amount returned by checkLiquidation as per desired amount
to be repaid specified (repayAssets)

If collateral is worthless, it can be seized without taking on any debt by the
liquidator.

If operation enabled AND violator healthy, liquidate must be a no-op.

If debt socialization enabled AND the violator has outstanding debt after the
liquidation AND the violator has no more accepted collaterals, the debt must be
socialized amongst all the lenders in the vault.

liquidate must revert if:
 - liquidate operation disabled
 - violator is the same account as liquidator
 - collateral is not accepted
 - collateral is not enabled collateral for the violator
 - liability vault is not enabled as the only controller of the violator
 - liability vault is not enabled as the only controller of the liquidator
 - violator account status check is deferred
 - price oracle is not configured
 - amount of collateral to be seized is less than the desired amount of 
   yieldspecified (minYieldBalance)

This operation is always called through the EVC.
This operation schedules the account status check on the liquidator address.
This operation schedules the vault status check.

Refer to the EVC documentation to learn how the collateral seizing mechanism
works:
*/

methods {
    function _.requireVaultStatusCheck() external => NONDET;
    function _.requireAccountAndVaultStatusCheck(address account) external => NONDET; 
    function _.calculateDTokenAddress() internal => NONDET;
    function EVCClient.EVCRequireStatusChecks(address account) internal => NONDET;
    function _.validateAndCallHook(Liquidation.Flags hookedOps, uint32 operation, address caller) internal => NONDET;
    function isRecognizedCollateralExt(address collateral) external returns (bool) envfree;
    function isCollateralEnabledExt(address account, address market) external returns (bool) envfree;
    function isAccountStatusCheckDeferredExt(address account) external returns (bool) envfree;
    function vaultIsOnlyController(address account) external returns (bool) envfree;
}

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

rule liquidate_mustRevert {
    env e;
    address violator;
    address collateral; 
    uint256 repayAssets; 
    uint256 minYieldBalance;

    address liquidator = getLiquidator(e);
    bool selfLiquidation = violator == liquidator;
    bool recognizedCollateral = isREcognizedCollateralExt(collateral);
    bool enabledCollateral = isCollateralEnabledExt(violator, collateral);
    bool violatorStatusCheckDeferred = isAccountStatusCheckDeferredExt(violator);

    liquidate(e, violator, collateral, repayAssets, minYieldBalance);
    assert !selfLiquidation;
    assert recognizedCollateral;
    assert enabledCollateral;
    assert !violatorStatusCheckDeferred;
    
}