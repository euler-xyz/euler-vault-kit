// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

/// @notice Contract for deploying minimal proxies with metadata, based on EIP-3448.
/// @dev The metadata of the proxies does not include the data length as defined by EIP-3448, saving gas at a cost of supporting variable size data.
contract MetaProxyDeployer {
    /// @dev Creates a proxy for `targetContract` with metadata from `metadata`. Code modified from EIP-3448 reference implementation: https://eips.ethereum.org/EIPS/eip-3448
    /// @return addr A non-zero address if successful.
    function deployMetaProxy(address targetContract, bytes memory metadata) internal returns (address addr) {
        // the following assembly code (init code + contract code) constructs a metaproxy.
        assembly {
            let offset := add(metadata, 32)
            let length := mload(metadata)
            // load free memory pointer as per solidity convention
            let start := mload(64)
            // keep a copy
            let ptr := start
            // deploy code (11 bytes) + first part of the proxy (21 bytes)
            mstore(ptr, 0x600b380380600b3d393df3363d3d373d3d3d3d60368038038091363936013d73)
            ptr := add(ptr, 32)

            // store the address of the contract to be called
            mstore(ptr, shl(96, targetContract))
            // 20 bytes
            ptr := add(ptr, 20)

            // the remaining proxy code...
            mstore(ptr, 0x5af43d3d93803e603457fd5bf300000000000000000000000000000000000000)
            // ...13 bytes
            ptr := add(ptr, 13)

            // copy the metadata
            {
                for { let i := 0 } lt(i, length) { i := add(i, 32) } { mstore(add(ptr, i), mload(add(offset, i))) }
            }
            ptr := add(ptr, length)

            // The size is deploy code + contract code + calldatasize - 4.
            addr := create(0, start, sub(ptr, start))
        }
    }
}
