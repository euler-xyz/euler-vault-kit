// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "../../src/IRiskManager.sol";
import "forge-std/console.sol";

contract MockRiskManager {
    constructor() {}

    function onMarketActivation(address, address, address, bytes calldata) external pure returns (bool success) {
        success = true;
    }

    function checkMarketStatus(uint8, IRiskManager.Snapshot memory, IRiskManager.Snapshot memory)
        external
        view
        returns (bool healthy, bytes memory notHealthyReason)
    {
        console.log("herererer");
        healthy = true;
        notHealthyReason = "";
    }
}

contract MockRiskManagerFail {
    constructor() {}

    function onMarketActivation(address, address, address, bytes calldata) external pure returns (bool success) {
        success = false;
    }
}
