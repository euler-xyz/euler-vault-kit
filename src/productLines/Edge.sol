// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "./BaseProductLine.sol";

contract Edge is BaseProductLine {
    // Constants

    bool public constant UPGRADEABLE = false;

    // Interface

    constructor(address vaultFactory_) BaseProductLine(vaultFactory_) {
    }

    struct Collateral {
        address vault;
        uint16 ltv;
    }

    struct CreateVaultParams {
        string name;
        // FIXME: IRM (address, or linear kink params and have it deploy a new IRM?)
        // FIXME: oracle, unit of account
        // FIXME: caps(?), debt socialisation, interestFee

        Collateral[] collaterals;

        address feeReceiver;
    }

    function createVault(address asset, CreateVaultParams calldata params) external returns (address) {
        IEVault vault = makeNewVaultInternal(asset, UPGRADEABLE);

        vault.setName(string.concat(params.name, " (", getTokenName(asset), " vault)"));
        vault.setSymbol(string.concat("e", getTokenSymbol(asset)));

        for (uint i; i < params.collaterals.length; ++i) {
            vault.setLTV(params.collaterals[i].vault, params.collaterals[i].ltv, 0);
        }

        vault.setFeeReceiver(params.feeReceiver);

        // Renounce governorship
        vault.setGovernorAdmin(address(0));

        return address(vault);
    }
}
