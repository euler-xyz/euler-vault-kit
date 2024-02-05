// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.23;

/// @title IBalanceTracker
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Provides an interface for tracking the balance of accounts
interface IBalanceTracker {
    /// @notice Executes the balance tracking hook for an account
    /// @dev This function is called by the Balance Forwarder contract which was enabled for the account
    /// @dev To prevent DOS attacks, forfeitRecentReward should be used appropriately
    /// @param account The account address to execute the hook for
    /// @param newAccountBalance The new balance of the account
    /// @param forfeitRecentReward Whether to forfeit the most recent reward and not update the accumulator
    function balanceTrackerHook(address account, uint256 newAccountBalance, bool forfeitRecentReward) external;
}
