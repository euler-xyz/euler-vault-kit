// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EnumerableSet} from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";
import {IERC20} from "../EVault/IEVault.sol";
import {GenericFactory} from "../GenericFactory/GenericFactory.sol";
import {RevertBytes} from "../EVault/shared/lib/RevertBytes.sol";

abstract contract BasePerspective {
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 constant ERROR__NOT_FROM_FACTORY = 0;
    uint256 constant ERROR__UPGRADABILITY = 1;
    uint256 constant ERROR__NOT_SINGLETON = 2;
    uint256 constant ERROR__ORACLE = 3;
    uint256 constant ERROR__UNIT_OF_ACCOUNT = 4;
    uint256 constant ERROR__CREATOR = 5;
    uint256 constant ERROR__GOVERNOR = 6;
    uint256 constant ERROR__FEE_RECEIVER = 7;
    uint256 constant ERROR__INTEREST_RATE_MODEL = 8;
    uint256 constant ERROR__SUPPLY_CAP = 9;
    uint256 constant ERROR__BORROW_CAP = 10;
    uint256 constant ERROR__HOOK_TARGET = 11;
    uint256 constant ERROR__HOOKED_OPS = 12;
    uint256 constant ERROR__CONFIG_FLAGS = 13;
    uint256 constant ERROR__NAME = 14;
    uint256 constant ERROR__SYMBOL = 15;
    uint256 constant ERROR__LTV_LENGTH = 16;
    uint256 constant ERROR__LTV_CONFIG = 17;
    uint256 constant ERROR__LTV_VAULT = 18;

    GenericFactory internal immutable vaultFactory;
    EnumerableSet.AddressSet internal verified;

    error PerspectiveError(address perspective, address vault, uint256 code);

    constructor(address vaultFactory_) {
        vaultFactory = GenericFactory(vaultFactory_);
    }

    function perspectiveVerify(address vault) external virtual returns (bool) {}

    function isVerified(address vault) external view returns (bool) {
        return verified.contains(vault);
    }

    function verifiedLength() external view returns (uint256) {
        return verified.length();
    }

    function verifiedSet() external view returns (address[] memory) {
        return verified.values();
    }

    function revertWithReason(address vault, uint256 code) internal view {
        revert PerspectiveError(address(this), vault, code);
    }

    function getTokenName(address asset) internal view returns (string memory) {
        // Handle MKR like tokens returning bytes32
        (bool success, bytes memory data) = address(asset).staticcall(abi.encodeWithSelector(IERC20.name.selector));
        if (!success) RevertBytes.revertBytes(data);
        return data.length <= 32 ? string(data) : abi.decode(data, (string));
    }

    function getTokenSymbol(address asset) internal view returns (string memory) {
        // Handle MKR like tokens returning bytes32
        (bool success, bytes memory data) = address(asset).staticcall(abi.encodeWithSelector(IERC20.symbol.selector));
        if (!success) RevertBytes.revertBytes(data);
        return data.length <= 32 ? string(data) : abi.decode(data, (string));
    }
}
