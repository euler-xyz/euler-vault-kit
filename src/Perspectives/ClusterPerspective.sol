// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EnumerableSet} from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";
import {IEVault} from "../EVault/IEVault.sol";
import {GenericFactory} from "../GenericFactory/GenericFactory.sol";
import {BasePerspective} from "./BasePerspective.sol";

import "../EVault/shared/Constants.sol";

contract ClusterPerspective is BasePerspective {
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

    function perspectiveVerifyInternal(address vault, bool failEarly) internal override {
        // the vault must be deployed by recognized factory
        testProperty(vaultFactory.isProxy(vault), vault, ERROR__NOT_FROM_FACTORY, failEarly);

        // verify vault configuration at the factory level
        GenericFactory.ProxyConfig memory config = vaultFactory.getProxyConfig(vault);

        address asset = IEVault(vault).asset();
        address oracle = IEVault(vault).oracle();
        address unitOfAccount = IEVault(vault).unitOfAccount();

        testProperty(
            keccak256(config.trailingData) == keccak256(abi.encodePacked(asset, oracle, unitOfAccount)),
            vault,
            ERROR__TRAILING_DATA,
            failEarly
        );

        // cluster vaults must not be upgradeable
        testProperty(!config.upgradeable, vault, ERROR__UPGRADABILITY, failEarly);

        // TODO cluster vaults must have oracle and unit of account recognized
        testProperty(oracle == address(1), vault, ERROR__ORACLE, failEarly);
        testProperty(unitOfAccount == address(2), vault, ERROR__UNIT_OF_ACCOUNT, failEarly);

        // verify vault configuration at the governance level
        // cluster vaults must not have a governor admin
        testProperty(IEVault(vault).governorAdmin() == address(0), vault, ERROR__GOVERNOR, failEarly);

        // TODO cluster vaults must have a recognized interest rate model
        testProperty(IEVault(vault).interestRateModel() == address(0), vault, ERROR__INTEREST_RATE_MODEL, failEarly);

        {
            // cluster vaults must not have supply or borrow caps
            (uint32 supplyCap, uint32 borrowCap) = IEVault(vault).caps();
            testProperty(supplyCap == 0, vault, ERROR__SUPPLY_CAP, failEarly);
            testProperty(borrowCap == 0, vault, ERROR__BORROW_CAP, failEarly);

            // cluster vaults must not have a hook target nor any operations disabled
            (address hookTarget, uint32 hookedOps) = IEVault(vault).hookConfig();
            testProperty(hookTarget == address(0), vault, ERROR__HOOK_TARGET, failEarly);
            testProperty(hookedOps == 0, vault, ERROR__HOOKED_OPS, failEarly);
        }

        // cluster vaults must not have any config flags set
        testProperty(IEVault(vault).configFlags() == 0, vault, ERROR__CONFIG_FLAGS, failEarly);

        // TODO cluster vaults must have a specific name and symbol
        testProperty(
            keccak256(abi.encode(IEVault(vault).name()))
                == keccak256(abi.encode(string.concat("Cluster vault: ", getTokenName(asset)))),
            vault,
            ERROR__NAME,
            failEarly
        );

        testProperty(
            keccak256(abi.encode(IEVault(vault).symbol()))
                == keccak256(abi.encode(string.concat("e", getTokenSymbol(asset)))),
            vault,
            ERROR__SYMBOL,
            failEarly
        );

        // TODO cluster vaults must have collaterals set up
        address[] memory ltvList = IEVault(vault).LTVList();
        testProperty(ltvList.length > 0 && ltvList.length <= 10, vault, ERROR__LTV_LENGTH, failEarly);

        // cluster vaults must have recognized collaterals with LTV set in range
        for (uint256 i = 0; i < ltvList.length; ++i) {
            address collateral = ltvList[i];

            // TODO cluster vaults collaterals must have the LTV set in range
            uint16 borrowingLTV = IEVault(vault).borrowingLTV(collateral);
            uint16 liquidationLTV = IEVault(vault).liquidationLTV(collateral);
            testProperty(borrowingLTV == 0, vault, ERROR__LTV_BORROW_CONFIG, failEarly);
            testProperty(liquidationLTV == 0, vault, ERROR__LTV_LIQUIDATION_CONFIG, failEarly);

            // iterate over recognized collateral perspectives to check if the collateral is recognized
            bool recognized = false;
            for (uint256 j = 0; j < recognizedCollateralPerspectives.length; ++j) {
                try BasePerspective(recognizedCollateralPerspectives[j]).perspectiveVerify(collateral, true) {
                    recognized = true;
                } catch {}

                if (recognized) break;
            }

            testProperty(recognized, vault, ERROR__LTV_COLLATERAL_NOT_RECOGNIZED, failEarly);
        }
    }
}
