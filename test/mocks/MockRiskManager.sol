// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

contract MockRiskManager {
    constructor() {
    }

    function onMarketActivation(address, address, address, bytes calldata) external pure returns (bool success) {
        success = true;
    }
}

contract MockRiskManagerFail {
    constructor() {
    }

    function onMarketActivation(address, address, address, bytes calldata) external pure returns (bool success) {
        success = false;
    }
}
