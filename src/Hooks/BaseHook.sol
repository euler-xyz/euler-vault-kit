// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

contract BaseHook {
    function isHookTarget() external pure returns (bytes4) {
        return this.isHookTarget.selector;
    }

    function getAddressFromMsgData() public pure returns (address) {
        // Ensure that tx.data has at least 20 bytes
        require(msg.data.length >= 20, "tx.data too short");

        // Get the last 20 bytes of tx.data
        bytes memory data = msg.data;
        bytes20 addressBytes;

        // Copy the last 20 bytes to addressBytes
        assembly {
            // Calculate the starting position of the last 20 bytes
            let start := sub(add(data, mload(data)), 20)
            addressBytes := mload(start)
        }

        // Cast bytes20 to address
        address extractedAddress = address(uint160(addressBytes));
        return extractedAddress;
    }
}
