/*
 * This is a specification file to formally verify BorrowSystem.sol
 * smart contract using the Certora Prover. For more information,
 * visit: https://www.certora.com/
 *
 */


// reference from the spec to additional contracts used in the verification 

import "Base.spec";
import "./GhostPow.spec";

using DummyERC20A as ERC20a; 
using DummyERC20B as ERC20b; 

/*
    Declaration of methods that are used in the rules. envfree indicate that
    the method is not dependent on the environment (msg.value, msg.sender).
    Methods that are not declared here are assumed to be dependent on env.
*/
methods {
    function name() external returns string envfree;
    function symbol() external returns string envfree;
    function decimals() external returns uint8 envfree;
    function asset() external returns address envfree;

    // function totalSupply() external returns uint256 envfree;
    // function balanceOf(address) external returns uint256 envfree; //NOT ENVFREE
    // Not implemented by EVault
    // function nonces(address) external returns uint256 envfree;

    function approve(address,uint256) external returns bool;
    function deposit(uint256,address) external;
    function mint(uint256,address) external;
    function withdraw(uint256,address,address) external;
    function redeem(uint256,address,address) external;

    // function totalAssets() external returns uint256 envfree;
    function userAssets(address) external returns uint256 envfree;
    // function convertToShares(uint256) external returns uint256 envfree;
    // function convertToAssets(uint256) external returns uint256 envfree;
    // function previewDeposit(uint256) external returns uint256 envfree;
    // function previewMint(uint256) external returns uint256 envfree;
    // function previewWithdraw(uint256) external returns uint256 envfree;
    // function previewRedeem(uint256) external returns uint256 envfree;

    // function maxDeposit(address) external returns uint256 envfree;
    // function maxMint(address) external returns uint256 envfree;
    // function maxWithdraw(address) external returns uint256 envfree;
    // function maxRedeem(address) external returns uint256 envfree;

    function permit(address,address,uint256,uint256,uint8,bytes32,bytes32) external;
    function DOMAIN_SEPARATOR() external returns bytes32;

    //// #ERC20 methods
    // These are done in Base
    // function _.balanceOf(address) external  => DISPATCHER(true);
    // function _.transfer(address,uint256) external  => DISPATCHER(true);
    // function _.transferFrom(address,address,uint256) external => DISPATCHER(true);

    // function ERC20a.balanceOf(address) external returns uint256 envfree; // NOT ENVFREE
    function ERC20a.transferFrom(address,address,uint256) external returns bool; // not envfree

    function RPow.rpow(uint256 x, uint256 y, uint256 base) internal returns (uint256, bool) => CVLPow(x, y, base);

    // These are unresolved calls that havoc contract state.
    // Most of these cause these havocs because of a low-level call 
    // operation and are irrelevant for the rules.
    function _.invokeHookTarget(address caller) internal => NONDET;
    // another unresolved call that havocs all contracts
    function _.requireVaultStatusCheck() external => NONDET;
    function _.requireAccountAndVaultStatusCheck(address account) external => NONDET;
    // trySafeTransferFrom cannot be summarized as NONDET (due to return type
    // that includes bytes memory). So it is summarized as 
    // DummyERC20a.transferFrom
    function _.trySafeTransferFrom(address token, address from, address to, uint256 value) internal with (env e) => CVLTrySafeTransferFrom(e, from, to, value) expect (bool, bytes memory);
    // safeTransferFrom can be made NONDET, but is summarized as transferFrom
    // from DummyERC20a anyway.
    function _.safeTransferFrom(address token, address from, address to, uint256 value, address permit2) internal with (env e)=> CVLTrySafeTransferFrom(e, from, to, value) expect (bool, bytes memory);
    function _.tryBalanceTrackerHook(address account, uint256 newAccountBalance, bool forfeitRecentReward) internal => NONDET;

}

// Summarize trySafeTransferFrom as DummyERC20 transferFrom
function CVLTrySafeTransferFrom(env e, address from, address to, uint256 value) returns (bool, bytes) {
    bytes ret; // Ideally bytes("") if there is a way to do this
    return (ERC20a.transferFrom(e, from, to, value), ret);
}

