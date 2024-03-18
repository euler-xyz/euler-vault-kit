// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

// Contracts
import {EVault} from "src/EVault/EVault.sol";

// Types
import {Snapshot} from "src/EVault/shared/types/Types.sol";

contract EVaultExtended is EVault {
    constructor(
        Integrations memory integrations,
        DeployedModules memory modules
    ) EVault(
        integrations, 
        modules
    ) {}

    function getReentrancyLock() external view returns (bool) {
        return marketStorage.reentrancyLocked;
    }

    function getSnapshot() external view returns (Snapshot memory) {
        return snapshot;
    }

    function getLastInterestAccumulatorUpdate() external view returns (uint256) {
        return marketStorage.lastInterestAccumulatorUpdate;
    }

    function isDisabledOp(uint32 bitMask) external view returns (bool) {
        return marketStorage.disabledOps.check(bitMask);
    }
}