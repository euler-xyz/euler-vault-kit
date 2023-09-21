// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

interface IBeacon {
    function implementation() external view returns (address);
}

contract EVaultProxy {
    // ERC-1967 beacon address slot. bytes32(uint256(keccak256('eip1967.proxy.beacon')) - 1)
    bytes32 constant BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

    address immutable beacon;
    uint immutable metadata1;
    uint immutable metadata2;

    event Genesis();

    constructor(address _asset, uint8 _assetDecimals, address _riskManager) {
        beacon = msg.sender;

        // pack 41 bytes metadata into 2 words
        metadata1 = (uint(uint160(_asset)) << 96) | (uint(_assetDecimals) << 88) | uint(uint160(_riskManager)) >> 72;
        metadata2 = uint(uint160(_riskManager)) << 184;

        // Store the beacon address in ERC-1967 slot for compatibility with block explorers
        assembly { sstore(BEACON_SLOT, caller()) }

        emit Genesis();
    }

    fallback() external {
        uint metadata1_ = metadata1;
        uint metadata2_ = metadata2;

        address implementation_ = IBeacon(beacon).implementation();

        assembly {
            calldatacopy(0, 0, calldatasize())
            mstore(calldatasize(), metadata1_)
            mstore(add(32, calldatasize()), metadata2_)

            let result := delegatecall(gas(), implementation_, 0, add(41, calldatasize()), 0, 0)
            returndatacopy(0, 0, returndatasize())

            switch result
                case 0 { revert(0, returndatasize()) }
                default { return(0, returndatasize()) }
        }
    }
}
