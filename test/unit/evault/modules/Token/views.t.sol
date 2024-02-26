// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "../../EVaultTestBase.t.sol";

contract ERC20Test_views is EVaultTestBase {
    function test_basicViews() public {
        assertEq(eTST.name(), "Unnamed Euler Vault");
        assertEq(eTST.symbol(), "UNKNOWN");
        assertEq(eTST.decimals(), assetTST.decimals());
    }
}
