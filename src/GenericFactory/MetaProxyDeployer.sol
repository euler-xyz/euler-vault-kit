// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Create2} from "openzeppelin-contracts/utils/Create2.sol";

/// @notice Contract for deploying minimal proxies with metadata, based on EIP-3448.
/// @dev The metadata of the proxies does not include the data length as defined by EIP-3448, saving gas at a cost of supporting variable size data.
contract MetaProxyDeployer {
    error E_DeploymentFailed();

    // Meta proxy bytecode from EIP-3488 https://eips.ethereum.org/EIPS/eip-3448
    bytes constant BYTECODE_HEAD = hex"600b380380600b3d393df3363d3d373d3d3d3d60368038038091363936013d73";
    bytes constant BYTECODE_TAIL = hex"5af43d3d93803e603457fd5bf3";

    /// @dev Creates a proxy for `targetContract` with metadata from `metadata`.
    /// @return addr A non-zero address if successful.
    function deployMetaProxy(address targetContract, bytes32 salt, bytes memory metadata)
        internal
        returns (address addr)
    {
        bytes memory code = getCode(targetContract, metadata);

        assembly ("memory-safe") {
            addr := create2(0, add(code, 32), mload(code), salt)
        }

        if (addr == address(0)) revert E_DeploymentFailed();
    }

    function getCode(address targetContract, bytes memory metadata) private pure returns (bytes memory) {
        return abi.encodePacked(BYTECODE_HEAD, targetContract, BYTECODE_TAIL, metadata);
    }

    function computeMetaProxyAddress(bytes32 salt, address targetContract, bytes memory metadata)
        internal
        view
        returns (address)
    {
        return Create2.computeAddress(salt, keccak256(getCode(targetContract, metadata)));
    }
}
