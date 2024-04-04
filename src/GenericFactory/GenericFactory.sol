// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BeaconProxy} from "./BeaconProxy.sol";
import {MetaProxyDeployer} from "./MetaProxyDeployer.sol";

interface IComponent {
    function initialize(address creator) external;
}

contract GenericFactory is MetaProxyDeployer {
    // Constants

    uint256 constant REENTRANCYLOCK__UNLOCKED = 1;
    uint256 constant REENTRANCYLOCK__LOCKED = 2;

    // State

    struct ProxyConfig {
        bool upgradeable;
        address implementation; // may be an out-of-date value, if upgradeable (handled by getProxyConfig)
        bytes trailingData;
    }

    uint256 private reentrancyLock;

    address public upgradeAdmin;
    address public implementation;
    mapping(address proxy => ProxyConfig) public proxyLookup;
    address[] public proxyList;

    // Events

    event Genesis();

    event ProxyCreated(address indexed proxy, bool upgradeable, address implementation, bytes trailingData);

    event SetImplementation(address indexed newImplementation);
    event SetUpgradeAdmin(address indexed newUpgradeAdmin);

    // Errors

    error E_Reentrancy();
    error E_Unauthorized();
    error E_Implementation();
    error E_BadAddress();
    error E_BadQuery();

    // Modifiers

    modifier nonReentrant() {
        if (reentrancyLock == REENTRANCYLOCK__LOCKED) revert E_Reentrancy();

        reentrancyLock = REENTRANCYLOCK__LOCKED;
        _;
        reentrancyLock = REENTRANCYLOCK__UNLOCKED;
    }

    modifier adminOnly() {
        if (msg.sender != upgradeAdmin) revert E_Unauthorized();
        _;
    }

    constructor(address admin) {
        emit Genesis();

        reentrancyLock = REENTRANCYLOCK__UNLOCKED;

        upgradeAdmin = admin;

        emit SetUpgradeAdmin(admin);
    }

    function createProxy(bool upgradeable, bytes memory trailingData) external nonReentrant returns (address) {
        if (implementation == address(0)) revert E_Implementation();

        address proxy;

        if (upgradeable) {
            proxy = address(new BeaconProxy(trailingData));
        } else {
            proxy = deployMetaProxy(implementation, trailingData);
        }

        proxyLookup[proxy] =
            ProxyConfig({upgradeable: upgradeable, implementation: implementation, trailingData: trailingData});

        proxyList.push(proxy);

        IComponent(proxy).initialize(msg.sender);

        emit ProxyCreated(proxy, upgradeable, implementation, trailingData);

        return proxy;
    }

    // EVault beacon upgrade

    function setImplementation(address newImplementation) external nonReentrant adminOnly {
        if (newImplementation == address(0)) revert E_BadAddress();
        implementation = newImplementation;
        emit SetImplementation(newImplementation);
    }

    // Admin role

    function setUpgradeAdmin(address newUpgradeAdmin) external nonReentrant adminOnly {
        if (newUpgradeAdmin == address(0)) revert E_BadAddress();
        upgradeAdmin = newUpgradeAdmin;
        emit SetUpgradeAdmin(newUpgradeAdmin);
    }

    // Proxy getters

    function getProxyConfig(address proxy) external view returns (ProxyConfig memory config) {
        config = proxyLookup[proxy];
        if (config.upgradeable) config.implementation = implementation;
    }

    function isProxy(address proxy) external view returns (bool) {
        return proxyLookup[proxy].implementation != address(0);
    }

    function getProxyListLength() external view returns (uint256) {
        return proxyList.length;
    }

    function getProxyListSlice(uint256 start, uint256 end) external view returns (address[] memory list) {
        if (end == type(uint256).max) end = proxyList.length;
        if (end < start || end > proxyList.length) revert E_BadQuery();

        list = new address[](end - start);
        for (uint256 i; i < end - start; ++i) {
            list[i] = proxyList[start + i];
        }
    }
}
