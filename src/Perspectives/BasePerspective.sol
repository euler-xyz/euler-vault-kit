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

    uint256 private constant FAIL_EARLY_SHIFT = 160;
    uint256 private constant VALUE_SET = 1;

    GenericFactory internal immutable vaultFactory;

    EnumerableSet.AddressSet private verified;
    mapping(address => uint256) private errors;

    Transient private transientVerified;
    Transient private transientContext;

    constructor(address vaultFactory_) {
        vaultFactory = GenericFactory(vaultFactory_);
    }

    function perspectiveVerify(address vault, bool failEarly) external returns (bool) {
        uint256 uintVault = uint160(vault);
        uint256 uintFailEarly = failEarly ? VALUE_SET << FAIL_EARLY_SHIFT : 0;
        bytes32 transientVerifiedHash;
        uint256 transientVerifiedValue;
        assembly {
            mstore(0, uintVault)
            mstore(32, transientVerified.slot)
            transientVerifiedHash := keccak256(0, 64)
            transientVerifiedValue := tload(transientVerifiedHash)
        }

        // if already verified, return true
        if (transientVerifiedValue == VALUE_SET || verified.contains(vault)) {
            return true;
        }

        // optimistically assume that the vault is verified
        assembly {
            tstore(transientVerifiedHash, VALUE_SET)
        }

        // cache the current context
        uint256 context = _loadContext();

        // store the new context
        _storeContext(uintFailEarly | uintVault);

        // perform the perspective verification
        perspectiveVerifyInternal(vault);

        // restore the previous context
        _storeContext(context);

        // if early fail was not requested, we need to check for any property errors that may have occurred.
        // otherwise, we would have already reverted if there were any property errors
        if (!failEarly) {
            uint256 accumulatedErrors = errors[vault];

            if (accumulatedErrors != 0) {
                revert PerspectiveError(address(this), vault, accumulatedErrors);
            }
        }

        // set the vault as permanently verified
        verified.add(vault);
        emit PerspectiveVerified(vault);

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

    function testProperty(bool condition, uint256 errorCode) internal {
        if (condition) return;

        uint256 context = _loadContext();
        address contextVault = address(uint160(context));
        bool contextFailEarly = (context >> FAIL_EARLY_SHIFT) == VALUE_SET;

        if (contextFailEarly) {
            revert PerspectiveError(address(this), contextVault, errorCode);
        } else {
            errors[contextVault] |= errorCode;
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

    function _storeContext(uint256 value) private {
        assembly {
            tstore(transientContext.slot, value)
        }
    }

    function _loadContext() private view returns (uint256 value) {
        assembly {
            value := tload(transientContext.slot)
        }
    }
}
