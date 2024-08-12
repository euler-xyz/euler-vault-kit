import "Base.spec";
import "LoadVaultSummary.spec";
using DummyERC20A as ERC20a;
using DummyETokenA as ETokenA; // Used to assume collaterals are ETokens.
using DummyETokenB as ETokenB; // Allows for possibility of multiple 
                               // addresses for different collaterals.

methods {
    function checkAccountMagicValue() external returns (bytes4) envfree;
    function checkAccountMagicValueMemory() external returns (bytes memory) envfree;
    function checkVaultMagicValueMemory() external returns (bytes memory) envfree;
    function EVCHarness.areChecksDeferred() external returns (bool) envfree;
    // healthStatusCheck reverts unless this is true. We assume it's true 
    // approximate the real situation where these checks get triggered
    // by the EVC before which this flag will be set.
    function EVCHarness.areChecksInProgress() external returns bool => CVLAreChecksInProgress();
    // unresolved calls that havoc all contracts
    function _.isHookTarget() external => NONDET;
    function _.invokeHookTarget(address caller) internal => NONDET;
    function _.tryBalanceTrackerHook(address account, uint256 newAccountBalance, bool forfeitRecentReward) internal => NONDET;
    function _.balanceTrackerHook(address account, uint256 newAccountBalance, bool forfeitRecentReward) external => NONDET;
    function _.emitTransfer(address from, address to, uint256 value) external => NONDET;
    function EVCHarness.disableController(address account) external => NONDET;
    function _.computeInterestRate(address vault, uint256 cash, uint256 borrows) external => NONDET;
    function _.onFlashLoan(bytes data) external => NONDET;

    // Harness
    function LiquidationHSHarness.hasDebtSocialization() external returns (bool) envfree;

    // EVC
    function _.requireVaultStatusCheck() external => DISPATCHER(true);
    function _.requireAccountAndVaultStatusCheck(address) external => DISPATCHER(true);

    // Summaries
    function _.safeTransferFrom(address token, address from, address to, uint256 value, address permit2) internal => CVLSafeTransferFrom(token, from, to, value) expect void;
    function _.enforceCollateralTransfer(address collateral, uint256 amount,
        address from, address receiver) internal => 
        CVLEnforceCollateralTransfer(collateral, amount, from, receiver) expect void;
    // To deal with changes between LTV values:
    // function _.getLTV(address collateral, bool liquidation) internal => CVLGetLTV(collateral, liquidation) expect (BaseHarness.ConfigAmount);
    // We can't handle the low-level call in 
    // EthereumVaultConnector.checkAccountStatusInternal 
    // and so reroute it to RiskManager's status check with this summary.
    function EthereumVaultConnector.checkAccountStatusInternal(address account) internal returns (bool, bytes memory) => 
        CVLCheckAccountStatusInternal(account);
    function EthereumVaultConnector.checkVaultStatusInternal(address vault) internal returns (bool, bytes memory) =>
        CVLCheckVaultStatusInternal();

    function _.EVCRequireStatusChecks(address account) internal =>
        EVCRequireStatusChecksCVL(account) expect void;
}

//-----------------------------------------------------------------------------
// Summaries and Ghost State
//-----------------------------------------------------------------------------

persistent ghost address accountToCheckGhost;
function EVCRequireStatusChecksCVL(address account) {
    accountToCheckGhost = account;
}

// We summarize EthereumVaultConnector.checkAccountStatusInternal
// because we need to direct the low-level call to RiskManager.
// checkAccountStatus and this linking doesn't happen automatically
function CVLCheckAccountStatusInternalBool(env e, address account) returns bool {
    address[] collaterals = evc.getCollaterals(e, account);
    checkAccountStatus@withrevert(e, account, collaterals);
    return !lastReverted;
}

function CVLCheckAccountStatusInternal(address account) returns (bool, bytes) {
    // We need a new env for the first function.
    // Since the vault calls the EVC, otherwise msg.sender
    // would become the vault unless we declare a fresh environment.
    env eEVC;
    return (CVLCheckAccountStatusInternalBool(eEVC, account), 
        checkAccountMagicValueMemory());
}

