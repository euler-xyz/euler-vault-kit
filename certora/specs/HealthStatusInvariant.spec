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
    // pure, so NONDET is safe
    function _.isHookTarget() external => NONDET; 
    // calls external contract. Here we assume invokeHookTarget does
    // not affect the vault's internal state especially user balances.
    // This is a pretty safe assumption because it is not the EVC and
    // access controls in the vault will not allow non-EVC calls to succeed.
    // there is also the nonreentrant modifier in most places.
    function _.invokeHookTarget(address caller) internal => NONDET; 
    // The following two are both related to balanceTrackerHook in the
    // RewardStreams repository. The implementation of BalanceTrackerHook
    // there does not affect the state of the vault contracts
    // https://github.com/euler-xyz/reward-streams/blob/master/src/TrackingRewardStreams.sol#L31-L62
    function _.tryBalanceTrackerHook(address account, uint256 newAccountBalance, bool forfeitRecentReward) internal => NONDET;
    function _.balanceTrackerHook(address account, uint256 newAccountBalance, bool forfeitRecentReward) external => NONDET;
    // just emits an event so NONDET is safe
    function _.emitTransfer(address from, address to, uint256 value) external => NONDET; 
    // has an actual affect -- disables a controller, but this is only called by RiskManager.disableController which reverts unless the controller balance is 0. So I think this nondet is safe.
    function EVCHarness.disableController(address account) external => NONDET; 
    // computeInterestRate is not strictly pure -- the implementations of 
    // this function seem to keep state to calculate the future interest rate
    // but modeling this as returning an arbitrary should be OK. (There is
    // technically a side effect of storing state but that state only
    // affects this return value)
    function _.computeInterestRate(address vault, uint256 cash, uint256 borrows) external => NONDET;
    // onFlashLoan is from an external contract. Here we assume this function 
    // does not affect the vault's internal state especially user balances.
    // This is a pretty safe assumption because it is not the EVC and
    // access controls in the vault will not allow non-EVC calls to succeed.
    // there is also the nonreentrant modifier in most places.
    function _.onFlashLoan(bytes data) external => NONDET;
    function EVCHarness.getCollaterals(address) external returns (address[] memory) envfree;

    // EVC
    function _.requireVaultStatusCheck() external => DISPATCHER(true);
    function _.requireAccountAndVaultStatusCheck(address) external => DISPATCHER(true);

    // Summaries
    function _.safeTransferFrom(address token, address from, address to, uint256 value, address permit2) internal => CVLSafeTransferFrom(token, from, to, value) expect void;
    function _.enforceCollateralTransfer(address collateral, uint256 amount,
        address from, address receiver) internal => 
        CVLEnforceCollateralTransfer(collateral, amount, from, receiver) expect void;
    // We can't handle the low-level call in 
    // EthereumVaultConnector.checkAccountStatusInternal 
    // and so reroute it to RiskManager's status check with this summary.
    function EthereumVaultConnector.checkAccountStatusInternal(address account) internal returns (bool, bytes memory) => 
        CVLCheckAccountStatusInternal(account);
    function EthereumVaultConnector.checkVaultStatusInternal(address vault) internal returns (bool, bytes memory) =>
        CVLCheckVaultStatusInternal();
}

// We summarize EthereumVaultConnector.checkAccountStatusInternal
// because we need to direct the low-level call to RiskManager.
// checkAccountStatus and this linking doesn't happen automatically
function CVLCheckAccountStatusInternalBool(env e, address account) returns bool {
    address[] collaterals = evc.getCollaterals(account);
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
function CVLEnforceCollateralTransfer(address collateral, uint256 amount, address from, address receiver) {
    env e;
    if (collateral == ETokenA) {
        ETokenA.transferFromInternalHarnessed(e, from, receiver, amount);
    } else if (collateral == ETokenB) {
        ETokenB.transferFromInternalHarnessed(e, from, receiver, amount);
    }
}

// Assuming the prices stay the same, a healthy account can never become 
// unhealthy. Here, our assumption that the prices do not change is implicit
// in the fact that the summary for GetQuote is an uninterpreted function --
// the prover will model it as a function so it will always return the same
// value when given the same arguments.
rule accountsStayHealthy_strategy (method f) filtered { f -> 
    // Literal selectors are used to avoid compilation errors when
    // only some of the modules are in the verification scene
    // sig:GovernanceModule.clearLTV(address).selector
    f.selector != 0x8255d029 &&
    // sig:GovernanceModule.setLTV(address,uint16,uint16,uint32).selector
    f.selector != 0x4bca3d5b &&
    // sig:InitializeModule.initialize(address).selector
    f.selector != 0xc4d66de8 &&
    // sig:TokenHarnes.transferFromInternalHarnessed (this is a harness method only)
    f.selector != 0xd3110e86
}{
    env e;
    calldataarg args;
    address account;
    address[] collaterals = evc.getCollaterals(account);
    require collaterals.length <= 2; // loop bound
    require oracleAddress != 0; 
    // not sure the following 4 are really needed
    require account != erc20;
    require account != oracleAddress;
    require account != evc;
    require account != unitOfAccount;
    require evc.areChecksDeferred();

    require LTVConfigAssumptions(e, getLTVConfig(e, ETokenA));
    require LTVConfigAssumptions(e, getLTVConfig(e, ETokenB));
    if (collaterals.length > 0) {
        require collaterals[0] == ETokenA || collaterals[0] == ETokenB;
    }
    if (collaterals.length > 1) {
        require collaterals[1] == ETokenA || collaterals[1] == ETokenB;
    }

    bool healthyBefore = checkLiquidityReturning(e, account, collaterals);
    f(e, args);
    // The only way to call a vault funciton is through EVC's call, batch, 
    // or permit. During all of these status checks are deferred and at the end
    // these call restoreExecutionContext which triggers the deferred checks.
    // This excplicit call to checkStatusAll is a way to get a setup that
    // approximates the real situation.
    // We proved separately that EVC really does always call checkStatus all
    // at the end of a call/batch.
    // run: https://prover.certora.com/output/65266/2523dd890b324c9cb6c1fcec767e030e/?anonymousKey=5c7f3132f51538a96a5d8d4fb0de61f4ed892ccc
    evc.checkStatusAllExt(e);
    bool healthyAfter = checkLiquidityReturning(e, account, collaterals);
    assert healthyBefore => healthyAfter; 
}