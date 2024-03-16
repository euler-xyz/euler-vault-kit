// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.23;

function boundAddr(address addr) pure returns (address) {
    if (
        uint160(addr) < 256 || addr == 0x4e59b44847b379578588920cA78FbF26c0B4956C
            || addr == 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D || addr == 0x000000000000000000636F6e736F6c652e6c6f67
            || addr == 0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f
    ) return address(uint160(addr) + 256);

    return addr;
}

function boundAddrs(address[] memory addrs) pure returns (address[] memory) {
    for (uint256 i = 0; i < addrs.length; ++i) {
        addrs[i] = boundAddr(addrs[i]);
    }
    return addrs;
}

function makeAddrs(uint256 length) pure returns (address[] memory) {
    address[] memory addrs = new address[](length);

    for (uint256 i = 0; i < length; ++i) {
        addrs[i] = address(uint160(uint256(keccak256(abi.encodePacked(i)))));
    }

    return addrs;
}
