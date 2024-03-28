// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "../evault/EVaultTestBase.t.sol";

contract ProductLine_Core is EVaultTestBase {
    function test_ProductLine_Core_basicViews() public {
        IEVault vault = IEVault(coreProductLine.createVault(address(assetTST), address(oracle), unitOfAccount));
        
        assertEq(factory.getProxyConfig(address(vault)).upgradeable, true);

        assertEq(vault.unitOfAccount(), unitOfAccount);
        assertEq(vault.oracle(), address(oracle));
        assertEq(vault.feeReceiver(), feeReceiver);
        assertEq(vault.governorAdmin(), address(this));
    }

    function test_ProductLine_Core_EVCCompatibility() public {
        assertEq(eTST.configFlags(), 0);
        IEVault nested = IEVault(coreProductLine.createVault(address(eTST), address(oracle), unitOfAccount));
        assertEq(nested.configFlags(), CFG_EVC_COMPATIBLE_ASSET);
    }
}
