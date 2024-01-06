// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVCClient} from "./EVCClient.sol";
import {Cache} from "./Cache.sol";

import "./types/Types.sol";

abstract contract Base is EVCClient, Cache {
    constructor(address evc) EVCClient(evc) {}

    // documentation only
    modifier reentrantOK() {
        _;
    }

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

    function initOperation(uint24 operation, address checkAccount)
        internal
        returns (MarketCache memory marketCache, address account)
    {
        (marketCache, account) = initMarketAndAccountCommon(operation, false);

        EVCRequireStatusChecks(checkAccount == ACCOUNT_CHECK_CALLER ? account : checkAccount);
    }

    function initOperationForBorrow(uint24 operation)
        internal
        returns (MarketCache memory marketCache, address account)
    {
        (marketCache, account) = initMarketAndAccountCommon(operation, true);

        EVCRequireStatusChecks(account);
    }

    function initMarketAndAccountCommon(uint24 operation, bool checkController)
        private
        returns (MarketCache memory marketCache, address account)
    {
        marketCache = loadAndUpdateMarket();
        snapshotMarket(operation, marketCache);

        account = EVCAuthenticate(checkController);
    }

    function snapshotMarket(uint24 operation, MarketCache memory marketCache) internal {
        uint24 performedOperations = marketStorage.marketSnapshot.performedOperations;

        if (performedOperations == 0) {
            marketStorage.marketSnapshot = getMarketSnapshot(operation, marketCache);
        } else {
            marketStorage.marketSnapshot.performedOperations = performedOperations | operation;
        }
    }

    function getMarketSnapshot(uint24 operation, MarketCache memory marketCache)
        internal
        pure
        returns (MarketSnapshot memory)
    {
        return MarketSnapshot({
            poolSize: marketCache.poolSize,
            totalBorrows: marketCache.totalBorrows.toOwedAssetsSnapshot(),
            performedOperations: operation
        });
    }
}
