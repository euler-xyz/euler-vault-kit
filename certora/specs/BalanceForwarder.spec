/*
CER-182 / Verify BalanceForwarder

EVK-16 enableBalanceForwarder: 
If balance tracker specified, enableBalanceForwarder enables the balance 
forwarding to the balance tracker for the authenticated account. The balance 
tracker hook should be invoked with current balance of the account.

EVK-17 disableBalanceForwarder 
disables the balance forwarding to the 
balance tracker for the authenticated account. The balance tracker 
hook should be invoked with 0 as the balance of the account.
*/

import "Base.spec";
// using EthereumVaultConnector as evc;

// function actualCaller(env e) returns address {
//     if(e.msg.sender == evc) {
//         address onBehalf;
//         bool unused;
//         onBehalf, unused = evc.getCurrentOnBehalfOfAccount(e, 0);
//         return onBehalf;
//     } else {
//         return e.msg.sender;
//     }
// }


// NOTE: Unused currently
// ghost mapping(uint256 => bool) ghost_balanceForwarderFlag;
// function CVLIsBalanceForwarderEnabled(uint256 userStorage_data) returns bool {
//    return ghost_balanceForwarderFlag[userStorage_data];
// }

//passing:
// https://prover.certora.com/output/65266/e2a397f3bb864a9eaf4eefdfd35529bc?anonymousKey=aa5dace26320fee72d3611b84d337413ac48c2da
rule enableBalanceForwarder {
    address account;
    env e1;
    env e2;
    // require e1.msg.sender != evc;
    // require e1.msg.sender == account;
    require actualCaller(e1) == account;
    enableBalanceForwarder(e1);
    assert balanceForwarderEnabled(e2, account);
}

// passing:
// https://prover.certora.com/output/65266/e2a397f3bb864a9eaf4eefdfd35529bc?anonymousKey=aa5dace26320fee72d3611b84d337413ac48c2da
rule disableBalanceForwarder {
    address account;
    env e1;
    env e2;
    // require e1.msg.sender != evc;
    // require e1.msg.sender == account;
    require actualCaller(e1) == account;
    disableBalanceForwarder(e1);
    assert !balanceForwarderEnabled(e2, account);
}

rule sanity (method f) {
    env e;
    calldataarg args;
    f(e, args);
    satisfy true;
}