function CVLCheckVaultStatusInternalBool(env e) returns bool {
    checkVaultStatus@withrevert(e);
    return !lastReverted;
}

function CVLCheckVaultStatusInternal() returns (bool, bytes) {
    // We need a new env for the first function.
    // Since the vault calls the EVC, otherwise msg.sender
    // would become the vault unless we declare a fresh environment.
    env eEVC;
    return (CVLCheckVaultStatusInternalBool(eEVC),
        checkVaultMagicValueMemory());
}

function CVLAreChecksInProgress() returns bool {
    return true;
}

function CVLSafeTransferFrom(address token, address from, address to, uint256 value) {
    // We need a new env since this will
    // be a call from the vault to the ERC20 rather than a call
    // from the original message sender to the ERC20.
    // would become the vault unless we declare a fresh environment.
    env e;
    if (token == ERC20a) {
        ERC20a.transferFrom(e, from, to, value);
    } else if (token == ETokenA) {
        ETokenA.transferFrom(e, from, to, value);
    } else if (token == ETokenB) {
        ETokenB.transferFrom(e, from, to, value);
    }
}

/*
* The prover struggles to reason about the low-level call operations involved
* in the real EVCClient.enforceControlCollateral function, so we need
* to emulate the real behavior here. Here's how it works in the real code:
*  - EVCClient calls evc.controlCollateral passing a call to `transfer(receiver, amount)` along with the collateral and from addresses
*  - In controlCollateral the from address is used to set the onBehalfOfAccount
*  and some authentication is done
* - After this, callWithContextInternal invokes the transfer function 
* on the collateral address
* - Collaterals in the EVK must all be Token.sol and token's transfer
* implementation calls initOperation which enqueues an account status
* check on the EVC for the onBehalfOfAccount it also gets from EVC.
* Because onBehalfOfAccount was set to the from address in callWithContextInternal this status check is for the from account
* To emulate this, we:
* - explicitly call EToken.transferFrom using the expected addresses
* - enqueue a status check on the evc for the "from" address
*/
// Because calling to requireAccountStatusCheck on EVC is expensive
// for the prover, instead assign which account gets checked to a ghost
function CVLEnforceCollateralTransfer(address collateral, uint256 amount, address from, address receiver) {
    env e;
    if (collateral == ETokenA) {
        ETokenA.transferFromInternalHarnessed(e, from, receiver, amount);
    } else if (collateral == ETokenB) {
        ETokenB.transferFromInternalHarnessed(e, from, receiver, amount);
    }
}

//-----------------------------------------------------------------------------
// Rules
//-----------------------------------------------------------------------------
/*
For Liquidation.liquidate we need to split this rule into cases:
    - account checked != liquidator and account checked != violator
    - account checked == liquidator and account checked != violator and:
        - debt socialization disabled
        - debt socialization enabled 
These cases are handled separately:
    - account checked == violator:
        if this account was healthy before the call does nothing. This is not
        only easy to see manually but we prove this in 
        checkLiquidation.healthy() in Liquidation.spec
    - liquidator  == violator:
        In this case the call reverts which is easy to check but also
        proved in liquidate_mustRevert in Liquidation.spec
*/

