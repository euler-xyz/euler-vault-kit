/*
 * This is a specification file to formally verify BorrowSystem.sol
 * smart contract using the Certora Prover. For more information,
 * visit: https://www.certora.com/
 *
 */


// reference from the spec to additional contracts used in the verification 

// import "Base.spec";
// import "./GhostPow.spec";
// import "./LoadVaultSummary.spec";

using DummyERC20A as ERC20a; 
using DummyERC20B as ERC20b;
using DummyERC20A as erc20;
using EthereumVaultConnector as evc;

/*
    Declaration of methods that are used in the rules. envfree indicate that
    the method is not dependent on the environment (msg.value, msg.sender).
    Methods that are not declared here are assumed to be dependent on env.
*/
methods {
    //------------------------------------------------------------------------
    // From Base.spec
    //------------------------------------------------------------------------
    function getLTVConfig(address collateral) external returns (BaseHarness.LTVConfig memory) envfree;
    function getCollateralsExt(address account) external returns (address[] memory) envfree;
    function isCollateralEnabledExt(address account, address market) external returns (bool) envfree;
    function vaultIsOnlyController(address account) external returns (bool) envfree;
    function isAccountStatusCheckDeferredExt(address account) external returns (bool) envfree;
    function vaultIsController(address account) external returns (bool) envfree;

    // Inline assembly here gives the tool problems
	function _.calculateDTokenAddress() internal => NONDET;

    // IPriceOracle
    function _.getQuote(uint256 amount, address base, address quote) external => CVLGetQuote(amount, base, quote) expect (uint256);
    function _.getQuotes(uint256 amount, address base, address quote) external => CVLGetQuotes(amount, base, quote) expect (uint256, uint256);

    // ProxyUtils    
    function ProxyUtils.metadata() internal returns (address, address, address)=> CVLProxyMetadata();

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

    //------------------------------------------------------------------------
    // LoadVaultSummary
    //------------------------------------------------------------------------
    function Cache.initVaultCache(BaseHarness.VaultCache memory vaultCache) internal returns (bool) with (env e) => CVLInitVaultCache(e, vaultCache);

    function storage_lastInterestAccumulatorUpdate() external returns (uint48) envfree;
    function storage_cash() external returns (BaseHarness.Assets) envfree;
    function storage_supplyCap() external returns (uint256) envfree;
    function storage_borrowCap() external returns (uint256) envfree;
    function storage_hookedOps() external returns (BaseHarness.Flags) envfree;
    function storage_snapshotInitialized() external returns (bool) envfree;
    function storage_totalShares() external returns (BaseHarness.Shares) envfree;
    function storage_totalBorrows() external returns (BaseHarness.Owed) envfree;
    function storage_accumulatedFees() external returns (BaseHarness.Shares) envfree;
    function storage_interestAccumulator() external returns (uint256) envfree;
    function storage_configFlags() external returns (BaseHarness.Flags) envfree;

    //------------------------------------------------------------------------
    // From ERC4626 spec
    //------------------------------------------------------------------------
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
    // function userAssets(address) external returns uint256 envfree;
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


    // function RPow.rpow(uint256 x, uint256 y, uint256 base) internal returns (uint256, bool) => CVLPow(x, y, base);

    // See comment near CVLgetCurrentOnBehalfOfAccount definition.
    function _.getCurrentOnBehalfOfAccount(address controller) external => CVLgetCurrentOnBehalfOfAccount(controller) expect (address, bool);

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
    // safeTransferFrom is summarized as transferFrom
    // from DummyERC20a to avoid dealing with the low-level `call`
    function _.safeTransferFrom(address token, address from, address to, uint256 value, address permit2) internal with (env e)=> CVLTrySafeTransferFrom(e, from, to, value) expect (bool, bytes memory);
    function _.tryBalanceTrackerHook(address account, uint256 newAccountBalance, bool forfeitRecentReward) internal => NONDET;
    function _.balanceTrackerHook(address account, uint256 newAccountBalance, bool forfeitRecentReward) external => NONDET;

}
ghost CVLGetQuote(uint256, address, address) returns uint256 {
    // The total value returned by the oracle is assumed < 2**230-1.
    // There will be overflows without an upper bound on this number.
    // (For example, it must be less than 2**242-1 to avoid overflow in
    // LTVConfig.mul)
    axiom forall uint256 x. forall address y. forall address z. 
        CVLGetQuote(x, y, z) < 1725436586697640946858688965569256363112777243042596638790631055949823;
}

