// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

interface IRiskManager {
    function onMarketActivation(address creator, address market, address asset, bytes calldata riskManagerConfig) external returns (bool success);
}

interface IEVaultFactory {
    function activateMarket(address asset, address riskManager, bytes memory riskManagerConfig) external returns (address);
}

contract ReentrancyAttack is IRiskManager {
    address factory;
    address asset;

    constructor(address _factory, address _asset){
        factory = _factory;
        asset = _asset;
    }
    // Factory - test modifier nonReentrancy activateMarket
    function onMarketActivation(
        address creator,
        address market,
        address asset,
        bytes calldata riskManagerConfig
    ) external override returns (bool success) {
        IEVaultFactory(factory).activateMarket(asset, address(this), "");
        success = false;
    }
}
