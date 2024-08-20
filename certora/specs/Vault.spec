// all passing
// run: https://prover.certora.com/output/65266/4e6a6aeb5af9454e87e8245498b0207d?anonymousKey=e924e53a6ff7a84beab51de18671463a166885b4
methods {
    // Track if a check was scheduled
    function EVCClient.EVCRequireStatusChecks(address account) internal => CVLRequireStatusCheck(account);

    // Track if balance forwarder hook is called
    function _.balanceTrackerHook(address account, uint256 newAccountBalance, bool forfeitRecentReward) external => 
        CVLCalledBalanceForwarder(account, newAccountBalance) expect void;

    // Workaround for lack of ability to summarize metadata
    function Cache.loadVault() internal returns (Vault.VaultCache memory) => CVLLoadVault();
    function Cache.updateVault() internal returns (Vault.VaultCache memory) => CVLLoadVault();

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

persistent ghost bool calledStatusCheck;
function CVLRequireStatusCheck(address account) {
    calledStatusCheck = true;
}

function CVLLoadVault() returns Vault.VaultCache {
    Vault.VaultCache vaultCache;
    require vaultCache.oracle != 0;
    return vaultCache;
}

definition isHookOperation(method f) returns bool =
    f.selector == sig:Vault.deposit(uint256, address).selector ||
    f.selector == sig:Vault.mint(uint256, address).selector ||
    f.selector == sig:Vault.withdraw(uint256, address, address).selector ||
    f.selector == sig:Vault.redeem(uint256, address, address).selector ||
    f.selector == sig:Vault.skim(uint256, address).selector;

rule status_checks_scheduled (method f) filtered { f ->
    isHookOperation(f)
}{
    env e;
    calldataarg args;
    require calledStatusCheck == false;
    f(e, args);
    assert calledStatusCheck;
}

persistent ghost bool calledForwarder;
function CVLCalledBalanceForwarder(address account, uint256 newAccountBalance) {
    calledForwarder = true;
}

// If balance forwarding is enabled and OP is not disabled,
// the Vault methods will call the balance forwarding hook
// NOTE: these rules are not parametric because they need
// to constrain to the case that the result is nonzero.
rule balance_forwarding_called_deposit {
    env e;
    uint256 amount;
    address receiver;
    uint256 result;

    uint256 balance;
    bool forwarderEnabled;

    require !calledForwarder;

    // if balance forwarding is enabled and OP is not disabled
    balance, forwarderEnabled = getBalanceAndForwarderExt(e, receiver);

    require forwarderEnabled;
    require !isDepositDisabled(e);
    result = deposit(e, amount, receiver);

    // // balance forwarding hook is called
    assert result !=0 => calledForwarder;
}

// If balance forwarding is enabled and OP is not disabled,
// mint will call the balance forwarding hook
rule balance_forwarding_called_mint {
    env e;
    uint256 amount;
    address receiver;
    uint256 result;

    uint256 balance;
    bool forwarderEnabled;

    require !calledForwarder;

    // if balance forwarding is enabled and OP is not disabled
    balance, forwarderEnabled = getBalanceAndForwarderExt(e, receiver);
    require forwarderEnabled;
    require !isMintDisabled(e);
    result = mint(e, amount, receiver);

    // balance forwarding hook is called
    assert result != 0 => calledForwarder;
}

rule balance_forwarding_called_withdraw {
    env e;
    uint256 amount;
    address receiver;
    address owner;
    uint256 result;

    uint256 balance;
    bool forwarderEnabled;

    require !calledForwarder;

    // if balance forwarding is enabled and OP is not disabled
    balance, forwarderEnabled = getBalanceAndForwarderExt(e, owner);
    require forwarderEnabled;
    require !isWithdrawDisabled(e);
    result = withdraw(e, amount, receiver, owner);

    // balance forwarding hook is called
    assert result !=0 => calledForwarder;
}

rule balance_forwarding_called_redeem {
    env e;
    uint256 amount;
    address receiver;
    address owner;
    uint256 result;

    uint256 balance;
    bool forwarderEnabled;

    require !calledForwarder;

    // if balance forwarding is enabled and OP is not disabled
    balance, forwarderEnabled = getBalanceAndForwarderExt(e, owner);
    require forwarderEnabled;
    require !isRedeemDisabled(e);
    result = redeem(e, amount, receiver, owner);

    // balance forwarding hook is called
    assert result != 0 => calledForwarder;
}

rule balance_forwarding_called_skim {
    env e;
    uint256 amount;
    address receiver;
    uint256 result;

    uint256 balance;
    bool forwarderEnabled;

    require !calledForwarder;

    // if balance forwarding is enabled and OP is not disabled
    balance, forwarderEnabled = getBalanceAndForwarderExt(e, receiver);
    require forwarderEnabled;
    require !isSkimDisabled(e);
    result = skim(e, amount, receiver);

    // balance forwarding hook is called
    assert result != 0 => calledForwarder;
}