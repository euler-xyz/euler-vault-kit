// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IInitialize, IERC20} from "../IEVault.sol";
import {Base} from "../shared/Base.sol";
import {BorrowUtils} from "../shared/BorrowUtils.sol";
import {DToken} from "../DToken.sol";
import {ProxyUtils} from "../shared/lib/ProxyUtils.sol";
import {MarketCache} from "../shared/types/MarketCache.sol";

import "../shared/Constants.sol";

abstract contract InitializeModule is IInitialize, Base, BorrowUtils {
    /// @inheritdoc IInitialize
    function initialize(address creator) external virtual reentrantOK {
        if (initialized) revert E_Initialized();
        initialized = true;

        governorAdmin = creator;

        // Validate proxy immutables

        // Calldata should include: signature and abi encoded creator address (4 + 32 bytes), followed by proxy metadata
        if (msg.data.length != 4 + 32 + PROXY_METADATA_LENGTH) revert E_ProxyMetadata();
        (IERC20 asset) = ProxyUtils.metadata();
        if (
            address(asset) == address(0) || address(asset) == address(evc) || address(asset).code.length == 0
        ) revert E_BadAddress();

        // Create companion DToken

        address dToken = address(new DToken());

        // Initialize storage

        marketStorage.lastInterestAccumulatorUpdate = uint40(block.timestamp);
        marketStorage.interestAccumulator = INITIAL_INTEREST_ACCUMULATOR;
        marketStorage.reentrancyLock = REENTRANCYLOCK__UNLOCKED;

        // Initialize config

        marketConfig.interestFee = DEFAULT_INTEREST_FEE;
        marketConfig.unitOfAccount = address(asset);

        // Emit logs

        emit EVaultCreated(creator, address(asset), dToken);
        logMarketStatus(loadMarket(), 0);
    }
}

contract Initialize is InitializeModule {
    constructor(address evc, address protocolAdmin, address balanceTracker) Base(evc, protocolAdmin, balanceTracker) {}
}
