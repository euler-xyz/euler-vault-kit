// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

/// @title ISequenceRegistry
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Provides an interface for reserving sequence IDs.
interface ISequenceRegistry {
    function reserveSeqId(address asset) external returns (uint256 seqId);
}
