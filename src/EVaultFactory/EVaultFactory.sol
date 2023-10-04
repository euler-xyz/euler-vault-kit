// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import { EVaultProxy } from "./EVaultProxy.sol";
import { EVault } from "../EVault/EVault.sol";
import { IERC20 } from "../EVault/IEVault.sol";
import { IRiskManager } from "../IRiskManager.sol";

contract EVaultFactory {

    // Constants

    string public constant name = "Euler EVault Factory";
    uint constant REENTRANCYLOCK__UNLOCKED = 1;
    uint constant REENTRANCYLOCK__LOCKED = 2;

    // State

    struct EVaultConfig {
        address riskManager;
        address asset;
    }

    uint reentrancyLock;

    address upgradeAdmin;
    address governorAdmin;
    address protocolFeesHolder;

    address eVaultImplementation;

    mapping(address eVault => EVaultConfig) eVaultLookup;
    address[] eVaultsList;

    // Events

    event Genesis();

    event EVaultCreated(address indexed eVault, address indexed asset, address indexed riskManager);

    event SetEVaultImplementation(address indexed newImplementation);
    event SetUpgradeAdmin(address indexed newUpgradeAdmin);
    event SetGovernorAdmin(address indexed newGovernorAdmin);
    event SetProtocolFeesHolder(address indexed newProtocolFeesHolder);

    // Errors

    error E_Reentrancy();
    error E_Unauthorized();
    error E_InvalidAsset();
    error E_Implementation();
    error E_BadAddress();
    error E_RiskManagerHook();
    error E_List();

    // Modifiers

    modifier nonReentrant() {
        if (reentrancyLock != REENTRANCYLOCK__UNLOCKED) revert E_Reentrancy();

        reentrancyLock = REENTRANCYLOCK__LOCKED;
        _;
        reentrancyLock = REENTRANCYLOCK__UNLOCKED;
    }

    modifier adminOnly {
        if (msg.sender != upgradeAdmin) revert E_Unauthorized();
        _;
    }

    modifier governorOnly {
        if (msg.sender != governorAdmin) revert E_Unauthorized();
        _;
    }

    constructor(address admin) {
        emit Genesis();

        reentrancyLock = REENTRANCYLOCK__UNLOCKED;

        upgradeAdmin = admin;
        governorAdmin = admin;
        protocolFeesHolder = admin;

        emit SetUpgradeAdmin(admin);
        emit SetGovernorAdmin(admin);
        emit SetProtocolFeesHolder(admin);
    }

    /// @notice Create an Euler EVault.
    /// @param asset The address of an ERC20-compliant token.
    /// @param riskManager The address of the risk manager contract to be used when borrowing from the market.
    /// @param riskManagerConfig Optional data for risk manager.
    /// @return The new EVault address.
    function activateMarket(address asset, address riskManager, bytes memory riskManagerConfig) external nonReentrant returns (address) {
        if (asset == address(this) || asset == address(0)) revert E_InvalidAsset();
        if (eVaultImplementation == address(0)) revert E_Implementation();

        // Deploy and initialize the vault

        address proxy = address(new EVaultProxy(asset, riskManager));
        EVault(proxy).initialize();

        // Trigger risk manager hook

        bool success = IRiskManager(riskManager).onMarketActivation(msg.sender, proxy, asset, riskManagerConfig);
        if (!success) revert E_RiskManagerHook();

        // Register in storage

        eVaultLookup[proxy] = EVaultConfig({ asset: asset, riskManager: riskManager });
        eVaultsList.push(proxy);

        emit EVaultCreated(proxy, asset, riskManager);

        return proxy;
    }

    // EVault beacon and implementation upgrade

    function implementation() external view returns (address) {
        return eVaultImplementation;
    }

    function setEVaultImplementation(address newImplementation) external nonReentrant adminOnly {
        if (newImplementation == address(0)) revert E_BadAddress();
        eVaultImplementation = newImplementation;
        emit SetEVaultImplementation(newImplementation);
    }

    // Vault registry getters

    function getEVaultsListLength() external view returns (uint) {
        return eVaultsList.length;
    }

    function getEVaultsList(uint startIndex, uint numElements) external view returns (address[] memory list) {
        if (startIndex == 0 && numElements == type(uint).max) {
            list = eVaultsList;
        } else {
            if (startIndex + numElements > eVaultsList.length) revert E_List();

            list = new address[](numElements);
            for (uint i; i < numElements;) {
                list[i] = eVaultsList[startIndex + i];
                unchecked { ++i; }
            }
        }
    }

    function getEVaultConfig(address eVault) external view returns (address asset, address riskManager) {
        EVaultConfig memory config = eVaultLookup[eVault];
        return (config.asset, config.riskManager);
    }

    // Admin roles

    function setUpgradeAdmin(address newUpgradeAdmin) external nonReentrant adminOnly {
        if (newUpgradeAdmin == address(0)) revert E_BadAddress();
        upgradeAdmin = newUpgradeAdmin;
        emit SetUpgradeAdmin(newUpgradeAdmin);
    }

    function setGovernorAdmin(address newGovernorAdmin) external nonReentrant adminOnly {
        if (newGovernorAdmin == address(0)) revert E_BadAddress();
        governorAdmin = newGovernorAdmin;
        emit SetGovernorAdmin(newGovernorAdmin);
    }

    function setProtocolFeesHolder(address newProtocolFeesHolder) external nonReentrant governorOnly {
        if (newProtocolFeesHolder == address(0)) revert E_BadAddress();
        protocolFeesHolder = newProtocolFeesHolder;
        emit SetProtocolFeesHolder(newProtocolFeesHolder);
    }

    function getUpgradeAdmin() external view returns (address) {
        return upgradeAdmin;
    }

    function getGovernorAdmin() external view returns (address) {
        return governorAdmin;
    }

    function getProtocolFeesHolder() external view returns (address) {
        return protocolFeesHolder;
    }
}
