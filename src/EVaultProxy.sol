// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

interface ICreator {
    function getEVaultImplementation() external view returns (address);
}

contract EVaultProxy {
    address immutable creator;
    uint immutable metadata1;
    uint immutable metadata2;


    event Genesis();

    constructor(address _asset, uint8 _assetDecimals, address _riskManager) {
        creator = msg.sender;

        // pack 41 bytes metadata into 2 words
        metadata1 = (uint(uint160(_asset)) << 96) | (uint(_assetDecimals) << 88) | uint(uint160(_riskManager)) >> 72;
        metadata2 = uint(uint160(_riskManager)) << 184;

        emit Genesis();
    }

    // External interface

    // Function returning current implementation address for compatibility with block explorers
    function implementation() external view returns (address) {
        return ICreator(creator).getEVaultImplementation();
    }

    fallback() external {
        uint metadata1_ = metadata1;
        uint metadata2_ = metadata2;
        // TODO revisit
        address implementation_ = ICreator(creator).getEVaultImplementation();

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
