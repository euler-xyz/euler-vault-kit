use builtin rule sanity;
use builtin rule hasDelegateCalls;
use builtin rule msgValueInLoopRule;
use builtin rule viewReentrancy;

methods {
	function _.requireVaultStatusCheck() external => NONDET;
	function _.requireAccountStatusCheck(address account) external => NONDET;
	function _.requireAccountAndVaultStatusCheck(address account) external => NONDET;
}

rule noRevert(method f) {
	env e;
	calldataarg arg;
	require e.msg.value == 0; 
	f@withrevert(e, arg); 
	assert !lastReverted;
}


rule alwaysRevert(method f) {
	env e;
	calldataarg arg;
	f@withrevert(e, arg); 
	assert lastReverted;
}

/*
This rule find which functions that can be called, may fail due to someone else calling a function right before.

This is n expensive rule - might fail on the demo site on big contracts
*/
rule simpleFrontRunning(method f, address privileged) filtered { f-> !f.isView } {
	env e1;
	calldataarg arg;
	require e1.msg.sender == privileged;  
	storage initialStorage = lastStorage;
	f(e1, arg); 
	bool firstSucceeded = !lastReverted;
	env e2;
	calldataarg arg2;
	require e2.msg.sender != e1.msg.sender;
	f(e2, arg2) at initialStorage; 
	f@withrevert(e1, arg);
	bool succeeded = !lastReverted;
	assert succeeded;
}


/*
This rule find which functions are privileged.
A function is privileged if there is only one address that can call it.

The rules finds this by finding which functions can be called by two different users.
*/
rule privilegedOperation(method f, address privileged) {
	env e1;
	calldataarg arg;
	require e1.msg.sender == privileged;

	storage initialStorage = lastStorage;
	f@withrevert(e1, arg); // privileged succeeds executing candidate privileged operation.
	bool firstSucceeded = !lastReverted;

	env e2;
	calldataarg arg2;
	require e2.msg.sender != privileged;
	f@withrevert(e2, arg2) at initialStorage; // unprivileged
	bool secondSucceeded = !lastReverted;

	assert  !(firstSucceeded && secondSucceeded);
}