function CVLGetQuotes(uint256 amount, address base, address quote) returns (uint256, uint256) {
    return (
        CVLGetQuote(amount, base, quote),
        CVLGetQuote(amount, base, quote)
    );
}

ghost address oracleAddress;
ghost address unitOfAccount;
function CVLProxyMetadata() returns (address, address, address) {
    return (erc20, oracleAddress, unitOfAccount);
}

function LTVConfigAssumptions(env e, BaseHarness.LTVConfig ltvConfig) returns bool {
    bool targetLTVLessOne = ltvConfig.targetLTV < 10000;
    bool originalLTVLessOne = ltvConfig.originalLTV < 10000;
    bool target_less_original = ltvConfig.targetLTV < ltvConfig.originalLTV;
    mathint timeRemaining = ltvConfig.targetTimestamp - e.block.timestamp;
    return targetLTVLessOne &&
        originalLTVLessOne &&
        target_less_original && 
        require_uint32(timeRemaining) < ltvConfig.rampDuration;
}

function actualCaller(env e) returns address {
    if(e.msg.sender == evc) {
        address onBehalf;
        bool unused;
        onBehalf, unused = evc.getCurrentOnBehalfOfAccount(e, 0);
        return onBehalf;
    } else {
        return e.msg.sender;
    }
}

function actualCallerCheckController(env e) returns address {
    if(e.msg.sender == evc) {
        address onBehalf;
        bool unused;
        // Similar to EVCAuthenticateDeferred when checkController is true.
        onBehalf, unused = evc.getCurrentOnBehalfOfAccount(e, currentContract);
        return onBehalf;
    } else {
        return e.msg.sender;
    }
}
//-----------------------------------------------------------------------------'
// From LoadVaultSummary.spec
//-----------------------------------------------------------------------------'
persistent ghost newInterestBorrows(uint256) returns uint256;
// this should be increasing over time, but I think we do
// not even need to model this. It can just be an uninterp function
// because in the ERC4626 spec there are no rules with multiple env.

function CVLInitVaultCache(env e, BaseHarness.VaultCache vaultCache) returns bool {
    uint48 lastUpdate = storage_lastInterestAccumulatorUpdate();
    BaseHarness.Owed oldTotalBorrows = storage_totalBorrows(); 
    BaseHarness.Shares oldTotalShares = storage_totalShares();
    require vaultCache.cash == storage_cash();
    uint48 timestamp48 = require_uint48(e.block.timestamp);
    bool updated = timestamp48 != lastUpdate;
    if(updated) {
        require vaultCache.lastInterestAccumulatorUpdate == timestamp48;

        // totalBorrows
        uint256 interestBorrows = newInterestBorrows(e.block.timestamp);
        require vaultCache.totalBorrows == require_uint144(oldTotalBorrows + interestBorrows);

        // totalShares
        mathint newTotalAssets = vaultCache.cash + vaultCache.totalBorrows;
        // underapproximate interesteFee as 1 (1e4 in impl)
        // feeAssets is a separate variable just for readability.
        uint256 feeAssets = interestBorrows;
        require feeAssets < require_uint256(newTotalAssets);
        if (feeAssets > 0) {
            require vaultCache.totalShares == require_uint112(oldTotalShares * newTotalAssets / (newTotalAssets - feeAssets));
        } else {
            require vaultCache.totalShares == oldTotalShares;
        }

        // accumulatedFees
        mathint accFees = storage_accumulatedFees() +
            vaultCache.totalShares - oldTotalShares;
        require vaultCache.accumulatedFees == require_uint112(accFees);

        // interestAccumulator
        require vaultCache.interestAccumulator >= storage_interestAccumulator();

    } else {
        require vaultCache.lastInterestAccumulatorUpdate == lastUpdate;
        require vaultCache.totalBorrows == oldTotalBorrows;
        require vaultCache.totalShares == oldTotalShares;
        require vaultCache.accumulatedFees == storage_accumulatedFees();
        require vaultCache.interestAccumulator == storage_interestAccumulator();
    }

    // unmodified values
    // require vaultCache.supplyCap == storage_supplyCap();
    // require vaultCache.borrowCap == storage_borrowCap();
    require vaultCache.hookedOps == storage_hookedOps();
    require vaultCache.configFlags == storage_configFlags();
    // require vaultCache.snapshotInitialized == storage_snapshotInitialized();

    // either of these cause a vacuity failure ...
    // require vaultCache.asset == erc20;
    require vaultCache.asset == asset();
    require vaultCache.oracle == oracleAddress;
    require vaultCache.unitOfAccount == unitOfAccount;

    return updated;
}

