// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "./BaseProductLine.sol";
import "../EVault/shared/Constants.sol";

contract Escrow is BaseProductLine {
    // Constants

    bool public constant UPGRADEABLE = false;

    // State

    mapping(address asset => address vault) public assetLookup;

    // Errors

    error E_AlreadyCreated();

    // Interface

    constructor(address vaultFactory_) BaseProductLine(vaultFactory_) {
    }

    function createVault(address asset) external returns (address) {
        if (assetLookup[asset] != address(0)) revert E_AlreadyCreated();

        IEVault vault = makeNewVaultInternal(asset, UPGRADEABLE);

        assetLookup[asset] = address(vault);

        vault.setName(string.concat("Escrow vault: ", getTokenName(asset)));
        vault.setSymbol(string.concat("e", getTokenSymbol(asset)));

        vault.setMarketPolicy(OP_BORROW | OP_REPAY | OP_WIND | OP_UNWIND | OP_PULL_DEBT | OP_CONVERT_FEES | OP_LIQUIDATE | OP_TOUCH, 0, 0);

        // Renounce governorship
        vault.setGovernorAdmin(address(0));

        return address(vault);
    }
}
