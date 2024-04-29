/*
//-----------------------------------------------------------------------------
// accountLiquidity
//-----------------------------------------------------------------------------
For a given account, accountLiquidity calculates and returns the sum of risk
adjusted values of enabled, and accepted, collaterals and the value of
liability.

If liquidation parameter is true, the risk adjusted value of collateral is the
value of collateral multiplied by the current LTV factor calculated using the
original LTV factor, the target LTV and ramp duration (assuming the LTV factor
changes linearly from the original LTV to the target LTV in ramp duration time).

If liquidation parameter is false, the risk adjusted value of collateral is the
value of collateral multiplied by the target LTV.

accountLiquidity must revert if:
 - liability vault is not enabled as the only controller of the account
 - price oracle is not configured

//-----------------------------------------------------------------------------
// accountLiquidityFull
//-----------------------------------------------------------------------------
For a given account, accountLiquidityFull calculates and returns the risk
adjusted values of enabled, and accepted, collaterals and the value of
liability.

If liquidation parameter is true, the risk adjusted value of collateral is the
value of collateral multiplied by the current LTV factor calculated using the
original LTV factor, the target LTV and ramp duration (assuming the LTV factor
changes linearly from the original LTV to the target LTV in ramp duration time).

If liquidation parameter is false, the risk adjusted value of collateral is the
value of collateral multiplied by the target LTV.

accountLiquidityFull must revert if:
 - liability vault is not enabled as the only controller of the account
 - price oracle is not configured


//-----------------------------------------------------------------------------
// checkAccountStatus
//-----------------------------------------------------------------------------
If the authenticated account does not have an outstanding liability,
disableController disables liability vault as a controller for the authenticated
account. disableController must revert if the authenticated account has an
outstanding liability.

If account healthy, considering the risk adjusted value of collateral is the
value of collateral multiplied by the target LTV, checkAccountStatus returns the
selector of itself.

checkAccountStatus must revert if:
 - not called by the EVC
 - not called when checks in progress
 - account unhealthy

//-----------------------------------------------------------------------------
// checkVaultStatus
//-----------------------------------------------------------------------------
If vault status is valid, checkVaultStatus updates the interest rate, clears the
snapshot (if created) and returns the selector of itself.

The interest rate is updated by calling into the configured interest rate model
contract and cannot exceed the MAX_ALLOWED_INTEREST_RATE. If the interest rate
model contract is not configured OR it reverts, the interest rate must remain
unchanged.

checkVaultStatus must revert if:
 - not called by the EVC
 - not called when checks in progress
 - vault status invalid
 */

using ERC20 as erc20;
using EthereumVaultConnector as evc;
methods {
    // envfree
    function vaultIsOnlyController(address account) external returns (bool) envfree;
    // function getCollateralsExt(address account) public returns (address[] memory) envfree;
        
    function ProxyUtils.metadata() internal returns (address, address, address)=> CVLProxyMetadata();

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

ghost CVLGetQuote(uint256, address, address) returns uint256;
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

rule liquidations_equal_for_one {
    env e;
    calldataarg args;
    address account;
    bool liquidation;

    uint256 collateralValue; 
    uint256 liabilityValue;

    require oracleAddress != 0;
    require unitOfAccount != 0;
    
    address[] collaterals = getCollateralsExt(e, account);
    require collaterals.length == 1;
    (collateralValue, liabilityValue) = accountLiquidity(e, account, liquidation);
    address[] collaterals_full; 
    uint256[] collateralValues; 
    uint256 liabilityValue_full;
    (collaterals_full, collateralValues, liabilityValue_full) = accountLiquidityFull(e, account, liquidation);
    assert collateralValue == collateralValues[1];
    assert liabilityValue == liabilityValue_full;

}

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

rule checkVaultStatusMustRevert {
    env e;
    calldataarg args;
    bool checksInProgress = evc.areChecksInProgress(e);
    checkVaultStatus(e);
    assert e.msg.sender == evc;
    assert checksInProgress;
}

rule sanity (method f) {
    env e;
    calldataarg args;
    f(e, args);
    satisfy true;
}