////////////////////////////////////////////////////////////////////////////////
////           #  asset To shares mathematical properties                  /////
////////////////////////////////////////////////////////////////////////////////

rule conversionOfZero {
    env e;
    uint256 convertZeroShares = convertToAssets(e, 0);
    uint256 convertZeroAssets = convertToShares(e, 0);

    assert convertZeroShares == 0,
        "converting zero shares must return zero assets";
    assert convertZeroAssets == 0,
        "converting zero assets must return zero shares";
}

rule convertToAssetsWeakAdditivity() {
    env e;
    uint256 sharesA; uint256 sharesB;
    require sharesA + sharesB < max_uint128
         && convertToAssets(e, sharesA) + convertToAssets(e, sharesB) < to_mathint(max_uint256)
         && convertToAssets(e, require_uint256(sharesA + sharesB)) < max_uint256;
    assert convertToAssets(e, sharesA) + convertToAssets(e, sharesB) <= to_mathint(convertToAssets(e, require_uint256(sharesA + sharesB))),
        "converting sharesA and sharesB to assets then summing them must yield a smaller or equal result to summing them then converting";
}

rule convertToSharesWeakAdditivity() {
    env e;
    uint256 assetsA; uint256 assetsB;
    require assetsA + assetsB < max_uint128
         && convertToAssets(e, assetsA) + convertToAssets(e, assetsB) < to_mathint(max_uint256)
         && convertToAssets(e, require_uint256(assetsA + assetsB)) < max_uint256;
    assert convertToAssets(e, assetsA) + convertToAssets(e, assetsB) <= to_mathint(convertToAssets(e, require_uint256(assetsA + assetsB))),
        "converting assetsA and assetsB to shares then summing them must yield a smaller or equal result to summing them then converting";
}

rule conversionWeakMonotonicity {
    env e;
    uint256 smallerShares; uint256 largerShares;
    uint256 smallerAssets; uint256 largerAssets;

    assert smallerShares < largerShares => convertToAssets(e, smallerShares) <= convertToAssets(e, largerShares),
        "converting more shares must yield equal or greater assets";
    assert smallerAssets < largerAssets => convertToShares(e, smallerAssets) <= convertToShares(e, largerAssets),
        "converting more assets must yield equal or greater shares";
}

rule conversionWeakIntegrity() {
    env e;
    uint256 sharesOrAssets;
    assert convertToShares(e, convertToAssets(e, sharesOrAssets)) <= sharesOrAssets,
        "converting shares to assets then back to shares must return shares less than or equal to the original amount";
    assert convertToAssets(e, convertToShares(e, sharesOrAssets)) <= sharesOrAssets,
        "converting assets to shares then back to assets must return assets less than or equal to the original amount";
}

rule convertToCorrectness(uint256 amount, uint256 shares)
{
    env e;
    assert amount >= convertToAssets(e, convertToShares(e, amount));
    assert shares >= convertToShares(e, convertToAssets(e, shares));
}


////////////////////////////////////////////////////////////////////////////////
////                   #    Unit Test                                      /////
////////////////////////////////////////////////////////////////////////////////

// passing with conf as here:
// https://prover.certora.com/output/65266/3fd23869b2124c45aa47599c521a70e5?anonymousKey=4c63cefe6e66a12fc34d6c9c887c3481b67379f0
rule depositMonotonicity() {

    env e; storage start = lastStorage;

    uint256 smallerAssets; uint256 largerAssets;
    address receiver;
    require currentContract != e.msg.sender && currentContract != receiver; 

    require largerAssets < max_uint256; // amount = max_uint256 deposits the full balance and we get a CEX for that case.

    safeAssumptions(e, e.msg.sender, receiver);

    deposit(e, smallerAssets, receiver);
    uint256 smallerShares = balanceOf(e, receiver) ;

    deposit(e, largerAssets, receiver) at start;
    uint256 largerShares = balanceOf(e, receiver) ;

    assert smallerAssets < largerAssets => smallerShares <= largerShares,
            "when supply tokens outnumber asset tokens, a larger deposit of assets must produce an equal or greater number of shares";
}


rule zeroDepositZeroShares(uint assets, address receiver)
{
    env e;
    
    uint shares = deposit(e,assets, receiver);

    assert shares == 0 <=> assets == 0;
}

