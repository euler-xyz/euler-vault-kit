// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ISequenceRegistry} from "../interfaces/ISequenceRegistry.sol";

/// @title SequenceRegistry
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice This contract maintains sequence counters for any/all addresses, each starting at 1
/// @dev Anybody can reserve a sequence ID. The only guarantee provided is that no two reservations for the same asset will get the same ID.
contract SequenceRegistry is ISequenceRegistry {
    /// @dev Each asset maps to the last sequence ID issued, or 0 if none were ever issued.
    mapping(address asset => uint256 lastSeqId) public counters;

    /// @notice Reserve an ID for a given asset
    /// @param asset The address that this ID is for
    /// @return seqId Sequence ID
    function reserveSeqId(address asset) external returns (uint256 seqId) {
        seqId = ++counters[asset];
    }
}
