// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EnumerableSet} from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";
import {IEVault} from "../EVault/IEVault.sol";
import {GenericFactory} from "../GenericFactory/GenericFactory.sol";
import {BasePerspective} from "./BasePerspective.sol";

import "../EVault/shared/Constants.sol";

contract EscrowPerspective is BasePerspective {
    using EnumerableSet for EnumerableSet.AddressSet;

    address[] public recognizedPerspectives;

    constructor(address vaultFactory_, address[] memory recognizedPerspectives_) BasePerspective(vaultFactory_) {
        recognizedPerspectives = recognizedPerspectives_;
    }

    function perspectiveVerify(address vault) external override returns (bool) {
        // if already verified, return true
        if (verified.contains(vault)) return true;

        // check if deployed by recognized factory
        if (!vaultFactory.isProxy(vault)) revertWithReason(vault, ERROR__NOT_FROM_FACTORY);

        // verify vault configuration at the factory level
        GenericFactory.ProxyConfig memory config = vaultFactory.getProxyConfig(vault);
        (address asset, address oracle, address unitOfAccount) =
            abi.decode(config.trailingData, (address, address, address));

        // TODO
        if (config.upgradeable) revertWithReason(vault, ERROR__UPGRADABILITY);
        if (oracle != address(0)) revertWithReason(vault, ERROR__ORACLE);
        if (unitOfAccount != address(0)) revertWithReason(vault, ERROR__UNIT_OF_ACCOUNT);

        // verify vault configuration at the governance level
        if (IEVault(vault).governorAdmin() != address(0)) revertWithReason(vault, ERROR__GOVERNOR);

        // TODO
        //if (IEVault(vault).feeReceiver() != address(0)) revertWithReason(vault, ERROR__FEE_RECEIVER);
        if (IEVault(vault).interestRateModel() != address(0)) revertWithReason(vault, ERROR__INTEREST_RATE_MODEL);

        (uint32 supplyCap, uint32 borrowCap) = IEVault(vault).caps();
        if (supplyCap != 0) revertWithReason(vault, ERROR__SUPPLY_CAP);
        if (borrowCap != 0) revertWithReason(vault, ERROR__BORROW_CAP);

        (address hookTarget, uint32 hookedOps) = IEVault(vault).hookConfig();
        if (hookTarget != address(0)) revertWithReason(vault, ERROR__HOOK_TARGET);
        if (hookedOps != 0) revertWithReason(vault, ERROR__HOOKED_OPS);

        if (IEVault(vault).configFlags() != 0) revertWithReason(vault, ERROR__CONFIG_FLAGS);

        //if (
        //    keccak256(abi.encode(IEVault(vault).name()))
        //        != keccak256(abi.encode(string.concat("Cluster vault: ", getTokenName(asset))))
        //) revertWithReason(vault, ERROR__NAME);

        //if (
        //    keccak256(abi.encode(IEVault(vault).symbol()))
        //        != keccak256(abi.encode(string.concat("e", getTokenSymbol(asset))))
        //) revertWithReason(vault, ERROR__SYMBOL);

        // TODO
        address[] memory ltvList = IEVault(vault).LTVList();
        if (ltvList.length == 0 || ltvList.length > 10) revertWithReason(vault, ERROR__LTV_LENGTH);

        // optimistically assume that the vault is valid
        verified.add(vault);

        for (uint256 i = 0; i < ltvList.length; ++i) {
            address collateral = ltvList[i];

            // TODO the LTV must be in range
            uint16 borrowingLTV = IEVault(vault).borrowingLTV(collateral);
            uint16 liquidationLTV = IEVault(vault).liquidationLTV(collateral);
            if (borrowingLTV > 0 || liquidationLTV > 0) revertWithReason(vault, ERROR__LTV_CONFIG);

            bool recognized = false;
            try BasePerspective(address(this)).perspectiveVerify(collateral) returns (bool result) {
                if (result) recognized = true;
            } catch {}

            if (!recognized) {
                for (uint256 j = 0; j < recognizedPerspectives.length; ++j) {
                    try BasePerspective(recognizedPerspectives[j]).perspectiveVerify(collateral) returns (bool result) {
                        if (result) recognized = true;
                    } catch {}

                    if (recognized) break;
                }
            }

            if (!recognized) revertWithReason(collateral, ERROR__LTV_VAULT);
        }

        return true;
    }
}
