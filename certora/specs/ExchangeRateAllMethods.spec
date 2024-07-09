import "Base.spec";
import "LoadVaultSummary.spec";
// using DummyERC20A as ERC20a;
using TokenHarness as EToken; // Used to assume collaterals are EToken^s

methods {
    function checkAccountMagicValue() external returns (bytes4) envfree;
    // healthStatusCheck reverts unless this is true. We assume it's true 
    // approximate the real situation where these checks get triggered
    // by the EVC before which this flag will be set.
    // TODO is this needed ??
    // function EVCHarness.areChecksInProgress() external returns bool => CVLAreChecksInProgress();
    
    // unresolved calls that havoc all contracts
    // TODO consider moving these to base.spec if they do not interfere with
    // ERC4626 or Contest rules. These are from HealthStatusInvariant.spec
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

    // TODO This is copied from HealthStatusInvariant. Refactor into Base.spec
    // if possible.
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

// TODO This is copied from HealthStatusInvariant. Refactor into Base.spec
// if possible.

function CVLSafeTransferFrom(env e, address token, address from, address to, uint256 value) {
    if (token == ERC20a) {
        ERC20a.transferFrom(e, from, to, value);
    } else if (token == EToken) {
        EToken.transferFrom(e, from, to, value);
    }
}
function CVLEnforceCollateralTransfer(env e, address collateral, uint256 amount, address from, address receiver) {
    evc.requireAccountStatusCheck(e, from);
    EToken.transferFromInternalHarnessed(e, from, receiver, amount);
}

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

// This shows that the exchange rate 
rule exchange_rate_monotonic (method f) {
    env e;
    calldataarg args;
    uint256 shares;
    // assume no debt socialization
    require !hasDebtSocialization(e); // note not envfree

    // want to show assetsAfter / shares >= assetsBefore / shares
    // but we can skip the division
    uint256 assetsBefore = convertToAssetsMock(e, shares);
    f(e, args);
    uint256 assetsAfter = convertToAssetsMock(e, shares);

    assert assetsAfter >= assetsBefore;
}
