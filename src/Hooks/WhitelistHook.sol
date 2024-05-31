// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

import {BaseHook} from "./BaseHook.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract WhitelistHook is BaseHook, Ownable {
    mapping(address => bool) public whitelist;

    error AddressNotWhitelisted();

    modifier checkWhitelist() {
        if (!whitelist[getAddressFromMsgData()]) {
            revert AddressNotWhitelisted();
        }
        _;
    }

    constructor() Ownable(msg.sender) {}

    function addToWhitelist(address _address) external onlyOwner {
        whitelist[_address] = true;
    }

    function removeFromWhitelist(address _address) external onlyOwner {
        whitelist[_address] = false;
    }

    fallback() external payable checkWhitelist {
        // no-op
    }
}
