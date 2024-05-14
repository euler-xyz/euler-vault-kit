// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BeaconProxy} from "./BeaconProxy.sol";
import {MetaProxyDeployer} from "./MetaProxyDeployer.sol";

import {Create2} from "openzeppelin-contracts/utils/Create2.sol";

import "forge-std/Test.sol";

interface IComponent {
    function initialize(address creator) external;
}

contract GenericFactory is MetaProxyDeployer {
    // Constants

    uint256 internal constant REENTRANCYLOCK__UNLOCKED = 1;
    uint256 internal constant REENTRANCYLOCK__LOCKED = 2;

    // State

    struct ProxyConfig {
        bool upgradeable;
        address implementation; // may be an out-of-date value, if upgradeable (handled by getProxyConfig)
        bytes trailingData;
    }

    uint256 private reentrancyLock;

    mapping(address proxy => ProxyConfig) internal proxyLookup;

    address public upgradeAdmin;
    address public implementation;
    address[] public proxyList;

    // Events

    event Genesis();

    event ProxyCreated(
        address indexed proxy,
        bool upgradeable,
        address implementation,
        bytes trailingData,
        address sender,
        bytes32 userSalt
    );

    event SetImplementation(address indexed newImplementation);
    event SetUpgradeAdmin(address indexed newUpgradeAdmin);

    // Errors

    error E_Reentrancy();
    error E_Unauthorized();
    error E_Implementation();
    error E_BadAddress();
    error E_BadQuery();
    error E_SaltAlreadyUsed();

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

        if (admin == address(0)) revert E_BadAddress();

        reentrancyLock = REENTRANCYLOCK__UNLOCKED;

        upgradeAdmin = admin;

        emit SetUpgradeAdmin(admin);
    }

    function createProxy(address desiredImplementation, bytes32 salt, bool upgradeable, bytes memory trailingData)
        external
        nonReentrant
        returns (address)
    {
        address _implementation = implementation;
        if (desiredImplementation == address(0)) desiredImplementation = _implementation;
        if (desiredImplementation == address(0) || desiredImplementation != _implementation) revert E_Implementation();

        if (
            proxyLookup[computeProxyAddress(desiredImplementation, msg.sender, salt, upgradeable, trailingData)]
                .implementation != address(0)
        ) revert E_SaltAlreadyUsed();

        // namespace sender's deployments
        bytes32 namespacedSalt = getNamespacedSalt(msg.sender, salt, upgradeable);

        address proxy;
        if (upgradeable) {
            proxy = address(new BeaconProxy{salt: namespacedSalt}(trailingData));
        } else {
            proxy = deployMetaProxy(desiredImplementation, namespacedSalt, trailingData);
        }

        proxyLookup[proxy] =
            ProxyConfig({upgradeable: upgradeable, implementation: desiredImplementation, trailingData: trailingData});

        proxyList.push(proxy);

        IComponent(proxy).initialize(msg.sender);

        emit ProxyCreated(proxy, upgradeable, desiredImplementation, trailingData, msg.sender, salt);

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

    /// @notice Compute and address of the proxy given requested parameters
    /// @param metaProxyTarget Address of the implementation contract. Only relevant for upgradeable proxies, ignored otherwise
    /// @param sender Address of the caller
    /// @param userSalt Salt provided by the user
    /// @param upgradeable Type of the proxy: meta proxy if true
    /// @param trailingData Metadata the proxy will be deployed with
    /// @return Computed address of the proxy
    function computeProxyAddress(
        address metaProxyTarget,
        address sender,
        bytes32 userSalt,
        bool upgradeable,
        bytes memory trailingData
    ) public view returns (address) {
        return upgradeable
            ? computeBeaconProxyAddress(getNamespacedSalt(sender, userSalt, upgradeable), trailingData)
            : computeMetaProxyAddress(getNamespacedSalt(sender, userSalt, upgradeable), metaProxyTarget, trailingData);
    }

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

    // Internal functions

    function getNamespacedSalt(address sender, bytes32 userSalt, bool upgradeable) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(sender, userSalt, upgradeable));
    }

    function computeBeaconProxyAddress(bytes32 salt, bytes memory trailingData) private view returns (address) {
        return Create2.computeAddress(salt, keccak256(abi.encodePacked(type(BeaconProxy).creationCode, abi.encode(trailingData))));
    }
}
