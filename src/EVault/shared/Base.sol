// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVCClient} from "./EVCClient.sol";
import {Cache} from "./Cache.sol";

import {IProtocolConfig} from "../../IProtocolConfig.sol";
import {IBalanceTracker} from "../../IBalanceTracker.sol";
import "./types/Types.sol";

abstract contract Base is EVCClient, Cache {
    IProtocolConfig immutable protocolConfig;
    IBalanceTracker immutable balanceTracker;

    constructor(address _evc, address _protocolConfig, address _balanceTracker) EVCClient(_evc) {
        protocolConfig = IProtocolConfig(_protocolConfig);
        balanceTracker = IBalanceTracker(_balanceTracker);
    }

    modifier reentrantOK() {
        _;
    } // documentation only

    modifier nonReentrant() {
        if (marketStorage.reentrancyLock) revert E_Reentrancy();

        marketStorage.reentrancyLock = true;
        _;
        marketStorage.reentrancyLock = false;
    }

    modifier nonReentrantView() {
        if (marketStorage.reentrancyLock) revert E_Reentrancy();
        _;
    }


    // Don't call this for OP_BORROW, OP_WIND, OP_PULL_DEBT.
    // Generate a market snapshot and store it.
    // Queue vault and maybe account checks in the EVC (caller, current, onBehalfOf or none).
    // Returns the MarketCache and active account.
    function initOperation(uint32 operation, address checkAccount)
        internal
        returns (MarketCache memory marketCache, address account)
    {
        (marketCache, account) = initMarketAndAccount(operation, false);

        EVCRequireStatusChecks(checkAccount == ACCOUNTCHECK_CALLER ? account : checkAccount);
    }

    // Called for OP_BORROW, OP_WIND, OP_PULL_DEBT.
    // Generate a market snapshot and store it.
    // Queue account checks in the EVC (current or onBehalfOf).
    // Revert if this contract is not the account controller.
    // Returns the MarketCache and active account.
    function initOperationForBorrow(uint32 operation)
        internal
        returns (MarketCache memory marketCache, address account)
    {
        (marketCache, account) = initMarketAndAccount(operation, true);

        EVCRequireStatusChecks(account);
    }

    // Generate an updated MarketCache.
    // Generate a market snapshot if it doesn't yet exits, and store it.
    // If `checkController == true` revert if this contract is not the controller for the active account.
    // Returns the MarketCache and active account.
    function initMarketAndAccount(uint32 operation, bool checkController)
        private
        returns (MarketCache memory marketCache, address account)
    {
        marketCache = updateMarket();

        if (marketCache.disabledOps.get(operation)) {
            revert E_OperationDisabled();
        }

        // alcueca: The snapshot is used only to verify that supply increased when checking the supply cap, and to verify that the borrows
        // increased when checking the borrowing cap. Caps are not checked when the capped variables decrease (become safer).
        // For this reason, the snapshot is disabled if both caps are disabled.
        if (!marketCache.snapshotInitialized && (marketCache.supplyCap < type(uint256).max || marketCache.borrowCap < type(uint256).max)) {
            marketStorage.snapshotInitialized = marketCache.snapshotInitialized = true;
            snapshotPoolSize = marketCache.poolSize; // alcueca: poolSize are the vault assets and borrows in asset terms
            snapshotTotalBorrows = marketCache.totalBorrows.toAssetsUp(); // alcueca: totalBorrows are the vault borrows in asset terms
        }

        account = EVCAuthenticateDeferred(checkController);
    }

    // Emit a MarketStatus event
    function logMarketStatus(MarketCache memory a, uint72 interestRate) internal {
        emit MarketStatus(
            a.totalShares.toUint(),
            a.totalBorrows.toAssetsUp().toUint(),
            a.feesBalance.toUint(),
            a.poolSize.toUint(),
            a.interestAccumulator,
            interestRate,
            block.timestamp
        );
    }
}
