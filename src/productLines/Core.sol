// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "./BaseProductLine.sol";

/// @notice Contract deploying EVaults, forming the `Core` product line, which are upgradeable and fully governed.
contract Core is BaseProductLine {
    // Constants

    bool public constant UPGRADEABLE = true;

    // State

    address public governor;
    address public feeReceiver;
    address public oracle;
    address public unitOfAccount;

    // Errors

    error E_Unauthorized();

    // Interface

    constructor(address vaultFactory_, address evc_, address governor_, address feeReceiver_, address oracle_, address unitOfAccount_) BaseProductLine(vaultFactory_, evc_) {
        governor = governor_;
        feeReceiver = feeReceiver_;

        oracle = oracle_;
        unitOfAccount = unitOfAccount_;
    }

    modifier governorOnly() {
        if (msg.sender != governor) revert E_Unauthorized();
        _;
    }

    function createVault(address asset) external governorOnly returns (address) {
        IEVault vault = makeNewVaultInternal(asset, UPGRADEABLE, oracle, unitOfAccount);

        vault.setName(string.concat("Core vault: ", getTokenName(asset)));
        vault.setSymbol(string.concat("e", getTokenSymbol(asset)));

        vault.setFeeReceiver(governor);
        vault.setGovernorAdmin(governor);

        return address(vault);
    }
}
