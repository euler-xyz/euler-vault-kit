// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "./BaseProductLine.sol";

contract Core is BaseProductLine {
    // Constants

    bool public constant UPGRADEABLE = true;

    // State

    address public governor;

    // Errors

    error E_Unauthorized();

    // Interface

    constructor(address vaultFactory_, address governor_) BaseProductLine(vaultFactory_) {
        governor_ = governor;
    }

    modifier governorOnly() {
        if (msg.sender != governor) revert E_Unauthorized();
        _;
    }

    function createVault(address asset) external governorOnly returns (address) {
        IEVault vault = makeNewVaultInternal(asset, UPGRADEABLE);

        vault.setName(string.concat("Core vault: ", getTokenName(asset)));
        vault.setSymbol(string.concat("e", getTokenSymbol(asset)));

        // FIXME: use different addresses for the following
        vault.setFeeReceiver(governor);
        vault.setGovernorAdmin(governor);

        return address(vault);
    }
}
