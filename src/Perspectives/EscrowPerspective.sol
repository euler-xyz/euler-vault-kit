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

    function perspectiveVerifyInternal(address vault, bool failEarly) internal override {
        // the vault must be deployed by recognized factory
        testProperty(vaultFactory.isProxy(vault), vault, ERROR__NOT_FROM_FACTORY, failEarly);

        // verify vault configuration at the factory level
        GenericFactory.ProxyConfig memory config = vaultFactory.getProxyConfig(vault);

        address asset = IEVault(vault).asset();
        testProperty(
            keccak256(config.trailingData) == keccak256(abi.encodePacked(asset, address(0), address(0))),
            vault,
            ERROR__TRAILING_DATA,
            failEarly
        );

        // escrow vaults must not be upgradeable
        testProperty(!config.upgradeable, vault, ERROR__UPGRADABILITY, failEarly);

        // there can be only one escrow vault per asset (singleton check)
        testProperty(assetLookup[asset] == address(0), vault, ERROR__NOT_SINGLETON, failEarly);

        // escrow vaults must not have an oracle or unit of account
        testProperty(IEVault(vault).oracle() == address(0), vault, ERROR__ORACLE, failEarly);
        testProperty(IEVault(vault).unitOfAccount() == address(0), vault, ERROR__UNIT_OF_ACCOUNT, failEarly);

        // escrow vaults must not be nested
        testProperty(!vaultFactory.isProxy(asset), vault, ERROR__NESTING, failEarly);

        // verify vault configuration at the governance level.
        // escrow vaults must not have a governor admin, fee receiver, or interest rate model
        testProperty(IEVault(vault).governorAdmin() == address(0), vault, ERROR__GOVERNOR, failEarly);
        testProperty(IEVault(vault).feeReceiver() == address(0), vault, ERROR__FEE_RECEIVER, failEarly);
        testProperty(IEVault(vault).interestRateModel() == address(0), vault, ERROR__INTEREST_RATE_MODEL, failEarly);

        {
            // escrow vaults must not have supply or borrow caps
            (uint32 supplyCap, uint32 borrowCap) = IEVault(vault).caps();
            testProperty(supplyCap == 0, vault, ERROR__SUPPLY_CAP, failEarly);
            testProperty(borrowCap == 0, vault, ERROR__BORROW_CAP, failEarly);

            // escrow vaults must not have a hook target
            (address hookTarget, uint32 hookedOps) = IEVault(vault).hookConfig();
            testProperty(hookTarget == address(0), vault, ERROR__HOOK_TARGET, failEarly);

            // escrow vaults must have certain operations disabled
            testProperty(
                hookedOps
                    == (
                        OP_BORROW | OP_REPAY | OP_LOOP | OP_DELOOP | OP_PULL_DEBT | OP_CONVERT_FEES | OP_LIQUIDATE
                            | OP_TOUCH
                    ),
                vault,
                ERROR__HOOKED_OPS,
                failEarly
            );
        }

        // escrow vaults must not have any config flags set
        testProperty(IEVault(vault).configFlags() == 0, vault, ERROR__CONFIG_FLAGS, failEarly);

        // escrow vaults must have a specific name and symbol
        // name: "Escrow vault: <asset name>"
        // symbol: "e<asset symbol>"
        testProperty(
            keccak256(abi.encode(IEVault(vault).name()))
                == keccak256(abi.encode(string.concat("Escrow vault: ", getTokenName(asset)))),
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

        // escrow vaults must not have any collateral set up
        testProperty(IEVault(vault).LTVList().length == 0, vault, ERROR__LTV_LENGTH, failEarly);

        assetLookup[asset] = vault;
    }
}
