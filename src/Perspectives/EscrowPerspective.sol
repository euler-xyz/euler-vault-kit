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
        testProperty(vaultFactory.isProxy(vault), ERROR__NOT_FROM_FACTORY);

        // verify vault configuration at the factory level
        GenericFactory.ProxyConfig memory config = vaultFactory.getProxyConfig(vault);

        address asset = IEVault(vault).asset();
        testProperty(
            keccak256(config.trailingData) == keccak256(abi.encodePacked(asset, address(0), address(0))),
            ERROR__TRAILING_DATA
        );

        // escrow vaults must not be upgradeable
        testProperty(!config.upgradeable, ERROR__UPGRADABILITY);

        // there can be only one escrow vault per asset (singleton check)
        testProperty(assetLookup[asset] == address(0), ERROR__NOT_SINGLETON);

        // escrow vaults must not have an oracle or unit of account
        testProperty(IEVault(vault).oracle() == address(0), ERROR__ORACLE);
        testProperty(IEVault(vault).unitOfAccount() == address(0), ERROR__UNIT_OF_ACCOUNT);

        // escrow vaults must not be nested
        testProperty(!vaultFactory.isProxy(asset), ERROR__NESTING);

        // verify vault configuration at the governance level.
        // escrow vaults must not have a governor admin, fee receiver, or interest rate model
        testProperty(IEVault(vault).governorAdmin() == address(0), ERROR__GOVERNOR);
        testProperty(IEVault(vault).feeReceiver() == address(0), ERROR__FEE_RECEIVER);
        testProperty(IEVault(vault).interestRateModel() == address(0), ERROR__INTEREST_RATE_MODEL);

        {
            // escrow vaults must not have supply or borrow caps
            (uint32 supplyCap, uint32 borrowCap) = IEVault(vault).caps();
            testProperty(supplyCap == 0, ERROR__SUPPLY_CAP);
            testProperty(borrowCap == 0, ERROR__BORROW_CAP);

            // escrow vaults must not have a hook target
            (address hookTarget, uint32 hookedOps) = IEVault(vault).hookConfig();
            testProperty(hookTarget == address(0), ERROR__HOOK_TARGET);

            // escrow vaults must have certain operations disabled
            testProperty(
                hookedOps
                    == (
                        OP_BORROW | OP_REPAY | OP_LOOP | OP_DELOOP | OP_PULL_DEBT | OP_CONVERT_FEES | OP_LIQUIDATE
                            | OP_TOUCH
                    ),
                ERROR__HOOKED_OPS
            );
        }

        // escrow vaults must not have any config flags set
        testProperty(IEVault(vault).configFlags() == 0, ERROR__CONFIG_FLAGS);

        // escrow vaults must have a specific name and symbol
        // name: "Escrow vault: <asset name>"
        // symbol: "e<asset symbol>"
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

        // escrow vaults must not have any collateral set up
        testProperty(IEVault(vault).LTVList().length == 0, ERROR__LTV_LENGTH);

        assetLookup[asset] = vault;
    }
}
