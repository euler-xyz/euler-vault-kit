// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "./BaseProductLine.sol";
import "../EVault/shared/Constants.sol";

/// @notice Contract deploying EVaults, forming the `Escrow` product line, which are non-upgradeable
/// non-governed, don't allow borrowing and only allow one instance per asset.
contract Escrow is BaseProductLine {
    // Constants

    bool public constant UPGRADEABLE = false;

    // State

    mapping(address asset => address vault) public assetLookup;

    // Errors

    error E_AlreadyCreated();

    // Interface

    constructor(address vaultFactory_, address evc_) BaseProductLine(vaultFactory_, evc_) {}

    function createVault(bytes32 salt, address asset) external returns (address) {
        if (assetLookup[asset] != address(0)) revert E_AlreadyCreated();

        IEVault vault = makeNewVaultInternal(UPGRADEABLE, salt, asset, address(0), address(0));

        assetLookup[asset] = address(vault);

        vault.setName(string.concat("Escrow vault: ", getTokenName(asset)));
        vault.setSymbol(string.concat("e", getTokenSymbol(asset)));

        // Disable borrowing operations
        vault.setHookConfig(
            address(0),
            OP_BORROW | OP_REPAY | OP_LOOP | OP_DELOOP | OP_PULL_DEBT | OP_CONVERT_FEES | OP_LIQUIDATE | OP_TOUCH
        );

        // Renounce governorship
        vault.setGovernorAdmin(address(0));

        return address(vault);
    }
}
