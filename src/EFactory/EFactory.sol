// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BeaconProxy} from "./BeaconProxy.sol";
import {MetaProxyDeployer} from "./MetaProxyDeployer.sol";

interface IComponent {
    function initialize(address creator) external;
}

contract EFactory is MetaProxyDeployer {
    // Constants

    uint256 constant REENTRANCYLOCK__UNLOCKED = 1;
    uint256 constant REENTRANCYLOCK__LOCKED = 2;

    // State

    struct ProxyConfig {
        bool upgradeable;
        address implementation; // may be an out-of-date value, if upgradeable
        bytes trailingData;
    }

    uint256 private reentrancyLock;

    address public upgradeAdmin;
    address public implementation;
    address[] public proxyList;
    mapping(address proxy => ProxyConfig) proxyLookup;

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
    error E_MetaProxy();

    // Modifiers

    modifier nonReentrant() {
        if (reentrancyLock != REENTRANCYLOCK__UNLOCKED) revert E_Reentrancy();

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

    function createProxy(bool upgradeable, bytes memory trailingData) external nonReentrant returns (address proxy) {
        if (implementation == address(0)) revert E_Implementation();

        if (upgradeable) {
            proxy = address(new BeaconProxy(trailingData));
        } else {
            proxy = deployMetaProxy(implementation, trailingData);
            if (proxy == address(0)) revert E_MetaProxy();
        }

        proxyLookup[proxy] =
            ProxyConfig({upgradeable: upgradeable, implementation: implementation, trailingData: trailingData});

        proxyList.push(proxy);

        IComponent(proxy).initialize(msg.sender);

        emit ProxyCreated(proxy, upgradeable, implementation, trailingData);
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

    function getProxyConfig(address proxy) external view returns (ProxyConfig memory) {
        ProxyConfig memory config = proxyLookup[proxy];
        return ProxyConfig({
            upgradeable: config.upgradeable,
            implementation: config.upgradeable ? implementation : config.implementation,
            trailingData: config.trailingData
        });
    }

    function isProxy(address proxy) external view returns (bool) {
        return proxyLookup[proxy].implementation != address(0);
    }

    function getProxyListLength() external view returns (uint256) {
        return proxyList.length;
    }

    function getProxyListRange(uint256 startIndex, uint256 numElements) external view returns (address[] memory list) {
        if (startIndex == 0 && numElements == type(uint256).max) {
            list = proxyList;
        } else {
            if (type(uint256).max - startIndex < numElements || startIndex + numElements > proxyList.length) {
                revert E_BadQuery();
            }

            list = new address[](numElements);
            for (uint256 i; i < numElements;) {
                list[i] = proxyList[startIndex + i];
                unchecked {
                    ++i;
                }
            }
        }
    }
}
