// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EnumerableSet} from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";
import {IEVault} from "../EVault/IEVault.sol";
import {GenericFactory} from "../GenericFactory/GenericFactory.sol";
import {BasePerspective} from "./BasePerspective.sol";

import "../EVault/shared/Constants.sol";

contract EscrowPerspective is BasePerspective {
    using EnumerableSet for EnumerableSet.AddressSet;

    mapping(address => address) public assetLookup;

    constructor(address vaultFactory_) BasePerspective(vaultFactory_) {}

    function perspectiveVerifyInternal(address vault) internal override {
        // the vault must be deployed by recognized factory
        if (!vaultFactory.isProxy(vault)) revertWithReason(vault, ERROR__NOT_FROM_FACTORY);

        // verify vault configuration at the factory level
        GenericFactory.ProxyConfig memory config = vaultFactory.getProxyConfig(vault);
        (address asset, address oracle, address unitOfAccount) =
            abi.decode(config.trailingData, (address, address, address));

        // escrow vaults must not be upgradeable
        if (config.upgradeable) revertWithReason(vault, ERROR__UPGRADABILITY);

        // there can be only one escrow vault per asset (singleton check)
        if (assetLookup[asset] != address(0)) revertWithReason(vault, ERROR__NOT_SINGLETON);

        // escrow vaults must not have an oracle or unit of account
        if (oracle != address(0)) revertWithReason(vault, ERROR__ORACLE);
        if (unitOfAccount != address(0)) revertWithReason(vault, ERROR__UNIT_OF_ACCOUNT);

        // verify vault configuration at the governance level.
        // escrow vaults must not have any collateral set up
        if (IEVault(vault).LTVList().length != 0) revertWithReason(vault, ERROR__LTV_LENGTH);

        // escrow vaults must not be nested
        if (!vaultFactory.isProxy(asset)) revertWithReason(vault, ERROR__NESTING);

        // escrow vaults must not have a governor admin, fee receiver, or interest rate model
        if (IEVault(vault).governorAdmin() != address(0)) revertWithReason(vault, ERROR__GOVERNOR);
        if (IEVault(vault).feeReceiver() != address(0)) revertWithReason(vault, ERROR__FEE_RECEIVER);
        if (IEVault(vault).interestRateModel() != address(0)) revertWithReason(vault, ERROR__INTEREST_RATE_MODEL);

        // escrow vaults must not have supply or borrow caps
        (uint32 supplyCap, uint32 borrowCap) = IEVault(vault).caps();
        if (supplyCap != 0) revertWithReason(vault, ERROR__SUPPLY_CAP);
        if (borrowCap != 0) revertWithReason(vault, ERROR__BORROW_CAP);

        // escrow vaults must not have a hook target
        (address hookTarget, uint32 hookedOps) = IEVault(vault).hookConfig();
        if (hookTarget != address(0)) revertWithReason(vault, ERROR__HOOK_TARGET);

        // escrow vaults must have certain operations disabled
        if (
            hookedOps
                != (OP_BORROW | OP_REPAY | OP_LOOP | OP_DELOOP | OP_PULL_DEBT | OP_CONVERT_FEES | OP_LIQUIDATE | OP_TOUCH)
        ) revertWithReason(vault, ERROR__HOOKED_OPS);

        // escrow vaults must not have any config flags set
        if (IEVault(vault).configFlags() != 0) revertWithReason(vault, ERROR__CONFIG_FLAGS);

        // escrow vaults must have a specific name and symbol
        // name: "Escrow vault: <asset name>"
        // symbol: "e<asset symbol>"
        if (
            keccak256(abi.encode(IEVault(vault).name()))
                != keccak256(abi.encode(string.concat("Escrow vault: ", getTokenName(asset))))
        ) revertWithReason(vault, ERROR__NAME);

        if (
            keccak256(abi.encode(IEVault(vault).symbol()))
                != keccak256(abi.encode(string.concat("e", getTokenSymbol(asset))))
        ) revertWithReason(vault, ERROR__SYMBOL);

        assetLookup[asset] = vault;
    }
}
