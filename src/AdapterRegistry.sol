// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";

contract AdapterRegistry is Ownable {
    error AR_AlreadyAdded();
    error AR_NotAdded();
    error AR_AlreadyRevoked();

    struct Entry {
        uint48 addedTime;
        uint48 revokedTime;
        string name;
    }

    mapping(address adapter => Entry) public entries;

    constructor() Ownable(msg.sender) {}

    function addAdapter(address adapter, string calldata name) external onlyOwner {
        if (entries[adapter].addedTime != 0) revert AR_AlreadyAdded();

        entries[adapter] = Entry({
            addedTime: uint48(block.timestamp),
            revokedTime: 0,
            name: name
        });
    }

    function revokeAdapter(address adapter) external onlyOwner {
        if (entries[adapter].addedTime == 0) revert AR_NotAdded();
        if (entries[adapter].revokedTime != 0) revert AR_AlreadyRevoked();

        entries[adapter].revokedTime = uint48(block.timestamp);
    }

    function isValidAdapter(address adapter, uint256 snapshotTime) external view returns (bool) {
        uint256 addedTime = entries[adapter].addedTime;
        uint256 revokedTime = entries[adapter].revokedTime;

        if (addedTime == 0 || snapshotTime < addedTime) return false;
        if (revokedTime != 0 && revokedTime <= snapshotTime) return false;

        return true;
    }
}
