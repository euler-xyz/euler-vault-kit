// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVCClient} from "./EVCClient.sol";
import {Cache} from "./Cache.sol";

import {IProtocolAdmin} from "../../IProtocolAdmin.sol";
import {IBalanceTracker} from "../../IBalanceTracker.sol";

import "./types/Types.sol";

abstract contract Base is EVCClient, Cache {
    IProtocolAdmin immutable protocolAdmin;
    IBalanceTracker immutable balanceTracker;

    constructor(address _evc, address _protocolAdmin, address _balanceTracker) EVCClient(_evc) {
        protocolAdmin = IProtocolAdmin(_protocolAdmin);
        balanceTracker = IBalanceTracker(_balanceTracker);
    }

    modifier reentrantOK() {
        _;
    } // documentation only

    modifier nonReentrant() {
        if (marketStorage.reentrancyLock != REENTRANCYLOCK__UNLOCKED) revert E_Reentrancy();

        marketStorage.reentrancyLock = REENTRANCYLOCK__LOCKED;
        _;
        marketStorage.reentrancyLock = REENTRANCYLOCK__UNLOCKED;
    }

    modifier nonReentrantView() {
        if (marketStorage.reentrancyLock != REENTRANCYLOCK__UNLOCKED) revert E_Reentrancy();
        _;
    }

    function initOperation(uint32 operation, address checkAccount)
        internal
        returns (MarketCache memory marketCache, address account)
    {
        (marketCache, account) = initMarketAndAccount(operation, false);

        EVCRequireStatusChecks(checkAccount == ACCOUNTCHECK_CALLER ? account : checkAccount);
    }

    function initOperationForBorrow(uint32 operation)
        internal
        returns (MarketCache memory marketCache, address account)
    {
        (marketCache, account) = initMarketAndAccount(operation, true);

        EVCRequireStatusChecks(account);
    }

    function initMarketAndAccount(uint32 operation, bool checkController)
        private
        returns (MarketCache memory marketCache, address account)
    {
        marketCache = updateMarket();
        snapshotMarket(operation, marketCache);

        account = EVCAuthenticateDeferred(checkController);
    }

    function snapshotMarket(uint32 operation, MarketCache memory marketCache) internal {
        uint32 performedOperations = marketStorage.marketSnapshot.performedOperations;

        if (performedOperations == 0) {
            marketStorage.marketSnapshot = getMarketSnapshot(operation, marketCache);
        } else if (performedOperations & operation == 0) {
            marketStorage.marketSnapshot.performedOperations = performedOperations | operation;
        }
    }

    function getMarketSnapshot(uint32 operation, MarketCache memory marketCache)
        internal
        pure
        returns (MarketSnapshot memory)
    {
        return MarketSnapshot({
            poolSize: marketCache.poolSize,
            totalBorrows: marketCache.totalBorrows.toAssetsUp(),
            performedOperations: operation
        });
    }

    function logMarketStatus(MarketCache memory a, uint72 interestRate) internal {
        emit MarketStatus(
            a.totalShares.toUint(),
            a.totalBorrows.toAssetsUp().toUint(),
            Fees.unwrap(a.feesBalance),
            a.poolSize.toUint(),
            a.interestAccumulator,
            interestRate,
            block.timestamp
        );
    }
}
