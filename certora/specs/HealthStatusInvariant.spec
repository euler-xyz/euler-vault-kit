import "Base.spec";
import "LoadVaultSummary.spec";
using DummyERC20A as ERC20a;
using DummyETokenA as ETokenA; // Used to assume collaterals are ETokens.
using DummyETokenB as ETokenB; // Allows for possibility of multiple 
                               // addresses for different collaterals.

methods {
    function checkAccountMagicValue() external returns (bytes4) envfree;
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

    // EVC
    function _.requireVaultStatusCheck() external => DISPATCHER(true);
    function _.requireAccountAndVaultStatusCheck(address) external => DISPATCHER(true);

    // Summaries
    function _.safeTransferFrom(address token, address from, address to, uint256 value, address permit2) internal with (env e)=> CVLSafeTransferFrom(e, token, from, to, value) expect void;
    function _.enforceCollateralTransfer(address collateral, uint256 amount,
        address from, address receiver) internal with (env e) => 
        CVLEnforceCollateralTransfer(e, collateral, amount, from, receiver) expect void;
    // We can't handle the low-level call in 
    // EthereumVaultConnector.checkAccountStatusInternal 
    // and so reroute it to RiskManager's status check with this summary.
    function EthereumVaultConnector.checkAccountStatusInternal(address account) internal returns (bool, bytes memory) with (env e) => 
        CVLCheckAccountStatusInternal(e, account);
    function EthereumVaultConnector.checkVaultStatusInternal(address vault) internal returns (bool, bytes memory) with(env e) =>
        CVLCheckVaultStatusInternal(e);
}

// We summarize EthereumVaultConnector.checkAccountStatusInternal
// because we need to direct the low-level call to RiskManager.
// checkAccountStatus and this linking doesn't happen automatically
function CVLCheckAccountStatusInternalBool(env e, address account) returns bool {
    address[] collaterals = evc.getCollaterals(e, account);
    checkAccountStatus@withrevert(e, account, collaterals);
    return !lastReverted;
}

function CVLCheckAccountStatusInternal(env e, address account) returns (bool, bytes) {
    return (CVLCheckAccountStatusInternalBool(e, account), 
        checkAccountMagicValueMemory(e));
}

function CVLCheckVaultStatusInternalBool(env e) returns bool {
    checkVaultStatus@withrevert(e);
    return !lastReverted;
}

function CVLCheckVaultStatusInternal(env e) returns (bool, bytes) {
    return (CVLCheckVaultStatusInternalBool(e),
        checkVaultMagicValueMemory(e));
}

function CVLAreChecksInProgress() returns bool {
    return true;
}

function CVLSafeTransferFrom(env e, address token, address from, address to, uint256 value) {
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
function CVLEnforceCollateralTransfer(env e, address collateral, uint256 amount, address from, address receiver) {
    evc.requireAccountStatusCheck(e, from);
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
    f.selector != 0xc4d66de8
}{
    env e;
    calldataarg args;
    address account;
    address[] collaterals = evc.getCollaterals(e, account);
    require collaterals.length <= 2; // loop bound
    require oracleAddress != 0; 
    // Vault cannot be a user of itself
    // require account != currentContract; // NOTE recently removed this
    // Vault should not be used as a collateral
    require collaterals[0] != currentContract;
    require collaterals[1] != currentContract;
    // Collaterals must be ETokens
    // require collaterals[0] == EToken;
    // require collaterals[1] == EToken;
    // not sure the following 4 are really needed
    require account != erc20;
    require account != oracleAddress;
    require account != evc;
    require account != unitOfAccount;

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
    evc.checkStatusAllExt(e);
    bool healthyAfter = checkLiquidityReturning(e, account, collaterals);
    assert healthyBefore => healthyAfter; 
}

// - prove separately that every call to vault is from evc (except maybe view)
// - prove on EVC: at the end of call/batch/permit we really do always call 
// checkStatusAll --> After looking at the tickets I think we did not prove 
// this already.
