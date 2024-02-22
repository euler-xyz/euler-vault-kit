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
        if (marketConfig.pauseBitmask & operation != 0) {
            revert E_OperationPaused();
        }

        marketCache = updateMarket();

        if (!marketStorage.snapshotInitialized) {
            marketStorage.snapshotInitialized = true;
            snapshotPoolSize = marketCache.poolSize;
            snapshotTotalBorrows = marketCache.totalBorrows.toAssetsUp();
        }

        account = EVCAuthenticateDeferred(checkController);
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
