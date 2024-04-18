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
        address evc_,
        address vaultFactory_,
        address[] memory recognizedCollateralPerspectives_,
        bool thisPerspectiveRecognized_
    ) BasePerspective(evc_, vaultFactory_) {
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
        testProperty(vaultFactory.isProxy(vault), ERROR__NOT_FROM_FACTORY);

        // verify vault configuration at the factory level
        GenericFactory.ProxyConfig memory config = vaultFactory.getProxyConfig(vault);

        address asset = IEVault(vault).asset();
        address oracle = IEVault(vault).oracle();
        address unitOfAccount = IEVault(vault).unitOfAccount();
        testProperty(
            keccak256(config.trailingData) == keccak256(abi.encodePacked(asset, oracle, unitOfAccount)),
            ERROR__TRAILING_DATA
        );

        // cluster vaults must not be upgradeable
        testProperty(!config.upgradeable, ERROR__UPGRADABILITY);

        // TODO cluster vaults must have oracle and unit of account recognized
        testProperty(oracle == address(0), ERROR__ORACLE);
        testProperty(unitOfAccount == address(0), ERROR__UNIT_OF_ACCOUNT);

        // verify vault configuration at the governance level
        // cluster vaults must not have a governor admin
        testProperty(IEVault(vault).governorAdmin() == address(0), ERROR__GOVERNOR);

        // TODO cluster vaults must have a recognized interest rate model
        testProperty(IEVault(vault).interestRateModel() == address(0), ERROR__INTEREST_RATE_MODEL);

        {
            // cluster vaults must not have supply or borrow caps
            (uint32 supplyCap, uint32 borrowCap) = IEVault(vault).caps();
            testProperty(supplyCap == 0, ERROR__SUPPLY_CAP);
            testProperty(borrowCap == 0, ERROR__BORROW_CAP);

            // cluster vaults must not have a hook target nor any operations disabled
            (address hookTarget, uint32 hookedOps) = IEVault(vault).hookConfig();
            testProperty(hookTarget == address(0), ERROR__HOOK_TARGET);
            testProperty(hookedOps == 0, ERROR__HOOKED_OPS);
        }

        // cluster vaults must not have any config flags set
        testProperty(IEVault(vault).configFlags() == 0, ERROR__CONFIG_FLAGS);

        // TODO cluster vaults must have a specific name and symbol
        testProperty(
            keccak256(abi.encode(IEVault(vault).name()))
                == keccak256(abi.encode(string.concat("Escrow vault: ", getTokenName(asset)))),
            ERROR__NAME
        );

        testProperty(
            keccak256(abi.encode(IEVault(vault).symbol()))
                == keccak256(abi.encode(string.concat("e", getTokenSymbol(asset)))),
            ERROR__SYMBOL
        );

        // TODO cluster vaults must have collaterals set up
        address[] memory ltvList = IEVault(vault).LTVList();
        testProperty(ltvList.length > 0 && ltvList.length <= 10, ERROR__LTV_LENGTH);

        // cluster vaults must have recognized collaterals with LTV set in range
        for (uint256 i = 0; i < ltvList.length; ++i) {
            address collateral = ltvList[i];

            // TODO cluster vaults collaterals must have the LTV set in range
            uint16 borrowingLTV = IEVault(vault).borrowingLTV(collateral);
            uint16 liquidationLTV = IEVault(vault).liquidationLTV(collateral);
            testProperty(borrowingLTV == 0, ERROR__LTV_BORROW_CONFIG);
            testProperty(liquidationLTV == 0, ERROR__LTV_LIQUIDATION_CONFIG);

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

            testProperty(recognized, ERROR__LTV_COLLATERAL_NOT_RECOGNIZED);
        }
    }
}
