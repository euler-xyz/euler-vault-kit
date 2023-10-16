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

    modifier nonReentrantWithChecks() { _; } // documentation only
    modifier reentrantOK() { _; } // documentation only

    modifier nonReentrant() {
    if (marketStorage.reentrancyLock != REENTRANCYLOCK__UNLOCKED) revert E_Reentrancy();

        marketStorage.reentrancyLock = REENTRANCYLOCK__LOCKED;
        _;
        marketStorage.reentrancyLock = REENTRANCYLOCK__UNLOCKED;
    }

    modifier lock(address account, MarketCache memory marketCache, uint8 pauseType) {
        if (marketStorage.reentrancyLock != REENTRANCYLOCK__UNLOCKED) revert E_Reentrancy();

        marketStorage.reentrancyLock = REENTRANCYLOCK__LOCKED;
        marketSnapshot(pauseType, marketCache); 

        _;

        marketStorage.reentrancyLock = REENTRANCYLOCK__UNLOCKED;

        checkAccountAndMarketStatus(account);
        logMarketStatus(marketCache);
    }

    function logMarketStatus(MarketCache memory a) internal {
        emit MarketStatus(address(this), a.totalBalances.toUint(), a.totalBorrows.toAssetsDown().toUint(), Fees.unwrap(a.feesBalance), a.poolSize.toUint(), a.interestAccumulator, a.interestRate, block.timestamp);
    }

    function getMarketSnapshot(uint8 operationType, MarketCache memory marketCache) internal pure returns (MarketSnapshot memory) {
        return MarketSnapshot({
            performedOperations: operationType,
            poolSize: marketCache.poolSize,
            totalBalances: marketCache.totalBalances.toAssetsDown(marketCache),
            totalBorrows: marketCache.totalBorrows.toAssetsDown(),
            interestAccumulator: uint144(marketCache.interestAccumulator)
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

    function revertBytes(bytes memory errMsg) internal pure override {
        if (errMsg.length > 0) {
            assembly {
                revert(add(32, errMsg), mload(errMsg))
            }
        }

        revert Errors.E_EmptyError();
    }
}