// passing: https://prover.certora.com/output/65266/132c942ca2a2463b84e15b77becdfa11/?anonymousKey=431faa27dd7b649306de7e37067b7a75e57271f8
rule liquidateAccountsStayHealthy_liquidator_no_debt_socialization {
    env e;
    address account;
    address[] collaterals = evc.getCollaterals(e, account);
    require collaterals.length <= 2; // loop bound
    require oracleAddress != 0; 
    // Vault cannot be a user of itself
    require account != currentContract;
    // Vault should not be used as a collateral
    require collaterals[0] != currentContract;
    require collaterals[1] != currentContract;
    // not sure the following 4 are really needed
    require account != erc20;
    require account != oracleAddress;
    require account != evc;
    require account != unitOfAccount;
    require evc.areChecksDeferred();

    require LTVConfigAssumptions(e, getLTVConfig(e, ETokenA));
    require LTVConfigAssumptions(e, getLTVConfig(e, ETokenB));
    // Collaterals must be ETokens
    if (collaterals.length > 0) {
        require collaterals[0] == ETokenA;
    }
    if (collaterals.length > 1) {
        require collaterals[1] == ETokenB;
    }

    address violator;
    address collateral;
    uint256 repayAssets;
    uint256 minYieldBalance;

    // disable debt socialization
    require !hasDebtSocialization();

    // initialize checked accounts to 0
    require accountToCheckGhost == 0; // account checked in initialize

    // account eq liquidator case
    require collateral == ETokenA || collateral == ETokenB;
    address liquidator = actualCaller(e);
    require account == liquidator;
    require violator != liquidator;

    bool healthyBefore = checkLiquidityReturning(e, account, collaterals);
    currentContract.liquidate(e, violator, collateral, repayAssets, minYieldBalance);

    // replace the real call path involving the EVC calling back into the
    // vault with a direct call on checkAccountStatus from the vault

    if(accountToCheckGhost != 0) {
        currentContract.checkAccountStatus(e, accountToCheckGhost, collaterals);
    }

    bool healthyAfter = checkLiquidityReturning(e, account, collaterals);
    assert healthyBefore => healthyAfter; 
}

// passing: https://prover.certora.com/output/65266/2d955907619c4c748e82791a3bb5843e/?anonymousKey=dfb93c10b2311ab0f99ffaf551bcd1fc4b7447b0
rule liquidateAccountsStayHealthy_liquidator_with_debt_socialization {
    env e;
    address account;
    address[] collaterals = evc.getCollaterals(e, account);
    require collaterals.length <= 2; // loop bound
    require oracleAddress != 0; 
    // Vault cannot be a user of itself
    require account != currentContract;
    // Vault should not be used as a collateral
    require collaterals[0] != currentContract;
    require collaterals[1] != currentContract;
    // not sure the following 4 are really needed
    require account != erc20;
    require account != oracleAddress;
    require account != evc;
    require account != unitOfAccount;
    require evc.areChecksDeferred();

    require LTVConfigAssumptions(e, getLTVConfig(e, ETokenA));
    require LTVConfigAssumptions(e, getLTVConfig(e, ETokenB));
    // Collaterals must be ETokens
    if (collaterals.length > 0) {
        require collaterals[0] == ETokenA;
    }
    if (collaterals.length > 1) {
        require collaterals[1] == ETokenB;
    }

    address violator;
    address collateral;
    uint256 repayAssets;
    uint256 minYieldBalance;

    // enable debt socialization
    require hasDebtSocialization();

    // initialize checked accounts to 0
    require accountToCheckGhost == 0; // account checked in initialize

    // account eq liquidator case
    require collateral == collaterals[0] || collateral == collaterals[1];
    address liquidator = actualCaller(e);
    require account == liquidator;
    require violator != liquidator;

    bool healthyBefore = checkLiquidityReturning(e, account, collaterals);
    currentContract.liquidate(e, violator, collateral, repayAssets, minYieldBalance);

    // replace the real call path involving the EVC calling back into the
    // vault with a direct call on checkAccountStatus from the vault

    if(accountToCheckGhost != 0) {
        currentContract.checkAccountStatus(e, accountToCheckGhost, collaterals);
    }

    bool healthyAfter = checkLiquidityReturning(e, account, collaterals);
    assert healthyBefore => healthyAfter; 
}

