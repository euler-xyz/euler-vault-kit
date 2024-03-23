// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVCClient} from "./EVCClient.sol";
import {Cache} from "./Cache.sol";

import {IProtocolConfig} from "../../ProtocolConfig/IProtocolConfig.sol";
import {IBalanceTracker} from "../../interfaces/IBalanceTracker.sol";

import "./types/Types.sol";

abstract contract Base is EVCClient, Cache {
    IProtocolConfig immutable protocolConfig;
    IBalanceTracker immutable balanceTracker;
    address immutable permit2;

    struct Integrations {
        address evc;
        address protocolConfig;
        address balanceTracker;
        address permit2;
    }

    constructor(Integrations memory integrations) EVCClient(integrations.evc) {
        protocolConfig = IProtocolConfig(integrations.protocolConfig);
        balanceTracker = IBalanceTracker(integrations.balanceTracker);
        permit2 = integrations.permit2;
    }

    modifier reentrantOK() {
        _;
    } // documentation only

    modifier nonReentrant() {
        if (marketStorage.reentrancyLocked) revert E_Reentrancy();

        marketStorage.reentrancyLocked = true;
        _;
        marketStorage.reentrancyLocked = false;
    }

    modifier nonReentrantView() {
        if (marketStorage.reentrancyLocked) revert E_Reentrancy();
        _;
    }

    // Generate a market snapshot and store it.
    // Queue vault and maybe account checks in the EVC (caller, current, onBehalfOf or none).
    // If needed, revert if this contract is not the controller of the authenticated account.
    // Returns the MarketCache and active account.
    function initOperation(uint32 operation, address accountToCheck)
        internal
        returns (MarketCache memory marketCache, address account)
    {
        marketCache = updateMarket();

        if (marketCache.disabledOps.isSet(operation)) {
            revert E_OperationDisabled();
        }

        // The snapshot is used only to verify that supply increased when checking the supply cap, and to verify that the borrows
        // increased when checking the borrowing cap. Caps are not checked when the capped variables decrease (become safer).
        // For this reason, the snapshot is disabled if both caps are disabled.
        if (
            !marketCache.snapshotInitialized
                && (marketCache.supplyCap < type(uint256).max || marketCache.borrowCap < type(uint256).max)
        ) {
            marketStorage.snapshotInitialized = marketCache.snapshotInitialized = true;
            snapshot.set(marketCache.cash, marketCache.totalBorrows.toAssetsUp());
        }

        account = EVCAuthenticateDeferred(~CONTROLLER_REQUIRED_OPS & operation == 0);

        EVCRequireStatusChecks(accountToCheck == CHECKACCOUNT_CALLER ? account : accountToCheck);
    }

    function logMarketStatus(MarketCache memory a, uint256 interestRate) internal {
        emit MarketStatus(
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
