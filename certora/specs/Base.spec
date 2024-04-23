using DummyERC20A as erc20;
// using EthereumVaultConnector as evc;

methods {
    // envfree
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

/*
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
*/