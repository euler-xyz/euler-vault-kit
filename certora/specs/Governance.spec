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

	function checkAccountMagicValueMemory() external returns (bytes memory) envfree;
    function checkVaultMagicValueMemory() external returns (bytes memory) envfree;

	// Harness
	function getAccountBalance(address) external returns (GovernanceHarness.Shares) envfree;
	function getGovernorReceiver() external returns (address) envfree;
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
	function EthereumVaultConnector.checkVaultStatusInternal(address vault) internal returns (bool, bytes memory) =>
        CVLCheckVaultStatusInternal();

	function _.invokeHookTarget(address caller) internal => NONDET;

	function _.balanceTrackerHook(address account, uint256 newAccountBalance, bool forfeitRecentReward) external => NONDET;

	function _.computeInterestRate(BaseHarness.VaultCache memory) internal => CONSTANT;
	
}


function CVLCheckVaultStatusInternalBool(env e) returns bool {
    checkVaultStatus@withrevert(e);
    return !lastReverted;
}

function CVLCheckVaultStatusInternal() returns (bool, bytes) {
	// We need a new env for the first function.
    // Since the vault calls the EVC, otherwise msg.sender
    // would become the vault unless we declare a fresh environment.
	env e;
    return (CVLCheckVaultStatusInternalBool(e),
        checkVaultMagicValueMemory());
}


// Collecting fees should increase the protocol’s and the governor’s asset (unless the governor is address(0))
// STATUS: PASSING
// https://prover.certora.com/output/65266/9207ef71046343e993e83f9dfa761eb1?anonymousKey=401a193cacbcbc774185473b0242384e3e8c5b4d
rule feeCollectionIncreasesProtocolGovernerAssets(env e){

	address protocolReceiver; 
	uint16 protocolFee;
	protocolReceiver, protocolFee = getProtocolFeeConfig(currentContract);
	require protocolFee > 0;
	// require protocolReceiver != 0;
	address governorReceiver = getGovernorReceiver();
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

// These are assumed elsewhere in the specs
// Pasing. Run link: https://prover.certora.com/output/65266/c078d73b9aaf41b69de58a059ec9c0ea?anonymousKey=3c865aa300106c0b53d38a8dc479dc0668774e48
rule LTVConfigProperties {
	env e;
	address collateral;
	uint16 borrowLTV;
	uint16 liquidationLTV;
	uint32 rampDuration;
	uint16 old_borrowLTVOut = getLTVHarness(e, collateral, false);
	uint16 old_liquidationLTVOut = getLTVHarness(e, collateral, true);
	require old_borrowLTVOut <= 10000 && 
		old_liquidationLTVOut <= 10000 && 
		old_liquidationLTVOut >= old_borrowLTVOut;
	setLTV(e, collateral, borrowLTV, liquidationLTV, rampDuration);
	uint16 borrowLTVOut = getLTVHarness(e, collateral, false);
	uint16 liquidationLTVOut = getLTVHarness(e, collateral, true);
	assert borrowLTVOut <= 10000 && 
		liquidationLTVOut <= 10000 && 
		liquidationLTVOut >= borrowLTVOut;
}