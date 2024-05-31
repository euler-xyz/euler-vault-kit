import "Base.spec";
import "LoadVaultSummary.spec";
using DummyERC20A as ERC20a;

methods {
    function checkAccountMagicValue() external returns (bytes4) envfree;
    // healthStatusCheck reverts unless this is true. We assume it's true 
    // approximate the real situation where these checks get triggered
    // by the EVC before which this flag will be set.
    function EVCHarness.areChecksInProgress() external returns bool => CVLAreChecksInProgress();
    // unresolved calls that havoc all contracts
    function _.invokeHookTarget(address caller) internal => NONDET;
    function _.tryBalanceTrackerHook(address account, uint256 newAccountBalance, bool forfeitRecentReward) internal => NONDET;
    function _.balanceTrackerHook(address account, uint256 newAccountBalance, bool forfeitRecentReward) external => NONDET;
    function _.requireVaultStatusCheck() external => DISPATCHER(true);
    // function _.requireAccountAndVaultStatusCheck(address account) external => NONDET;
    function _.requireAccountAndVaultStatusCheck(address) external => DISPATCHER(true);
    function _.emitTransfer(address from, address to, uint256 value) external => NONDET;
    function EVCHarness.disableController(address account) external => NONDET;
    // function _.computeInterestRate(BaseHarness.VaultCache memory vaultCache) internal => NONDET;
    function _.computeInterestRate(address vault, uint256 cash, uint256 borrows) external => NONDET;
    function _.onFlashLoan(bytes data) external => NONDET;
    function _.safeTransferFrom(address token, address from, address to, uint256 value, address permit2) internal with (env e)=> CVLTrySafeTransferFrom(e, from, to, value) expect (bool, bytes memory);
    // We can't handle the low-level call in 
    // EthereumVaultConnector.checkAccountStatusInternal 
    // and so reroute it to RiskManager's status check with this summary.
    function EthereumVaultConnector.checkAccountStatusInternal(address account) internal returns (bool, bytes memory) with (env e) => 
        CVLCheckAccountStatusInternal(e, account);
    function EthereumVaultConnector.checkVaultStatusInternal(address vault) internal returns (bool, bytes memory) with(env e) =>
        CVLCheckVaultStatusInternal(e);
    // NONDET checkVaultStatus because I think it is not related to enforcing
    // this and it is expensive for the tool.
    function currentContract.checkVaultStatus() external returns (bytes4) => NONDET;
}

// We summarize EthereumVaultConnector.checkAccountStatusInternal
// because we need 
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

// Summarize trySafeTransferFrom as DummyERC20 transferFrom
function CVLTrySafeTransferFrom(env e, address from, address to, uint256 value) returns (bool, bytes) {
    bytes ret; // Ideally bytes("") if there is a way to do this
    return (ERC20a.transferFrom(e, from, to, value), ret);
}


// Assuming the prices stay the same, a healthy account can never become 
// unhealthy. Here, our assumption that the prices do not change is implicit
// in the fact that the summary for GetQuote is an uninterpreted function --
// the prover will model it as a function so it will always return the same
// value when given the same arguments.
rule accountsStayHealthy (method f) {
    env e;
    calldataarg args;
    address account;
    address[] collaterals = evc.getCollaterals(e, account);
    require collaterals.length == 2; // loop bound
    require oracleAddress != 0;

    // Otherwise this can cause an unintersting divide by zero in OwedLib.getCurrentOwed (on the mulDiv)
    require getUserInterestAccumulator(e, account) > 0;
    require storage_interestAccumulator(e) == getUserInterestAccumulator(e, account);
    // otherwise this can cause an uninteresting overflow in mulDiv
    require storage_interestAccumulator(e) < max_uint112;

    checkAccountStatus@withrevert(e, account, collaterals);
    bool healthyBefore = !lastReverted;
    f(e, args);
    // The only way to call a vault funciton is through EVC's call, batch, 
    // or permit. During all of these status checks are deferred and at the end
    // these call restoreExecutionContext which triggers the deferred checks.
    evc.checkStatusAllExt(e);
    checkAccountStatus@withrevert(e, account, collaterals);
    bool healthyAfter= !lastReverted;
    assert healthyBefore => healthyAfter;
}

// - prove separately that every call to vault is from evc (except maybe view)
// - prove on EVC: at the end of call/batch/permit we really do always call checkStatusAll
