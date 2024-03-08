// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Hook Contracts
import {TokenBeforeAfterHooks} from "./TokenBeforeAfterHooks.t.sol";
import {VaultBeforeAfterHooks} from "./VaultBeforeAfterHooks.t.sol";
import {BorrowingBeforeAfterHooks} from "./BorrowingBeforeAfterHooks.t.sol";

/// @title HookAggregator
/// @notice Helper contract to aggregate all before / after hook contracts, inherited on each handler
abstract contract HookAggregator is
    TokenBeforeAfterHooks,
    VaultBeforeAfterHooks,
    BorrowingBeforeAfterHooks
{
    /// @notice Modular hook selector, per vault type
    function _before() internal {
        _tokenHooksBefore();
        _vaultHooksBefore();
        _borrowingHooksBefore();
    }

    /// @notice Modular hook selector, per vault type
    function _after() internal {
        _tokenHooksAfter();
        _vaultHooksAfter();
        _borrowingHooksAfter();
    }
}