////////////////////////////////////////////////////////////////////////////////
////                    #    Valid State                                   /////
////////////////////////////////////////////////////////////////////////////////

invariant assetsMoreThanSupply(env e)
    totalAssets(e) >= totalSupply(e)
    {
        preserved {
            require e.msg.sender != currentContract;
            address any;
            safeAssumptions(e, any , e.msg.sender);
        }
    }

invariant noAssetsIfNoSupply(env e) 
   ( userAssets(currentContract) == 0 => totalSupply(e) == 0 ) &&
    ( totalAssets(e) == 0 => ( totalSupply(e) == 0 ))

    {
        preserved {
        address any;
            safeAssumptions(e, any, e.msg.sender);
        }
    }

invariant noSupplyIfNoAssets(env e)
    noSupplyIfNoAssetsDef(e)     // see defition in "helpers and miscellaneous" section
    {
        preserved {
            safeAssumptions(e, _, e.msg.sender);
        }
    }



ghost mathint sumOfBalances {
    init_state axiom sumOfBalances == 0;
}

hook Sstore currentContract.vaultStorage.users[KEY address addy].data Vault.PackedUserSlot newValue (Vault.PackedUserSlot oldValue)  {
    sumOfBalances = sumOfBalances + newValue - oldValue;
}

hook Sload Vault.PackedUserSlot val currentContract.vaultStorage.users[KEY address addy].data  {
    require sumOfBalances >= to_mathint(val);
}

// hook Sstore balanceOf[KEY address addy] uint256 newValue (uint256 oldValue)  {
//     sumOfBalances = sumOfBalances + newValue - oldValue;
// }
 

// hook Sload uint256 val balanceOf[KEY address addy]  {
//     require sumOfBalances >= to_mathint(val);
// }

invariant totalSupplyIsSumOfBalances(env e)
    to_mathint(totalSupply(e)) == sumOfBalances;



////////////////////////////////////////////////////////////////////////////////
////                    #     State Transition                             /////
////////////////////////////////////////////////////////////////////////////////


rule totalsMonotonicity() {
    method f; env e; calldataarg args;
    require e.msg.sender != currentContract; 
    uint256 totalSupplyBefore = totalSupply(e);
    uint256 totalAssetsBefore = totalAssets(e);
    address receiver;
    safeAssumptions(e, receiver, e.msg.sender);
    callReceiverFunctions(f, e, receiver);

    uint256 totalSupplyAfter = totalSupply(e);
    uint256 totalAssetsAfter = totalAssets(e);
    
    // possibly assert totalSupply and totalAssets must not change in opposite directions
    assert totalSupplyBefore < totalSupplyAfter  <=> totalAssetsBefore < totalAssetsAfter,
        "if totalSupply changes by a larger amount, the corresponding change in totalAssets must remain the same or grow";
    assert totalSupplyAfter == totalSupplyBefore => totalAssetsBefore == totalAssetsAfter,
        "equal size changes to totalSupply must yield equal size changes to totalAssets";
}

rule underlyingCannotChange() {
    address originalAsset = asset();

    method f; env e; calldataarg args;
    f(e, args);

    address newAsset = asset();

    assert originalAsset == newAsset,
        "the underlying asset of a contract must not change";
}

////////////////////////////////////////////////////////////////////////////////
////                    #   High Level                                    /////
////////////////////////////////////////////////////////////////////////////////

//// #  This rules timeout - we will show how to deal with timeouts 
/* rule totalAssetsOfUser(method f, address user ) {
    env e;
    calldataarg args;
    safeAssumptions(e, e.msg.sender, user);
    require user != currentContract;
    mathint before = userAssets(user) + maxWithdraw(user); 

    // need to ignore cases where user is msg.sender but someone else the receiver 
    address receiver; 
    require e.msg.sender != user;
    uint256 assets; uint256 shares;
    callFunctionsWithReceiverAndOwner(e, f, assets, shares, receiver, e.msg.sender);
    mathint after = userAssets(user) + maxWithdraw(user); 
    assert after >= before; 
}
*/

