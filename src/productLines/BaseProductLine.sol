// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IERC20, IEVault} from "../EVault/IEVault.sol";
import {GenericFactory} from "../GenericFactory/GenericFactory.sol";
import {RevertBytes} from "../EVault/shared/lib/RevertBytes.sol";

abstract contract BaseProductLine {
    // Constants

    uint256 constant REENTRANCYLOCK__UNLOCKED = 1;
    uint256 constant REENTRANCYLOCK__LOCKED = 2;

    address public immutable vaultFactory;

    // State

    uint256 private reentrancyLock;

    mapping(address vault => bool created) public vaultLookup;
    address[] public vaultList;

    // Events

    event Genesis();
    event VaultCreated(address indexed vault, address indexed asset, bool upgradeable);

    // Errors

    error E_Reentrancy();
    error E_BadQuery();

    // Modifiers

    modifier nonReentrant() {
        if (reentrancyLock != REENTRANCYLOCK__UNLOCKED) revert E_Reentrancy();

        reentrancyLock = REENTRANCYLOCK__LOCKED;
        _;
        reentrancyLock = REENTRANCYLOCK__UNLOCKED;
    }

    // Interface

    constructor(address vaultFactory_) {
        vaultFactory = vaultFactory_;

        emit Genesis();
    }

    function makeNewVaultInternal(address asset, bool upgradeable) internal returns (IEVault) {
        address newVault = GenericFactory(vaultFactory).createProxy(upgradeable, abi.encodePacked(asset));

        vaultLookup[newVault] = true;
        vaultList.push(newVault);

        emit VaultCreated(newVault, asset, upgradeable);

        return IEVault(newVault);
    }

    function getTokenName(address asset) internal view returns (string memory) {
        // Handle MKR like tokens returning bytes32
        (bool success, bytes memory data) = address(asset).staticcall(abi.encodeWithSelector(IERC20.name.selector));
        if (!success) RevertBytes.revertBytes(data);
        return data.length == 32 ? string(data) : abi.decode(data, (string));
    }

    function getTokenSymbol(address asset) internal view returns (string memory) {
        // Handle MKR like tokens returning bytes32
        (bool success, bytes memory data) = address(asset).staticcall(abi.encodeWithSelector(IERC20.symbol.selector));
        if (!success) RevertBytes.revertBytes(data);
        return data.length == 32 ? string(data) : abi.decode(data, (string));
    }

    // Getters

    function getVaultListLength() external view returns (uint256) {
        return vaultList.length;
    }

    function getVaultListSlice(uint256 start, uint256 end) external view returns (address[] memory list) {
        if (end == type(uint256).max) end = vaultList.length;
        if (end < start || end > vaultList.length) revert E_BadQuery();

        list = new address[](end - start);
        for (uint256 i; i < end - start; ++i) {
            list[i] = vaultList[start + i];
        }
    }
}
