// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EnumerableSet} from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";
import {IERC20} from "../EVault/IEVault.sol";
import {GenericFactory} from "../GenericFactory/GenericFactory.sol";
import {RevertBytes} from "../EVault/shared/lib/RevertBytes.sol";

abstract contract BasePerspective {
    using EnumerableSet for EnumerableSet.AddressSet;

    struct Transient {
        uint256 placeholder;
    }

    uint256 private constant NOT_VERIFIED = 0;
    uint256 private constant VERIFIED = 1;

    uint256 internal constant ERROR__NOT_FROM_FACTORY = 0;
    uint256 internal constant ERROR__UPGRADABILITY = 1;
    uint256 internal constant ERROR__NOT_SINGLETON = 2;
    uint256 internal constant ERROR__NESTING = 3;
    uint256 internal constant ERROR__ORACLE = 4;
    uint256 internal constant ERROR__UNIT_OF_ACCOUNT = 5;
    uint256 internal constant ERROR__CREATOR = 6;
    uint256 internal constant ERROR__GOVERNOR = 7;
    uint256 internal constant ERROR__FEE_RECEIVER = 8;
    uint256 internal constant ERROR__INTEREST_RATE_MODEL = 9;
    uint256 internal constant ERROR__SUPPLY_CAP = 10;
    uint256 internal constant ERROR__BORROW_CAP = 11;
    uint256 internal constant ERROR__HOOK_TARGET = 12;
    uint256 internal constant ERROR__HOOKED_OPS = 13;
    uint256 internal constant ERROR__CONFIG_FLAGS = 14;
    uint256 internal constant ERROR__NAME = 15;
    uint256 internal constant ERROR__SYMBOL = 16;
    uint256 internal constant ERROR__LTV_LENGTH = 17;
    uint256 internal constant ERROR__LTV_CONFIG = 18;
    uint256 internal constant ERROR__LTV_VAULT_NOT_RECOGNIZED = 19;

    GenericFactory internal immutable vaultFactory;
    EnumerableSet.AddressSet private verified;
    Transient private transientVerified;

    error PerspectiveError(address perspective, address vault, uint256 code);

    event PerspectiveVerified(address indexed vault);

    constructor(address vaultFactory_) {
        vaultFactory = GenericFactory(vaultFactory_);
    }

    function perspectiveVerify(address vault) external returns (bool) {
        // if already verified, return true
        if (_isVerified(vault)) return true;

        // optimistically assume that the vault is verified
        _setOptimisticallyVerified(vault);

        // this must revert if the vault is not compliant with the perspective
        perspectiveVerifyInternal(vault);

        // set the vault as permanently verified
        _setPermanentlyVerified(vault);

        return true;
    }

    function isVerified(address vault) external view returns (bool) {
        return verified.contains(vault);
    }

    function verifiedLength() external view returns (uint256) {
        return verified.length();
    }

    function verifiedArray() external view returns (address[] memory) {
        return verified.values();
    }

    function perspectiveVerifyInternal(address vault) internal virtual {}

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

    function _isVerified(address vault) private view returns (bool) {
        uint256 value;
        assembly {
            mstore(0, vault)
            mstore(32, transientVerified.slot)
            value := tload(keccak256(0, 64))
        }

        return value != NOT_VERIFIED || verified.contains(vault);
    }

    function _setOptimisticallyVerified(address vault) private {
        assembly {
            mstore(0, vault)
            mstore(32, transientVerified.slot)
            tstore(keccak256(0, 64), VERIFIED)
        }
    }

    function _setPermanentlyVerified(address vault) private {
        verified.add(vault);
        emit PerspectiveVerified(vault);
    }
}