rule dustFavorsTheHouse(uint assetsIn )
{
    env e;
        
    require e.msg.sender != currentContract;
    safeAssumptions(e,e.msg.sender,e.msg.sender);
    uint256 totalSupplyBefore = totalSupply(e);

    uint balanceBefore = ERC20a.balanceOf(e, currentContract);

    require balanceBefore > 0;
    require totalSupplyBefore > 0;
    require assetsIn > 0;
    
    require assetsIn < max_uint256;
    uint shares = deposit(e,assetsIn, e.msg.sender);
    require shares < max_uint256;
    uint assetsOut = redeem(e,shares,e.msg.sender,e.msg.sender);

    uint balanceAfter = ERC20a.balanceOf(e, currentContract);

    assert balanceAfter >= balanceBefore;
}

////////////////////////////////////////////////////////////////////////////////
////                       #   Risk Analysis                           /////////
////////////////////////////////////////////////////////////////////////////////


invariant vaultSolvency(env e)
    totalAssets(e) >= totalSupply(e)  && userAssets(currentContract) >= totalAssets(e)  {
      preserved {
            requireInvariant totalSupplyIsSumOfBalances(e);
            require e.msg.sender != currentContract;
            require currentContract != asset(); 
        }
    }



rule redeemingAllValidity() { 
    env e;
    address owner; 
    uint256 shares; require shares == balanceOf(e, owner);
    
    safeAssumptions(e, _, owner);
    redeem(e, shares, _, owner);
    uint256 ownerBalanceAfter = balanceOf(e, owner);
    assert ownerBalanceAfter == 0;
}


////////////////////////////////////////////////////////////////////////////////
////               # stakeholder properties  (Risk Analysis )         //////////
////////////////////////////////////////////////////////////////////////////////

rule contributingProducesShares(method f)
filtered {
    f -> f.selector == sig:deposit(uint256,address).selector
      || f.selector == sig:mint(uint256,address).selector
}
{
    env e; uint256 assets; uint256 shares;
    address contributor; require contributor == e.msg.sender;
    address receiver;
    require currentContract != contributor
         && currentContract != receiver;

    require previewDeposit(e, assets) + balanceOf(e, receiver) <= max_uint256; // safe assumption because call to _mint will revert if totalSupply += amount overflows
    require shares + balanceOf(e, receiver) <= max_uint256; // same as above

    safeAssumptions(e, contributor, receiver);

    uint256 contributorAssetsBefore = userAssets(contributor);
    uint256 receiverSharesBefore = balanceOf(e, receiver);

    callContributionMethods(e, f, assets, shares, receiver);

    uint256 contributorAssetsAfter = userAssets(contributor);
    uint256 receiverSharesAfter = balanceOf(e, receiver);

    assert contributorAssetsBefore > contributorAssetsAfter <=> receiverSharesBefore < receiverSharesAfter,
        "a contributor's assets must decrease if and only if the receiver's shares increase";
}

rule onlyContributionMethodsReduceAssets(method f) {
    address user; require user != currentContract;
    uint256 userAssetsBefore = userAssets(user);

    env e; calldataarg args;
    safeAssumptions(e, user, _);

    f(e, args);

    uint256 userAssetsAfter = userAssets(user);

    assert userAssetsBefore > userAssetsAfter =>
        (f.selector == sig:deposit(uint256,address).selector ||
         f.selector == sig:mint(uint256,address).selector),
        "a user's assets must not go down except on calls to contribution methods";
}

rule reclaimingProducesAssets(method f)
filtered {
    f -> f.selector == sig:withdraw(uint256,address,address).selector
      || f.selector == sig:redeem(uint256,address,address).selector
}
{
    env e; uint256 assets; uint256 shares;
    address receiver; address owner;
    require currentContract != e.msg.sender
         && currentContract != receiver
         && currentContract != owner;

    safeAssumptions(e, receiver, owner);

    uint256 ownerSharesBefore = balanceOf(e, owner);
    uint256 receiverAssetsBefore = userAssets(receiver);

    callReclaimingMethods(e, f, assets, shares, receiver, owner);

    uint256 ownerSharesAfter = balanceOf(e, owner);
    uint256 receiverAssetsAfter = userAssets(receiver);

    assert ownerSharesBefore > ownerSharesAfter <=> receiverAssetsBefore < receiverAssetsAfter,
        "an owner's shares must decrease if and only if the receiver's assets increase";
}



