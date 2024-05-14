// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IERC20, IEVault, IGovernance} from "../EVault/IEVault.sol";
import {GenericFactory} from "../GenericFactory/GenericFactory.sol";
import {RevertBytes} from "../EVault/shared/lib/RevertBytes.sol";

import "../EVault/shared/Constants.sol";

/// @notice Base contract for product line contracts, which deploy pre-configured EVaults through a GenericFactory
abstract contract BaseProductLine {
    // Constants

    uint256 constant REENTRANCYLOCK__UNLOCKED = 1;
    uint256 constant REENTRANCYLOCK__LOCKED = 2;

    address public immutable vaultFactory;
    address public immutable evc;

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
        if (reentrancyLock == REENTRANCYLOCK__LOCKED) revert E_Reentrancy();

        reentrancyLock = REENTRANCYLOCK__LOCKED;
        _;
        reentrancyLock = REENTRANCYLOCK__UNLOCKED;
    }

    // Interface

    constructor(address vaultFactory_, address evc_) {
        vaultFactory = vaultFactory_;
        evc = evc_;

        reentrancyLock = REENTRANCYLOCK__UNLOCKED;

        emit Genesis();
    }

    function makeNewVaultInternal(bool upgradeable, bytes32 salt, address asset, address oracle, address unitOfAccount)
        internal
        returns (IEVault)
    {
        address newVault = GenericFactory(vaultFactory).createProxy(
            address(0), salt, upgradeable, abi.encodePacked(asset, oracle, unitOfAccount)
        );

        vaultLookup[newVault] = true;
        vaultList.push(newVault);

        if (isEVCCompatible(asset)) {
            uint32 flags = IEVault(newVault).configFlags();
            IEVault(newVault).setConfigFlags(flags | CFG_EVC_COMPATIBLE_ASSET);
        }

        emit VaultCreated(newVault, asset, upgradeable);

        return IEVault(newVault);
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

    function getTokenName(address asset) internal view returns (string memory) {
        // Handle MKR like tokens returning bytes32
        (bool success, bytes memory data) = address(asset).staticcall(abi.encodeWithSelector(IERC20.name.selector));
        if (!success) RevertBytes.revertBytes(data);
        return data.length <= 32 ? string(data) : abi.decode(data, (string));
    }

    function getTokenSymbol(address asset) internal view returns (string memory) {
        // Handle MKR like tokens returning bytes32
        (bool success, bytes memory data) = address(asset).staticcall(abi.encodeWithSelector(IERC20.symbol.selector));
        if (!success) RevertBytes.revertBytes(data);
        return data.length <= 32 ? string(data) : abi.decode(data, (string));
    }

    function isEVCCompatible(address asset) private view returns (bool) {
        (bool success, bytes memory data) = asset.staticcall(abi.encodeCall(IGovernance.EVC, ()));
        return success && data.length >= 32 && abi.decode(data, (address)) == address(evc);
    }
}
