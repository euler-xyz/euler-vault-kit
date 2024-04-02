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
    function _.requireVaultStatusCheck() external => NONDET;
    function _.requireAccountAndVaultStatusCheck(address account) external => NONDET; 
    function _.calculateDTokenAddress() internal => NONDET;
    function EVCClient.EVCRequireStatusChecks(address account) internal => NONDET;
}

rule sanity (method f) {
    env e;
    calldataarg args;
    f(e, args);
    satisfy true;
}