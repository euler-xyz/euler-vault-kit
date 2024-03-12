// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Hook Contracts
import {VaultBeforeAfterHooks} from "./VaultBeforeAfterHooks.t.sol";
import {BorrowingBeforeAfterHooks} from "./BorrowingBeforeAfterHooks.t.sol";

/// @title HookAggregator
/// @notice Helper contract to aggregate all before / after hook contracts, inherited on each handler
abstract contract HookAggregator is
    VaultBeforeAfterHooks,
    BorrowingBeforeAfterHooks
{
    /// @notice Modular hook selector, per module
    function _before() internal {
        _vaultHooksBefore();
        _borrowingHooksBefore();
    }

    /// @notice Modular hook selector, per module
    function _after() internal {
        _vaultHooksAfter();
        _borrowingHooksAfter();

        // Postconditions
        _postConditions();
    }

    /// @notice Postconditions for the handlers
    function _postConditions() internal {
        // Vault
        assert_VM_INVARIANT_B();

        // Borrowing
        assert_BM_INVARIANT_G();
        assert_BM_INVARIANT_H();
        assert_BM_INVARIANT_I();
        assert_BM_INVARIANT_J();
    }
}
