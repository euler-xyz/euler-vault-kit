// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.19;

import "../../lib/ethereum-vault-connector/src/EthereumVaultConnector.sol";
contract EVCHarness is EthereumVaultConnector {
    using ExecutionContext for EC;
    using Set for SetStorage;

    // Trigger the (deferred) status checks in restoreExecutionContext
    // explicitly. 
    function checkStatusAllExt() external {
        checkStatusAll(SetType.Account);
    }
}