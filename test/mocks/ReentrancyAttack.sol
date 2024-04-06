// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

interface IVault {
    function initialize(address creator) external;
}

interface IGenericFactory {
    function createProxy(bool upgradeable, bytes memory trailingData) external returns (address);
}

contract ReentrancyAttack is IVault {
    address immutable factory;
    address immutable asset;

    constructor(address _factory, address _asset) {
        factory = _factory;
        asset = _asset;
    }

    function initialize(address) external {
        IGenericFactory(factory).createProxy(true, abi.encodePacked(asset, address(this)));
    }

    function testExcludeFromCoverage() public pure {}
}
