// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EnumerableSet} from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";
import {PerspectiveErrors} from "./PerspectiveErrors.sol";
import {IERC20} from "../EVault/IEVault.sol";
import {GenericFactory} from "../GenericFactory/GenericFactory.sol";
import {RevertBytes} from "../EVault/shared/lib/RevertBytes.sol";

abstract contract BasePerspective is PerspectiveErrors {
    using EnumerableSet for EnumerableSet.AddressSet;

    struct Transient {
        uint256 placeholder;
    }

    event PerspectiveVerified(address indexed vault);

    uint256 private constant VALUE_SET = 1;

    GenericFactory internal immutable vaultFactory;

    EnumerableSet.AddressSet private verified;
    Transient private transientVerified;
    Transient private transientErrors;

    constructor(address vaultFactory_) {
        vaultFactory = GenericFactory(vaultFactory_);
    }

    function perspectiveVerify(address vault, bool failEarly) external {
        uint256 uintVault = uint160(vault);
        bytes32 transientVerifiedHash;
        uint256 transientVerifiedValue;
        assembly {
            mstore(0, uintVault)
            mstore(32, transientVerified.slot)
            transientVerifiedHash := keccak256(0, 64)
            transientVerifiedValue := tload(transientVerifiedHash)
        }

        // if already verified, return true
        if (transientVerifiedValue == VALUE_SET || verified.contains(vault)) return;

        // optimistically assume that the vault is verified
        assembly {
            tstore(transientVerifiedHash, VALUE_SET)
        }

        // perform the perspective verification
        perspectiveVerifyInternal(vault, failEarly);

        // if early fail was not requested, we need to check for any property errors that may have occurred.
        // otherwise, we would have already reverted if there were any property errors
        uint256 errors;
        assembly {
            errors := tload(transientErrors.slot)
        }

        if (errors != 0) revert PerspectiveError(address(this), vault, errors);

        // set the vault as permanently verified
        verified.add(vault);
        emit PerspectiveVerified(vault);
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

    function perspectiveVerifyInternal(address vault, bool failEarly) internal virtual {}

    function testProperty(bool condition, address vault, uint256 errorCode, bool failEarly) internal {
        if (condition) return;

        if (failEarly) {
            revert PerspectiveError(address(this), vault, errorCode);
        } else {
            assembly {
                let errors := tload(transientErrors.slot)
                tstore(transientErrors.slot, or(errors, errorCode))
            }
        }
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
