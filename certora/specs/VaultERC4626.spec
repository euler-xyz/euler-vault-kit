/*
 * This is a specification file to formally verify BorrowSystem.sol
 * smart contract using the Certora Prover. For more information,
 * visit: https://www.certora.com/
 *
 */


// reference from the spec to additional contracts used in the verification 

import "Base.spec";
import "./GhostPow.spec";
import "./LoadVaultSummary.spec";

using DummyERC20A as ERC20a; 
// using DummyERC20B as ERC20b; 

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

    function approve(address,uint256) external returns bool;
    function deposit(uint256,address) external;
    function mint(uint256,address) external;
    function withdraw(uint256,address,address) external;
    function redeem(uint256,address,address) external;


    function permit(address,address,uint256,uint256,uint8,bytes32,bytes32) external;
    function DOMAIN_SEPARATOR() external returns bytes32;

    //// #ERC20 methods

    function ERC20a.transferFrom(address,address,uint256) external returns bool; // not envfree


    function RPow.rpow(uint256 x, uint256 y, uint256 base) internal returns (uint256, bool) => CVLPow(x, y, base);

    // See comment near CVLgetCurrentOnBehalfOfAccount definition.
    function _.getCurrentOnBehalfOfAccount(address controller) external => CVLgetCurrentOnBehalfOfAccount(controller) expect (address, bool);

    // These are unresolved calls that havoc contract state.
    // Most of these cause these havocs because of a low-level call 
    // operation and are irrelevant for the rules.
    function _.invokeHookTarget(address caller) internal => NONDET;
    // another unresolved call that havocs all contracts
    function _.requireVaultStatusCheck() external => NONDET;
    function _.requireAccountAndVaultStatusCheck(address account) external => NONDET;
    function EthereumVaultConnector.getAccountOwner(address account) external returns address => CVLGetAccountOwner(account);
    // trySafeTransferFrom cannot be summarized as NONDET (due to return type
    // that includes bytes memory). So it is summarized as 
    // DummyERC20a.transferFrom
    function _.trySafeTransferFrom(address token, address from, address to, uint256 value) internal with (env e) => CVLTrySafeTransferFrom(e, token,from, to, value) expect (bool, bytes memory);
    // safeTransferFrom is summarized as transferFrom
    // from DummyERC20a to avoid dealing with the low-level `call`
    function _.safeTransferFrom(address token, address from, address to, uint256 value, address permit2) internal => CVLSafeTransferFrom(token, from, to, value) expect void;
    function _.tryBalanceTrackerHook(address account, uint256 newAccountBalance, bool forfeitRecentReward) internal => NONDET;
    function _.balanceTrackerHook(address account, uint256 newAccountBalance, bool forfeitRecentReward) external => NONDET;
    // This is NONDET to help avoid timeouts. It should be safe
    // to NONDET since it is a private view function.
    function _.resolve(Vault.AmountCap self) internal => CONSTANT; 

}

// This is not in the scene for this config, so we just want it to be
// an uninterpreted function rather than NONDET so that
// we get the same value when this is called for different parts
ghost address GhostOnBehalfOfAccount {
    axiom GhostOnBehalfOfAccount != currentContract;
    axiom GhostOnBehalfOfAccount != 0;
} 
ghost CVLgetCurrentOnBehalfOfAccountBool(address) returns bool;
function CVLgetCurrentOnBehalfOfAccount(address addr) returns (address, bool) {
    return (GhostOnBehalfOfAccount,
        CVLgetCurrentOnBehalfOfAccountBool(addr));
}
persistent ghost CVLGetAccountOwner(address) returns address;

// Summarize trySafeTransferFrom as DummyERC20 transferFrom
function CVLSafeTransferFrom(address token, address from, address to, uint256 value) {
    env e;
    ERC20a.transferFrom(e, from, to, value);
}

