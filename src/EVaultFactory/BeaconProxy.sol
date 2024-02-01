// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

contract BeaconProxy {
    // ERC-1967 beacon address slot. bytes32(uint256(keccak256('eip1967.proxy.beacon')) - 1)
    bytes32 constant BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;
    // Beacon implementation() selector
    bytes32 constant IMPLEMENTATION_SELECTOR = 0x5c60da1b00000000000000000000000000000000000000000000000000000000;
    // Max trailing data length, 4 immutable slots
    uint256 constant MAX_TRAILING_DATA_LENGTH = 128;

    address immutable beacon;
    uint256 immutable metadataLength;
    bytes32 immutable metadata0;
    bytes32 immutable metadata1;
    bytes32 immutable metadata2;
    bytes32 immutable metadata3;

    event Genesis();

    constructor(bytes memory trailingData) {
        emit Genesis();

        require(trailingData.length <= MAX_TRAILING_DATA_LENGTH, "trailing data too long");

        // Beacon is always the proxy creator; store it in immutable
        beacon = msg.sender;

        // Store the beacon address in ERC-1967 slot for compatibility with block explorers
        assembly {
            sstore(BEACON_SLOT, caller())
        }

        // Record length as immutable
        metadataLength = trailingData.length;

        // Pad length with uninitialised memory so the decode will succeed
        assembly {
            mstore(trailingData, 128)
        }
        (metadata0, metadata1, metadata2, metadata3) = abi.decode(trailingData, (bytes32, bytes32, bytes32, bytes32));
    }

    fallback() external {
        address beacon_ = beacon;
        uint256 metadataLength_ = metadataLength;
        bytes32 metadata0_ = metadata0;
        bytes32 metadata1_ = metadata1;
        bytes32 metadata2_ = metadata2;
        bytes32 metadata3_ = metadata3;

        assembly {
            // Fetch implementation address from the beacon
            mstore(0, IMPLEMENTATION_SELECTOR)
            let result := staticcall(gas(), beacon_, 0, 4, 0, 32)
            if iszero(result) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
            let implementation := mload(0)

            // delegatecall to the implementation with trailing metadata
            calldatacopy(0, 0, calldatasize())
            mstore(calldatasize(), metadata0_)
            mstore(add(32, calldatasize()), metadata1_)
            mstore(add(64, calldatasize()), metadata2_)
            mstore(add(96, calldatasize()), metadata3_)
            result := delegatecall(gas(), implementation, 0, add(metadataLength_, calldatasize()), 0, 0)
            returndatacopy(0, 0, returndatasize())

            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
}
