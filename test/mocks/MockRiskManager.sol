// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "../../src/IRiskManager.sol";
import "forge-std/console.sol";

contract MockRiskManager {
    constructor() {}

    function activateMarket(address) external pure {}

    function checkMarketStatus(address, address[] calldata, IRiskManager.Liability calldata)
        external
        pure
    {}
}
