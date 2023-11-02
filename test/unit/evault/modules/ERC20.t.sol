// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "../EVaultTestBase.t.sol";

contract ERC20Test is EVaultTestBase {
    function test_basicViews() public {
        assertEq(eTST.name(), "Euler Pool: Test Token");
        assertEq(eTST.symbol(), "eTST");
    }
}