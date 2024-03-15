// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

// Contracts
import {EVault} from "src/EVault/EVault.sol";

// Types
import {Snapshot} from "src/EVault/shared/types/Types.sol";

contract EVaultExtended is EVault {
    constructor(
        Integrations memory integrations,
        address MODULE_INITIALIZE_,
        address MODULE_TOKEN_,
        address MODULE_VAULT_,
        address MODULE_BORROWING_,
        address MODULE_LIQUIDATION_,
        address MODULE_RISKMANAGER_,
        address MODULE_BALANCE_FORWARDER_,
        address MODULE_GOVERNANCE_
    ) EVault(
        integrations, 
        MODULE_INITIALIZE_,
        MODULE_TOKEN_,
        MODULE_VAULT_,
        MODULE_BORROWING_,
        MODULE_LIQUIDATION_,
        MODULE_RISKMANAGER_,
        MODULE_BALANCE_FORWARDER_,
        MODULE_GOVERNANCE_
    ) {}

    function getReentrancyLock() external view returns (bool) {
        return marketStorage.reentrancyLock;
    }

    function getSnapshot() external view returns (Snapshot memory) {
        return snapshot;
    }

    function getLastInterestAccumulatorUpdate() external view returns (uint256) {
        return marketStorage.lastInterestAccumulatorUpdate;
    }
}