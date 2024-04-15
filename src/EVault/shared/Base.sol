// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVCClient} from "./EVCClient.sol";
import {Cache} from "./Cache.sol";
import {RevertBytes} from "./lib/RevertBytes.sol";
import {AddressUtils} from "./lib/AddressUtils.sol";

import {IProtocolConfig} from "../../ProtocolConfig/IProtocolConfig.sol";
import {IBalanceTracker} from "../../interfaces/IBalanceTracker.sol";

import "./types/Types.sol";

/// @title Base
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Base contract for EVault modules with top level modifiers and utilities
abstract contract Base is EVCClient, Cache {
    IProtocolConfig internal immutable protocolConfig;
    IBalanceTracker internal immutable balanceTracker;
    address internal immutable permit2;

    struct Integrations {
        address evc;
        address protocolConfig;
        address balanceTracker;
        address permit2;
    }

    constructor(Integrations memory integrations) EVCClient(integrations.evc) {
        protocolConfig = IProtocolConfig(AddressUtils.checkContract(integrations.protocolConfig));
        balanceTracker = IBalanceTracker(integrations.balanceTracker);
        permit2 = integrations.permit2;
    }

    modifier reentrantOK() {
        _;
    } // documentation only

    modifier nonReentrant() {
        if (vaultStorage.reentrancyLocked) revert E_Reentrancy();

        vaultStorage.reentrancyLocked = true;
        _;
        vaultStorage.reentrancyLocked = false;
    }

    modifier nonReentrantView() {
        if (vaultStorage.reentrancyLocked) revert E_Reentrancy();
        _;
    }

    // Generate a vault snapshot and store it.
    // Queue vault and maybe account checks in the EVC (caller, current, onBehalfOf or none).
    // If needed, revert if this contract is not the controller of the authenticated account.
    // Returns the VaultCache and active account.
    function initOperation(uint32 operation, address accountToCheck)
        internal
        returns (VaultCache memory vaultCache, address account)
    {
        vaultCache = updateVault();
        account = EVCAuthenticateDeferred(CONTROLLER_NEUTRAL_OPS & operation == 0);

        validateAndCallHook(vaultCache.hookedOps, operation, account);
        EVCRequireStatusChecks(accountToCheck == CHECKACCOUNT_CALLER ? account : accountToCheck);

        // The snapshot is used only to verify that supply increased when checking the supply cap, and to verify that the borrows
        // increased when checking the borrowing cap. Caps are not checked when the capped variables decrease (become safer).
        // For this reason, the snapshot is disabled if both caps are disabled.
        if (
            !vaultCache.snapshotInitialized
                && (vaultCache.supplyCap < type(uint256).max || vaultCache.borrowCap < type(uint256).max)
        ) {
            vaultStorage.snapshotInitialized = vaultCache.snapshotInitialized = true;
            snapshot.set(vaultCache.cash, vaultCache.totalBorrows.toAssetsUp());
        }
    }

    // Checks whether the operation is hookable and if so, calls the hook target.
    // If the hook target is not a contract, the operation is considered disabled.
    function validateAndCallHook(Flags hookedOps, uint32 operation, address caller) internal {
        if (hookedOps.isNotSet(operation)) return;

        address hookTarget = vaultStorage.hookTarget;

        if (hookTarget.code.length == 0) revert E_OperationDisabled();

        (bool success, bytes memory data) = hookTarget.call(abi.encodePacked(msg.data, caller));

        if (!success) RevertBytes.revertBytes(data);
    }

    // Checks whether the operation is hookable and if so, calls the hook target.
    // If the hook target is not a contract or the hook target call is reverting,
    // the operation is considered disabled.
    function validateAndCallHookView(Flags hookedOps, uint32 operation) internal view returns (bool) {
        if (hookedOps.isNotSet(operation)) return true;

        address hookTarget = vaultStorage.hookTarget;
        (bool success,) = hookTarget.staticcall(msg.data);

        return success && hookTarget.code.length != 0;
    }

    function logVaultStatus(VaultCache memory a, uint256 interestRate) internal {
        emit VaultStatus(
            a.totalShares.toUint(),
            a.totalBorrows.toAssetsUp().toUint(),
            a.accumulatedFees.toUint(),
            a.cash.toUint(),
            a.interestAccumulator,
            interestRate,
            block.timestamp
        );
    }
}
