// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EnumerableSet} from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";
import {IEVault} from "../EVault/IEVault.sol";
import {GenericFactory} from "../GenericFactory/GenericFactory.sol";
import {BasePerspective} from "./BasePerspective.sol";

import "../EVault/shared/Constants.sol";

contract EscrowPerspective is BasePerspective {
    using EnumerableSet for EnumerableSet.AddressSet;

    address[] public recognizedCollateralPerspectives;

    constructor(
        address vaultFactory_,
        address[] memory recognizedCollateralPerspectives_,
        bool thisPerspectiveRecognized_
    ) BasePerspective(vaultFactory_) {
        // TODO currently when checking if collaterals are recognized, we first check if the collateral is
        // recognized by the cluster perspective and only then check the recognized collateral perspectives.
        // it might be good to optimize this by checking the escrow perspective first (most likely scenario)
        if (thisPerspectiveRecognized_) recognizedCollateralPerspectives.push(address(this));

        for (uint256 i = 0; i < recognizedCollateralPerspectives_.length; ++i) {
            recognizedCollateralPerspectives.push(recognizedCollateralPerspectives_[i]);
        }
    }

    function perspectiveVerifyInternal(address vault) internal override {
        // the vault must be deployed by recognized factory
        if (!vaultFactory.isProxy(vault)) revertWithReason(vault, ERROR__NOT_FROM_FACTORY);

        // verify vault configuration at the factory level
        GenericFactory.ProxyConfig memory config = vaultFactory.getProxyConfig(vault);
        (address asset, address oracle, address unitOfAccount) =
            abi.decode(config.trailingData, (address, address, address));

        // cluster vaults must not be upgradeable
        if (config.upgradeable) revertWithReason(vault, ERROR__UPGRADABILITY);

        // TODO cluster vaults must have oracle and unit of account recognized
        if (oracle != address(0)) revertWithReason(vault, ERROR__ORACLE);
        if (unitOfAccount != address(0)) revertWithReason(vault, ERROR__UNIT_OF_ACCOUNT);

        // verify vault configuration at the governance level
        // TODO cluster vaults must have collaterals set up
        address[] memory ltvList = IEVault(vault).LTVList();
        if (ltvList.length == 0 || ltvList.length > 10) revertWithReason(vault, ERROR__LTV_LENGTH);

        // cluster vaults must not have a governor admin
        if (IEVault(vault).governorAdmin() != address(0)) revertWithReason(vault, ERROR__GOVERNOR);

        // TODO cluster vaults must have a recognized interest rate model
        if (IEVault(vault).interestRateModel() != address(0)) revertWithReason(vault, ERROR__INTEREST_RATE_MODEL);

        // cluster vaults must not have supply or borrow caps
        (uint32 supplyCap, uint32 borrowCap) = IEVault(vault).caps();
        if (supplyCap != 0) revertWithReason(vault, ERROR__SUPPLY_CAP);
        if (borrowCap != 0) revertWithReason(vault, ERROR__BORROW_CAP);

        // cluster vaults must not have a hook target nor any operations disabled
        (address hookTarget, uint32 hookedOps) = IEVault(vault).hookConfig();
        if (hookTarget != address(0)) revertWithReason(vault, ERROR__HOOK_TARGET);
        if (hookedOps != 0) revertWithReason(vault, ERROR__HOOKED_OPS);

        // cluster vaults must not have any config flags set
        if (IEVault(vault).configFlags() != 0) revertWithReason(vault, ERROR__CONFIG_FLAGS);

        // TODO cluster vaults must have a specific name and symbol
        //if (
        //    keccak256(abi.encode(IEVault(vault).name()))
        //        != keccak256(abi.encode(string.concat("Cluster vault: ", _getTokenName(asset))))
        //) revertWithReason(vault, ERROR__NAME);

        //if (
        //    keccak256(abi.encode(IEVault(vault).symbol()))
        //        != keccak256(abi.encode(string.concat("e", _getTokenSymbol(asset))))
        //) revertWithReason(vault, ERROR__SYMBOL);

        // cluster vaults must have recognized collaterals with LTV set in range
        for (uint256 i = 0; i < ltvList.length; ++i) {
            address collateral = ltvList[i];

            // TODO cluster vaults collaterals must have the LTV set in range
            uint16 borrowingLTV = IEVault(vault).borrowingLTV(collateral);
            uint16 liquidationLTV = IEVault(vault).liquidationLTV(collateral);
            if (borrowingLTV > 0 || liquidationLTV > 0) revertWithReason(collateral, ERROR__LTV_CONFIG);

            // iterate over recognized collateral perspectives to check if the collateral is recognized
            bool recognized = false;
            for (uint256 j = 0; j < recognizedCollateralPerspectives.length; ++j) {
                try BasePerspective(recognizedCollateralPerspectives[j]).perspectiveVerify(collateral) returns (
                    bool result
                ) {
                    recognized = result;
                } catch {}

                if (recognized) break;
            }

            if (!recognized) revertWithReason(collateral, ERROR__LTV_VAULT_NOT_RECOGNIZED);
        }
    }
}
