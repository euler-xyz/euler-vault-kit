methods {
	// Havocs here should be OK, but want to remove the linking issues from the tool
	function _.calculateDTokenAddress() internal => NONDET;
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

	// Harness
	function getAccountBalance(address) external returns (GovernanceHarness.Shares) envfree;
	function getGovernorReciver() external returns (address) envfree;
	function getProtocolFeeConfig(address) external returns (address, uint16) envfree;
	function getTotalShares() external returns (GovernanceHarness.Shares) envfree;
	function getAccumulatedFees() external returns (GovernanceHarness.Shares);
	function getLastAccumulated() external returns (uint256) envfree;

	// protocolConfig
	function ProtocolConfig.protocolFeeConfig(address) external returns (address, uint16) envfree;

	// unresolved calls havocing all contracts

	// We can't handle the low-level call in 
    // EthereumVaultConnector.checkAccountStatusInternal 
    // and so reroute it to RiskManager's status check with this summary.
	function EthereumVaultConnector.checkVaultStatusInternal(address vault) internal returns (bool, bytes memory) with(env e) =>
        CVLCheckVaultStatusInternal(e);

	function _.invokeHookTarget(address caller) internal => NONDET;

	function _.balanceTrackerHook(address account, uint256 newAccountBalance, bool forfeitRecentReward) external => NONDET;
	
}


function CVLCheckVaultStatusInternalBool(env e) returns bool {
    checkVaultStatus@withrevert(e);
    return !lastReverted;
}

function CVLCheckVaultStatusInternal(env e) returns (bool, bytes) {
    return (CVLCheckVaultStatusInternalBool(e),
        checkVaultMagicValueMemory(e));
}

// Both rules pass. Run with both:
// https://prover.certora.com/output/65266/9207ef71046343e993e83f9dfa761eb1?anonymousKey=401a193cacbcbc774185473b0242384e3e8c5b4d

// Collecting fees should increase the protocol’s and the governor’s asset (unless the governor is address(0))
// STATUS: PASSING
rule feeCollectionIncreasesProtocolGovernerAssets(env e){

	address protocolReceiver; 
	uint16 protocolFee;
	protocolReceiver, protocolFee = getProtocolFeeConfig(currentContract);
	require protocolFee > 0;
	// require protocolReceiver != 0;
	address governorReceiver = getGovernorReciver();
	require governorReceiver != 0;

	// accumulated fee is not zero 
	uint112 fees = getAccumulatedFees(e);

	// at fee == 1 the governor fee can be rounded down to zero and the 1 wei fee goes to the protocol
	require fees >1;

	uint112 protocolReceiverBal_before = getAccountBalance(protocolReceiver);
	uint112 governorReceiverBal_before = getAccountBalance(governorReceiver);
	
	convertFees(e);
	
	uint112 protocolReceiverBal_after = getAccountBalance(protocolReceiver);
	uint112 governorReceiverBal_after = getAccountBalance(governorReceiver);

	assert protocolReceiverBal_after > protocolReceiverBal_before 
			&& governorReceiverBal_after > governorReceiverBal_before,
	"collecting fees should icnrease the shares of the governor and protocol";
}

// Collecting fees should not change total shares
// STATUS: PASSING
rule collectingFeeDoesntChangeTotalShares(env e){
	
	uint112 totalShares_before = getTotalShares();
	// requiring that no fee accumulation happens to increase totalShares
	require getLastAccumulated() == e.block.timestamp;

	convertFees(e);
	
	uint112 totalShares_after = getTotalShares();

	assert totalShares_after ==  totalShares_before,"fee collection should not change total shares";

}