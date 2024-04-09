/*
CER-132 / EVK-45 convertToAssets 
returns the amount of assets (rounding down)
that the vault would exchange for the amount of shares provided. The function
must make calculations based on the total shares amount, the amount of assets
held by the vault and the amount of liabilities issued. It must be ensured that
the vault implements the function in a manipulation-resistant manner.
*/

/*
CER-133 / EVK-46 convertToShares 
returns the amount of shares (rounding down)
that the vault would exchange for the amount of assets provided. The function
must make calculations based on the total shares amount, the amount of assets
held by the vault and the amount of liabilities issued. It must be ensured that
the vault implements the function in a manipulation-resistant manner.
*/

/*
CER-134 / EVK-47 deposit
If operation enabled, deposit mints vault shares (rounding
down) to receiver by depositing exactly assets of underlying tokens pulled from
the authenticated account.

If balance forwarding enabled for the receiver address, the balance tracker hook
must be called with the new shares balance of receiver.  This operation is
always called through the EVC.  This operation schedules the vault status check.

This operation affects: 
- shares balance of the receiver account 
- total shares balance 
- total balance of the underlying assets held by the vault
*/

/*
CER-135 / EVK-48 mint
If operation enabled, mint mints exactly shares vault shares to receiver by
depositing corresponding amount of underlying tokens (rounding up) pulled from
the authenticated account.  If balance forwarding enabled for the receiver
address, the balance tracker hook must be called with the new shares balance of
receiver.  This operation is always called through the EVC.  This operation
schedules the vault status check.  
This operation affects: 
- shares balance of the receiver account 
- total shares balance 
- total balance of the underlying assets held by the vault
*/

/*
CER-136 / EVK-49 withdraw
If operation enabled, withdraw burns vault shares (rounding up) from owner and
sends exactly assets of underlying tokens to receiver. If the owner account does
not belong to the authenticated account, the amount of shares burned is a
subject to the ERC20 allowance check.
If balance forwarding enabled for the owner address, the balance tracker hook
must be called with the new shares balance of owner.
If asset receiver validation enabled, this operation must protect user from
sending assets to a virtual account.
This operation is always called through the EVC.
This operation schedules the account status check on the owner address.
This operation schedules the vault status check.
This operation affects:
 - shares balance of the owner account
 - total shares balance
 - total balance of the underlying assets held by the vault
*/

/*
CER-137 / EVK-50 redeem
If operation enabled, redeem burns exactly shares vault shares from owner and
sends corresponding amount of underlying tokens (rounding down) to receiver. If
the owner account does not belong to the authenticated account, the amount of
shares burned is a subject to the ERC20 allowance check.
If balance forwarding enabled for the owner address, the balance tracker hook
must be called with the new shares balance of owner.
If asset receiver validation enabled, this operation must protect user from
sending assets to a virtual account.
This operation is always called through the EVC.
This operation schedules the account status check on the owner address.
This operation schedules the vault status check.

This operation affects:
 - shares balance of the owner account
 - total shares balance
 - total balance of the underlying assets held by the vault
*/

/*
CER-138 / EVK-51 skim
If operation enabled, skim mints vault shares (rounding down) to receiver by
assuming that the excess of the underlying tokens, that may occur due to
internal balance tracking, belongs to the receiver.
If balance forwarding enabled for the receiver address, the balance tracker hook
must be called with the new shares balance of receiver.
This operation is always called through the EVC.
This operation schedules the vault status check.
This operation affects:
 - shares balance of the receiver account
 - total shares balance
 - total balance of the underlying assets held by the vault
*/
methods {
    // Track if a check was scheduled
    function EVCClient.EVCRequireStatusChecks(address account) internal => CVLRequireStatusCheck(account);

    // Track if balance forwarder hook is called
    function BalanceUtils.tryBalanceTrackerHook(address account, uint256 newAccountBalance, bool forfeitRecentReward) internal returns (bool) => 
        CVLCalledBalanceForwarder(account, newAccountBalance);

    // TypesLib -- in practice these cause vacuity errors without summaries
    function _.toAssets(uint256 amount) internal =>
        CVLToAssets(amount) expect (uint112);
    function _.toShares(uint256 amount) internal =>
        CVLToShares(amount) expect (uint112);
    function _.toOwed(uint256 amount) internal =>
        CVLToOwed(amount) expect (uint144);

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

function CVLToAssets(uint256 amount) returns uint112 {
    return require_uint112(amount);
}

function CVLToShares(uint256 amount) returns uint112 {
    return require_uint112(amount);
}

function CVLToOwed(uint256 amount) returns uint144 {
    return require_uint144(amount);
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
function CVLCalledBalanceForwarder(address account, uint256 newAccountBalance) returns bool {
    calledForwarder = true;
    return true;
}

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

// NOTE: disabled ops do not cause a revert. They cause the call
// to act like a NOP in callHook (in initOperation). So we could prove
// that the actual call does not happen by writing a "hook" on invokeTarget