function CVLTrySafeTransferFrom(env e, address token, address from, address to, uint256 value) returns (bool, bytes) {
    bytes ret;
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

// passing
// run: https://prover.certora.com/output/65266/e7e04c3291f843ba9fe0b81ea9a1f949/?anonymousKey=1828bc78fcb1ed87cf33d17878823becfad2ca23
rule convertToAssetsWeakAdditivity() {
    env e;
    uint256 sharesA; uint256 sharesB;
    require sharesA + sharesB < max_uint128
         && convertToAssets(e, sharesA) + convertToAssets(e, sharesB) < to_mathint(max_uint256)
         && convertToAssets(e, require_uint256(sharesA + sharesB)) < max_uint256;
    assert convertToAssets(e, sharesA) + convertToAssets(e, sharesB) <= to_mathint(convertToAssets(e, require_uint256(sharesA + sharesB))),
        "converting sharesA and sharesB to assets then summing them must yield a smaller or equal result to summing them then converting";
}

// passing
// run: https://prover.certora.com/output/65266/3bd31b8e066543fc8097a0ffce93ee41/?anonymousKey=5b8d2876fecf3d8af7a550e203faa4d58bbedf5c
rule convertToSharesWeakAdditivity() {
    env e;
    uint256 assetsA; uint256 assetsB;
    require assetsA + assetsB < max_uint128
         && convertToAssets(e, assetsA) + convertToAssets(e, assetsB) < to_mathint(max_uint256)
         && convertToAssets(e, require_uint256(assetsA + assetsB)) < max_uint256;
    assert convertToAssets(e, assetsA) + convertToAssets(e, assetsB) <= to_mathint(convertToAssets(e, require_uint256(assetsA + assetsB))),
        "converting assetsA and assetsB to shares then summing them must yield a smaller or equal result to summing them then converting";
}

// passing
// run: https://prover.certora.com/output/40748/614a8496d9784ba5873b9be6636d9f3e/?anonymousKey=a0622d3850471ef5d170484cbe7c5fec18646d61
rule conversionWeakMonotonicity {
    env e;
    uint256 smallerShares; uint256 largerShares;
    uint256 smallerAssets; uint256 largerAssets;

    assert smallerShares < largerShares => convertToAssets(e, smallerShares) <= convertToAssets(e, largerShares),
        "converting more shares must yield equal or greater assets";
    assert smallerAssets < largerAssets => convertToShares(e, smallerAssets) <= convertToShares(e, largerAssets),
        "converting more assets must yield equal or greater shares";
}

// passing
// run: https://prover.certora.com/output/65266/302371dbde0246a28808b078c2164615/?anonymousKey=9759cd932017c8a142c5e1c4d6fa312b4ef94ae3
rule conversionWeakIntegrity() {
    env e;
    uint256 sharesOrAssets;
    assert convertToShares(e, convertToAssets(e, sharesOrAssets)) <= sharesOrAssets,
        "converting shares to assets then back to shares must return shares less than or equal to the original amount";
    assert convertToAssets(e, convertToShares(e, sharesOrAssets)) <= sharesOrAssets,
        "converting assets to shares then back to assets must return assets less than or equal to the original amount";
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

//run: https://prover.certora.com/output/65266/8d021eab19f945cd86a3ef904b0aa6dc/?anonymousKey=bd4cc32f9af86278b0eceaae2316ea3e385c1cdf
rule zeroDepositZeroShares(uint assets, address receiver)
{
    env e;
    
    uint shares = deposit(e,assets, receiver);
    // In this Vault, max_uint256 as an argument will transfer all assets
    // to the vault. This precondition rules out the case where
    // the depositor calls deposit with a balance of 0 in the underlying
    // asset and gives max_uint256 as the shares.
    require assets < max_uint256;

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
        }
    }

invariant noAssetsIfNoSupply(env e) 
    ( totalAssets(e) == 0 => ( totalSupply(e) == 0 ))

    {
        preserved {
            address any;
            safeAssumptions(e, any, actualCaller(e));
            safeAssumptions(e, any, actualCallerCheckController(e));
        }
    }

invariant noSupplyIfNoAssets(env e)
    noSupplyIfNoAssetsDef(e)     // see definition in "helpers and miscellaneous" section
    {
        preserved {
            safeAssumptions(e, _, e.msg.sender);
        }
    }



persistent ghost mathint sumOfBalances {
    init_state axiom sumOfBalances == 0;
}

hook Sstore currentContract.vaultStorage.users[KEY address addy].data Vault.PackedUserSlot newValue (Vault.PackedUserSlot oldValue)  {
    sumOfBalances = sumOfBalances + newValue - oldValue;
}

hook Sload Vault.PackedUserSlot val currentContract.vaultStorage.users[KEY address addy].data  {
    require sumOfBalances >= to_mathint(val);
}

// passing: https://prover.certora.com/output/65266/de3636d287d2473294463c07263fc11e/?anonymousKey=ac8f74e6c5c1298f0954a21fafd41cccf32b9ffb
invariant totalSupplyIsSumOfBalances(env e)
    // to_mathint(totalSupply(e)) == sumOfBalances + accumulatedFees(e);
    to_mathint(totalSupply(e)) == sumOfBalances;



////////////////////////////////////////////////////////////////////////////////
////                    #     State Transition                             /////
////////////////////////////////////////////////////////////////////////////////

//run: https://prover.certora.com/output/65266/3ef25c98a7e34422bcf177d853662b5f/?anonymousKey=ca43e967a607a404f34b39c70f6517e90dac0902
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

// passing
// run: https://prover.certora.com/output/65266/a19010e64bb8424aa513be8b75d15cdf/?anonymousKey=87c73cdf676930336269396f2dbb3cac3d78b997
rule dustFavorsTheHouse(uint assetsIn )
{
    env e;
        
    require e.msg.sender != currentContract;
    safeAssumptions(e,e.msg.sender,e.msg.sender);
    uint256 totalSupplyBefore = totalSupply(e);

    uint balanceBefore = userAssets(e, currentContract);

    uint shares = deposit(e,assetsIn, e.msg.sender);
    uint assetsOut = redeem(e,shares,e.msg.sender,e.msg.sender);

    uint balanceAfter = userAssets(e, currentContract);
    assert balanceAfter >= balanceBefore;
}

// passing:
// run: https://prover.certora.com/output/65266/16c756cc79054db2822d8d77cd7d157b?anonymousKey=ab0d69f0506e327db1fd9180bf8b0259a7bf1f7b
rule dustFavorsTheHouseAssets(uint assetsIn )
{
    env e;
        
    require e.msg.sender != currentContract;
    safeAssumptions(e,e.msg.sender,e.msg.sender);
    uint256 totalAssetsBefore = totalAssets(e);

    uint shares = deposit(e,assetsIn, e.msg.sender);
    uint assetsOut = redeem(e,shares,e.msg.sender,e.msg.sender);
    uint256 totalAssetsAfter = totalAssets(e);

    assert totalAssetsAfter >= totalAssetsBefore;
}

////////////////////////////////////////////////////////////////////////////////
////                       #   Risk Analysis                           /////////
////////////////////////////////////////////////////////////////////////////////


invariant vaultSolvency(env e)
    totalAssets(e) >= totalSupply(e)  && userAssets(e, currentContract) >= require_uint256(cache_cash(e))  {
      preserved {
            requireInvariant totalSupplyIsSumOfBalances(e);
            require e.msg.sender != currentContract;
            require actualCaller(e) != currentContract;
            require actualCallerCheckController(e) != currentContract;
            require currentContract != asset(); 
        }
    }

rule vaultSolvencyWithdraw_totals {
    env e;
    requireInvariant totalSupplyIsSumOfBalances(e);
    require e.msg.sender != currentContract;
    require actualCaller(e) != currentContract;
    require currentContract != asset(); 
    uint256 amount;
    address receiver;
    address owner;
    require totalAssets(e) >= totalSupply(e);  
    require userAssets(e, currentContract) >= require_uint256(cache_cash(e));
    withdraw(e, amount, receiver, owner);
    assert totalAssets(e) >= totalSupply(e); 
}

rule withdraw_amount_max {
    env e;
    require e.msg.sender != currentContract;
    require actualCaller(e) != currentContract;
    require currentContract != asset(); 
    uint256 amount;
    address receiver;
    address owner;
    withdraw(e, amount, receiver, owner);
    assert amount <= max_uint112 || amount == max_uint256;
}

rule vaultSolvencyWithdraw_underlying {
    env e;
    requireInvariant totalSupplyIsSumOfBalances(e);
    require e.msg.sender != currentContract;
    require actualCaller(e) != currentContract;
    require currentContract != asset(); 
    uint256 amount;
    address receiver;
    address owner;
    require userAssets(e, currentContract) >= require_uint256(cache_cash(e));
    withdraw(e, amount, receiver, owner);
    assert userAssets(e, currentContract) >= require_uint256(cache_cash(e));
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

// passing. run: https://prover.certora.com/output/65266/48a3074474f1475baf13fe3cb9602567/?anonymousKey=9111d29e8d8ed721825b12f083128af396e5e814
rule contributingProducesShares(method f)
filtered {
    f -> f.selector == sig:deposit(uint256,address).selector
      || f.selector == sig:mint(uint256,address).selector
}
{
    env e; uint256 assets; uint256 shares;
    address contributor;

    // need to minimize these
    require actualCaller(e) == contributor;
    require contributor == GhostOnBehalfOfAccount;
    require actualCallerCheckController(e) == contributor;

    address receiver;
    require currentContract != contributor
         && currentContract != receiver;

    require previewDeposit(e, assets) + balanceOf(e, receiver) <= max_uint256; // safe assumption because call to _mint will revert if totalSupply += amount overflows
    require shares + balanceOf(e, receiver) <= max_uint256; // same as above

    safeAssumptions(e, contributor, receiver);

    uint256 contributorAssetsBefore = userAssets(e, contributor);
    uint256 receiverSharesBefore = balanceOf(e, receiver);

    callContributionMethods(e, f, assets, shares, receiver);

    uint256 contributorAssetsAfter = userAssets(e, contributor);
    uint256 receiverSharesAfter = balanceOf(e, receiver);

    assert contributorAssetsBefore > contributorAssetsAfter <=> receiverSharesBefore < receiverSharesAfter,
        "a contributor's assets must decrease if and only if the receiver's shares increase";
}

// passing
// run: https://prover.certora.com/output/65266/28a47dd30c6747cbbc4495de59e5f965?anonymousKey=2e86f97ff0030d5489503334c71961bb5978f331
rule onlyContributionMethodsReduceAssets(method f) {
    env e; calldataarg args;
    address user; require user != currentContract;
    uint256 userAssetsBefore = userAssets(e, user);

    safeAssumptions(e, user, _);

    f(e, args);

    uint256 userAssetsAfter = userAssets(e, user);

    assert userAssetsBefore > userAssetsAfter =>
        (f.selector == sig:deposit(uint256,address).selector ||
         f.selector == sig:mint(uint256,address).selector),
        "a user's assets must not go down except on calls to contribution methods";
}

// passing
// run: https://prover.certora.com/output/65266/8ead2419e398420286adb1f636a35249/?anonymousKey=f135ef5ad92b9e187a5df3ebce5499f693eae015
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
    uint256 receiverAssetsBefore = userAssets(e, receiver);

    callReclaimingMethods(e, f, assets, shares, receiver, owner);

    uint256 ownerSharesAfter = balanceOf(e, owner);
    uint256 receiverAssetsAfter = userAssets(e, receiver);

    assert ownerSharesBefore > ownerSharesAfter <=> receiverAssetsBefore < receiverAssetsAfter,
        "an owner's shares must decrease if and only if the receiver's assets increase";
}



////////////////////////////////////////////////////////////////////////////////
////                        # helpers and miscellaneous                //////////
////////////////////////////////////////////////////////////////////////////////

definition noSupplyIfNoAssetsDef(env e) returns bool = 
    ( totalAssets(e) == 0 => ( totalSupply(e) == 0 ));


function safeAssumptions(env e, address receiver, address owner) {
    require currentContract != asset(); // Although this is not disallowed, we assume the contract's underlying asset is not the contract itself
    requireInvariant totalSupplyIsSumOfBalances(e);
    requireInvariant vaultSolvency(e);
    requireInvariant noAssetsIfNoSupply(e);
    requireInvariant noSupplyIfNoAssets(e);
    requireInvariant assetsMoreThanSupply(e); 

    //// # Note : we don't want to use singleBalanceBounded and singleBalanceBounded invariants 
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