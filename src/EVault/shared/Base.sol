// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {CVCClient} from "./CVCClient.sol";
import {Cache} from "./Cache.sol";

import "./types/Types.sol";

abstract contract Base is CVCClient, Cache {
    address immutable public factory;

    constructor(address factory_, address cvc_) CVCClient(cvc_) {
        factory = factory_;
    }

    modifier reentrantOK() { _; } // documentation only

    modifier nonReentrant() {
        if (marketStorage.reentrancyLock != REENTRANCYLOCK__UNLOCKED) revert E_Reentrancy();

        marketStorage.reentrancyLock = REENTRANCYLOCK__LOCKED;
        _;
        marketStorage.reentrancyLock = REENTRANCYLOCK__UNLOCKED;
    }

    function loadMarketAndAuthenticate(uint8 pauseType, bool isBorrowOperation) private returns (MarketCache memory marketCache, address account) {
        marketCache = loadAndUpdateMarket();
        marketSnapshot(pauseType, marketCache); 
        account = CVCAuthenticate(isBorrowOperation);
    }

    function initMarketAndAccount(uint8 pauseType) internal returns (MarketCache memory marketCache, address account) {
        (marketCache, account) = loadMarketAndAuthenticate(pauseType, false);
    }

    function initMarketAndAccountForBorrow(uint8 pauseType) internal returns (MarketCache memory marketCache, address account) {
        (marketCache, account) = loadMarketAndAuthenticate(pauseType, true);
    }

    function checkMarketAndAccountStatus(MarketCache memory marketCache, address account) internal {
        CVCRequireStatusChecks(account);
        logMarketStatus(marketCache);
    }

    function logMarketStatus(MarketCache memory a) internal {
        emit MarketStatus(a.totalBalances.toUint(), a.totalBorrows.toUintAssetsDown(), Fees.unwrap(a.feesBalance), a.poolSize.toUint(), a.interestAccumulator, a.interestRate, block.timestamp);
    }

    function getMarketSnapshot(uint8 operationType, MarketCache memory marketCache) internal pure returns (MarketSnapshot memory) {
        return MarketSnapshot({
            totalBalances: marketCache.totalBalances.toAssetsDown(marketCache),
            totalBorrows: marketCache.totalBorrows,
            performedOperations: operationType,
            poolSize: marketCache.poolSize,
            interestAccumulator: uint136(marketCache.interestAccumulator) // TODO cast down
        });
    }

    function marketSnapshot(uint8 operationType, MarketCache memory marketCache) internal {
        uint8 performedOperations = marketStorage.marketSnapshot.performedOperations;

        if (performedOperations == 0) {
            marketStorage.marketSnapshot = getMarketSnapshot(operationType, marketCache);
        } else {
            marketStorage.marketSnapshot.performedOperations = performedOperations | operationType;
        }
    }

    function revertBytes(bytes memory errMsg) internal pure {
        if (errMsg.length > 0) {
            assembly {
                revert(add(32, errMsg), mload(errMsg))
            }
        }

        revert Errors.E_EmptyError();
    }
}