////////////////////////////////////////////////////////////////////////////////
////                        # helpers and miscellaneous                //////////
////////////////////////////////////////////////////////////////////////////////

definition noSupplyIfNoAssetsDef(env e) returns bool = 
    ( userAssets(currentContract) == 0 => totalSupply(e) == 0 ) &&
    ( totalAssets(e) == 0 => ( totalSupply(e) == 0 ));

// definition noSupplyIfNoAssetsStrongerDef() returns bool =                // fails for ERC4626BalanceOfHarness as explained in the readme
//     ( userAssets(currentContract) == 0 => totalSupply() == 0 ) &&
//     ( totalAssets() == 0 <=> ( totalSupply() == 0 ));


function safeAssumptions(env e, address receiver, address owner) {
    require currentContract != asset(); // Although this is not disallowed, we assume the contract's underlying asset is not the contract itself
    requireInvariant totalSupplyIsSumOfBalances(e);
    requireInvariant vaultSolvency(e);
    requireInvariant noAssetsIfNoSupply(e);
    requireInvariant noSupplyIfNoAssets(e);
    requireInvariant assetsMoreThanSupply(e); 

    //// # Note : we don't want to use singleBalanceBounded and singleBalanceBounded invariants 
    /* requireInvariant sumOfBalancePairsBounded(receiver, owner );
    requireInvariant singleBalanceBounded(receiver);
    requireInvariant singleBalanceBounded(owner);
    */
    ///// # but, it safe to assume that a single balance is less than sum of balances
    require ( (receiver != owner => balanceOf(e, owner) + balanceOf(e, receiver) <= to_mathint(totalSupply(e)))  && 
                balanceOf(e, receiver) <= totalSupply(e) &&
                balanceOf(e, owner) <= totalSupply(e));
}


// A helper function to set the receiver 
function callReceiverFunctions(method f, env e, address receiver) {
    uint256 amount;
    if (f.selector == sig:deposit(uint256,address).selector) {
        deposit(e, amount, receiver);
    } else if (f.selector == sig:mint(uint256,address).selector) {
        mint(e, amount, receiver);
    } else if (f.selector == sig:withdraw(uint256,address,address).selector) {
        address owner;
        withdraw(e, amount, receiver, owner);
    } else if (f.selector == sig:redeem(uint256,address,address).selector) {
        address owner;
        redeem(e, amount, receiver, owner);
    } else {
        calldataarg args;
        f(e, args);
    }
}


function callContributionMethods(env e, method f, uint256 assets, uint256 shares, address receiver) {
    if (f.selector == sig:deposit(uint256,address).selector) {
        deposit(e, assets, receiver);
    }
    if (f.selector == sig:mint(uint256,address).selector) {
        mint(e, shares, receiver);
    }
}

function callReclaimingMethods(env e, method f, uint256 assets, uint256 shares, address receiver, address owner) {
    if (f.selector == sig:withdraw(uint256,address,address).selector) {
        withdraw(e, assets, receiver, owner);
    }
    if (f.selector == sig:redeem(uint256,address,address).selector) {
        redeem(e, shares, receiver, owner);
    }
}

function callFunctionsWithReceiverAndOwner(env e, method f, uint256 assets, uint256 shares, address receiver, address owner) {
    if (f.selector == sig:withdraw(uint256,address,address).selector) {
        withdraw(e, assets, receiver, owner);
    }
    if (f.selector == sig:redeem(uint256,address,address).selector) {
        redeem(e, shares, receiver, owner);
    } 
    if (f.selector == sig:deposit(uint256,address).selector) {
        deposit(e, assets, receiver);
    }
    if (f.selector == sig:mint(uint256,address).selector) {
        mint(e, shares, receiver);
    }
     if (f.selector == sig:transferFrom(address,address,uint256).selector) {
        transferFrom(e, owner, receiver, shares);
    }
    else {
        calldataarg args;
        f(e, args);
    }
}

rule sanity (method f) {
    env e;
    calldataarg args;
    f(e, args);
    assert false;
}