// passing: https://prover.certora.com/output/65266/83941c4b1c3448a6bd56c3edebf44ced/?anonymousKey=11866ef668f148318b2bea213560da6a5b6df937
rule liquidateAccountsStayHealthy_not_violator {
    env e;
    address account;
    address[] collaterals = evc.getCollaterals(e, account);
    require collaterals.length <= 2; // loop bound
    require oracleAddress != 0; 
    // Vault cannot be a user of itself
    require account != currentContract;
    // Vault should not be used as a collateral
    require collaterals[0] != currentContract;
    require collaterals[1] != currentContract;
    // not sure the following 4 are really needed
    require account != erc20;
    require account != oracleAddress;
    require account != evc;
    require account != unitOfAccount;
    require evc.areChecksDeferred();

    require LTVConfigAssumptions(e, getLTVConfig(e, ETokenA));
    require LTVConfigAssumptions(e, getLTVConfig(e, ETokenB));
    // Collaterals must be ETokens
    if (collaterals.length > 0) {
        require collaterals[0] == ETokenA;
    }
    if (collaterals.length > 1) {
        require collaterals[1] == ETokenB;
    }

    address violator;
    address collateral;
    uint256 repayAssets;
    uint256 minYieldBalance;

    address liquidator = actualCaller(e);

    // initialize checked accounts to 0
    require accountToCheckGhost == 0; // account checked in initialize

    // account NE violator case
    require account != violator;
    require liquidator != violator;
    require account != liquidator;

    bool healthyBefore = checkLiquidityReturning(e, account, collaterals);
    currentContract.liquidate(e, violator, collateral, repayAssets, minYieldBalance);
    // The only way to call a vault funciton is through EVC's call, batch, 
    // or permit. During all of these status checks are deferred and at the end
    // these call restoreExecutionContext which triggers the deferred checks.
    // Replace the real call path involving the EVC calling back into the
    // vault with a direct call on checkAccountStatus from the vault.
    // (For the not_violator / not liquidator case, we can also directly
    // call evc.checkStatusAll rather than using these ghosts and
    // the direct call on checkAccountStatus, but for the liquidator case
    // this will drop performance enough to hit a timeout)

    if(accountToCheckGhost != 0) {
        currentContract.checkAccountStatus(e, accountToCheckGhost, collaterals);
    }

    bool healthyAfter = checkLiquidityReturning(e, account, collaterals);
    assert healthyBefore => healthyAfter; 
}

rule liquidateAccountsStayHealthy_account_cur_contract {
    env e;
    address account;
    address[] collaterals = evc.getCollaterals(e, account);
    require collaterals.length <= 2; // loop bound
    require oracleAddress != 0; 
    // Vault should not be used as a collateral
    require collaterals[0] != currentContract;
    require collaterals[1] != currentContract;
    // not sure the following 4 are really needed
    require account != erc20;
    require account != oracleAddress;
    require account != evc;
    require account != unitOfAccount;
    require evc.areChecksDeferred();

    require LTVConfigAssumptions(e, getLTVConfig(e, ETokenA));
    require LTVConfigAssumptions(e, getLTVConfig(e, ETokenB));
    // Collaterals must be ETokens
    if (collaterals.length > 0) {
        require collaterals[0] == ETokenA;
    }
    if (collaterals.length > 1) {
        require collaterals[1] == ETokenB;
    }

    // vault is account of itself case 
    require account == currentContract;

    address violator;
    address collateral;
    uint256 repayAssets;
    uint256 minYieldBalance;

    address liquidator = actualCaller(e);

    // initialize checked accounts to 0
    require accountToCheckGhost == 0; // account checked in initialize

    bool healthyBefore = checkLiquidityReturning(e, account, collaterals);
    currentContract.liquidate(e, violator, collateral, repayAssets, minYieldBalance);
    // The only way to call a vault funciton is through EVC's call, batch, 
    // or permit. During all of these status checks are deferred and at the end
    // these call restoreExecutionContext which triggers the deferred checks.
    // Replace the real call path involving the EVC calling back into the
    // vault with a direct call on checkAccountStatus from the vault.
    // (For the not_violator / not liquidator case, we can also directly
    // call evc.checkStatusAll rather than using these ghosts and
    // the direct call on checkAccountStatus, but for the liquidator case
    // this will drop performance enough to hit a timeout)

    if(accountToCheckGhost != 0) {
        currentContract.checkAccountStatus(e, accountToCheckGhost, collaterals);
    }

    bool healthyAfter = checkLiquidityReturning(e, account, collaterals);
    assert healthyBefore => healthyAfter; 
}