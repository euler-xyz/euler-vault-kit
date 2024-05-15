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

    // Errors

    error E_Unauthorized();

    // Interface

    constructor(address vaultFactory_, address evc_, address governor_, address feeReceiver_)
        BaseProductLine(vaultFactory_, evc_)
    {
        governor = governor_;
        feeReceiver = feeReceiver_;
    }

    modifier governorOnly() {
        if (msg.sender != governor) revert E_Unauthorized();
        _;
    }

    function createVault(address asset, address oracle, address unitOfAccount)
        external
        governorOnly
        returns (address)
    {
        IEVault vault = makeNewVaultInternal(UPGRADEABLE, asset, oracle, unitOfAccount);

        vault.setFeeReceiver(feeReceiver);
        vault.setGovernorAdmin(governor);

        return address(vault);
    }
}