//-----------------------------------------------------------------------------'
// From ERC4626 spec
//-----------------------------------------------------------------------------

// This is not in the scene for this config, so we just want it to be
// an uninterpreted function rather than NONDET so that
// we get the same value when this is called for different parts
ghost CVLgetCurrentOnBehalfOfAccountAddr(address) returns address;
ghost CVLgetCurrentOnBehalfOfAccountBool(address) returns bool;
function CVLgetCurrentOnBehalfOfAccount(address addr) returns (address, bool) {
    return (CVLgetCurrentOnBehalfOfAccountAddr(addr),
        CVLgetCurrentOnBehalfOfAccountBool(addr));
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

//run: https://prover.certora.com/output/65266/8d021eab19f945cd86a3ef904b0aa6dc/?anonymousKey=bd4cc32f9af86278b0eceaae2316ea3e385c1cdf
rule zeroDepositZeroShares(uint assets, address receiver)
{
    env e;
    
    uint shares = deposit(e,assets, receiver);
    // In this Vault, max_uint256 as an argument will transfer all assets
    // to the vault. This precondition rules out the case where
    // the depositor calls deposit with a blance of 0 in the underlying
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
            address any;
            safeAssumptions(e, any , e.msg.sender);
        }
    }

invariant noAssetsIfNoSupply(env e) 
   ( userAssets(e, currentContract) == 0 => totalSupply(e) == 0 ) &&
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

// passing: https://prover.certora.com/output/65266/de3636d287d2473294463c07263fc11e/?anonymousKey=ac8f74e6c5c1298f0954a21fafd41cccf32b9ffb
invariant totalSupplyIsSumOfBalances(env e)
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

// passing
// run: https://prover.certora.com/output/65266/1912c053cdf8485087f2c050146c64aa/?anonymousKey=a12e3d573258a4d8136a19b612448a50f80b9a21
rule dustFavorsTheHouse(uint assetsIn )
{
    env e;
        
    require e.msg.sender != currentContract;
    safeAssumptions(e,e.msg.sender,e.msg.sender);
    uint256 totalSupplyBefore = totalSupply(e);

    // uint balanceBefore = ERC20a.balanceOf(e, currentContract);
    uint balanceBefore = currentContract.balanceOf(e, currentContract);

    uint shares = deposit(e,assetsIn, e.msg.sender);
    uint assetsOut = redeem(e,shares,e.msg.sender,e.msg.sender);

    // uint balanceAfter = ERC20a.balanceOf(e, currentContract);
    uint balanceAfter = currentContract.balanceOf(e, currentContract);
    assert balanceAfter >= balanceBefore;
}

////////////////////////////////////////////////////////////////////////////////
////                       #   Risk Analysis                           /////////
////////////////////////////////////////////////////////////////////////////////


invariant vaultSolvency(env e)
    totalAssets(e) >= totalSupply(e)  && userAssets(e, currentContract) >= totalAssets(e)  {
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
    require contributor == CVLgetCurrentOnBehalfOfAccountAddr(0);
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
    // for this ERC4626 implementation balanceOf(Vault) is not the same as total assets
    // ( userAssets(e, currentContract) == 0 => totalSupply(e) == 0 ) &&
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

// rule vaultCacheSanity (method f) {
//     env e;
//     BaseHarness.VaultCache vaultCache;
//     CVLInitVaultCache(e, vaultCache);
//     assert false;
// }