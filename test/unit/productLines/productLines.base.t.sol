// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "../evault/EVaultTestBase.t.sol";

contract ProductLine_Base is EVaultTestBase {
    function test_ProductLine_Base_lookup() public {
        address vault1 = coreProductLine.createVault(address(assetTST), address(oracle), unitOfAccount);
        address vault2 = coreProductLine.createVault(address(assetTST2), address(oracle), unitOfAccount);

        assertEq(coreProductLine.vaultLookup(vault1), true);
        assertEq(coreProductLine.vaultLookup(vm.addr(100)), false);
        assertEq(coreProductLine.getVaultListLength(), 2);
        assertEq(coreProductLine.getVaultListSlice(0, type(uint256).max)[0], vault1);
        assertEq(coreProductLine.getVaultListSlice(0, type(uint256).max)[1], vault2);
    }
}
