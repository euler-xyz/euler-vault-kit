// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IInitialize, IERC20} from "../IEVault.sol";
import {IRiskManager} from "../../IRiskManager.sol";
import {IFactory} from "../shared/interfaces/IFactory.sol";
import {Base} from "../shared/Base.sol";
import {BorrowUtils} from "../shared/BorrowUtils.sol";
import {DToken} from "../DToken.sol";
import {ProxyUtils} from "../shared/lib/ProxyUtils.sol";

import "../shared/Constants.sol";

abstract contract InitializeModule is IInitialize, Base, BorrowUtils {
    /// @inheritdoc IInitialize
    function initialize(address creator) external virtual reentrantOK {
        if (initialized) revert E_Initialized();
        initialized = true;

        // Validate proxy immutables

        // Calldata should include: signature and abi encoded address argument (4 + 32 bytes) followed by proxy metadata
        if (msg.data.length != 4 + 32 + PROXY_METADATA_LENGTH) revert E_ProxyMetadata();
        (IERC20 asset, IRiskManager riskManager) = ProxyUtils.metadata();
        if (
            address(asset) == address(0) || address(asset) == address(riskManager) || address(asset) == address(evc)
                || address(riskManager) == address(0) || address(riskManager) == address(evc)
        ) revert E_BadAddress();

        // Initialize storage

        factory = msg.sender;

        marketStorage.lastInterestAccumulatorUpdate = uint40(block.timestamp);
        marketStorage.interestAccumulator = INITIAL_INTEREST_ACCUMULATOR;
        marketStorage.reentrancyLock = REENTRANCYLOCK__UNLOCKED;

        address admin = IFactory(factory).upgradeAdmin();
        if (admin == address(0)) revert E_BadAddress();
        marketStorage.protocolFeesHolder = admin;
        emit NewProtocolFeesHolder(admin);

        // Create companion DToken

        address dToken = address(new DToken());

        // Initialize new vault on the risk manager

        (, IRiskManager rm) = ProxyUtils.metadata();
        rm.activateMarket(creator);

        // Initialize interest rate and interest fee
        updateInterestParams(loadMarket());
        if (marketStorage.interestFee == 0) revert E_InterestFeeInit();

        emit EVaultCreated(creator, address(asset), address(riskManager), dToken);
    }
}

contract Initialize is InitializeModule {
    constructor(address evc) Base(evc) {}
}
