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
        if (marketStorage.bitField.get(BF_REENTRANCYLOCK)) revert E_Reentrancy();

        marketStorage.bitField = marketStorage.bitField.set(BF_REENTRANCYLOCK);
        _;
        marketStorage.bitField = marketStorage.bitField.clear(BF_REENTRANCYLOCK);
    }

    modifier nonReentrantView() {
        if (marketStorage.bitField.get(BF_REENTRANCYLOCK)) revert E_Reentrancy();
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
        if (marketStorage.bitField.get(operation)) {
            revert E_OperationPaused();
        }

        marketCache = updateMarket();

        if (!marketStorage.bitField.get(BF_SNAPSHOT)) {
            marketStorage.bitField = marketStorage.bitField.set(BF_SNAPSHOT);
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
