// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "../evault/EVaultTestBase.t.sol";

contract ProductLine_Base is EVaultTestBase {
    function test_ProductLine_Base_lookup() public view {
        assertEq(coreProductLine.vaultLookup(address(eTST)), true);
        assertEq(coreProductLine.vaultLookup(vm.addr(100)), false);
        assertEq(coreProductLine.getVaultListLength(), 2);
        assertEq(coreProductLine.getVaultListSlice(0, type(uint).max)[0], address(eTST));
        assertEq(coreProductLine.getVaultListSlice(0, type(uint).max)[1], address(eTST2));
    }
}
