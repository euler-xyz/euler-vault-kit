// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EnumerableSet} from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";
import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";
import {PerspectiveErrors} from "./PerspectiveErrors.sol";
import {IERC20} from "../EVault/IEVault.sol";
import {GenericFactory} from "../GenericFactory/GenericFactory.sol";
import {RevertBytes} from "../EVault/shared/lib/RevertBytes.sol";

abstract contract BasePerspective is PerspectiveErrors {
    using EnumerableSet for EnumerableSet.AddressSet;

    struct Transient {
        uint256 placeholder;
    }

    uint256 private constant SIMULATION_SHIFT = 160;
    uint256 private constant SIMULATION_IN_PROGRESS = 1;
    uint256 private constant VAULT_VERIFIED = 1;

    IEVC internal immutable evc;
    GenericFactory internal immutable vaultFactory;
    EnumerableSet.AddressSet private verified;
    Transient private transientVerified;
    Transient private transientErrors;
    Transient private transientContext;

    event PerspectiveVerified(address indexed vault);

    constructor(address evc_, address vaultFactory_) {
        evc = IEVC(evc_);
        vaultFactory = GenericFactory(vaultFactory_);
    }

    function perspectiveVerify(address vault) external returns (bool) {
        // if already verified, return true
        if (_isVerified(vault)) return true;

        // perform the perspective verification
        _perspectiveVerify(vault);

        // if the simulation was in progress, we need to check for any property errors that may have occurred.
        // otherwise, we would have already reverted if there were any property errors
        _requireNoPropertyErrors(vault);

        // set the vault as permanently verified
        _setPermanentStorage(vault);

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
        uint256 uintVault = uint160(context);

        if ((context >> SIMULATION_SHIFT) == SIMULATION_IN_PROGRESS) {
            assembly {
                mstore(0, uintVault)
                mstore(32, transientErrors.slot)
                let hash := keccak256(0, 64)
                let accumulatedErrors := tload(hash)
                tstore(hash, or(accumulatedErrors, errorCode))
            }
        } else {
            revert PerspectiveError(address(this), address(uint160(uintVault)), errorCode);
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

    function _isVerified(address vault) private view returns (bool) {
        uint256 uintVault = uint160(vault);
        uint256 value;
        assembly {
            mstore(0, uintVault)
            mstore(32, transientVerified.slot)
            value := tload(keccak256(0, 64))
        }

        return value == VAULT_VERIFIED || verified.contains(vault);
    }

    function _perspectiveVerify(address vault) private {
        uint256 uintVault = uint160(vault);

        // optimistically assume that the vault is verified
        assembly {
            mstore(0, uintVault)
            mstore(32, transientVerified.slot)
            tstore(keccak256(0, 64), VAULT_VERIFIED)
        }

        uint256 context = _loadContext();

        // query the EVC to determine if the simulation is in progress and set the transient variable indicating that
        uint256 simulationStatus = ((context >> SIMULATION_SHIFT) == SIMULATION_IN_PROGRESS)
            || evc.isSimulationInProgress() ? (SIMULATION_IN_PROGRESS << SIMULATION_SHIFT) : 0;

        // store the new context
        _storeContext(simulationStatus | uintVault);

        // perform the perspective verification
        perspectiveVerifyInternal(vault);

        // restore the cached vault address
        _storeContext(context);
    }

    function _requireNoPropertyErrors(address vault) private view {
        uint256 uintVault = uint160(vault);
        uint256 accumulatedErrors;
        assembly {
            mstore(0, uintVault)
            mstore(32, transientErrors.slot)
            let hash := transientErrors.slot
            accumulatedErrors := tload(keccak256(0, 64))
        }

        if (accumulatedErrors != 0) revert PerspectiveError(address(this), vault, accumulatedErrors);
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

    function _setPermanentStorage(address vault) private {
        verified.add(vault);
        emit PerspectiveVerified(vault);
    }
}
