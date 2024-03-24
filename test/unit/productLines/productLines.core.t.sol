// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "../evault/EVaultTestBase.t.sol";

contract ProductLine_Core is EVaultTestBase {
    function test_ProductLine_Core_basicViews() public view {
        assertEq(factory.getProxyConfig(address(eTST)).upgradeable, true);

        assertEq(eTST.unitOfAccount(), unitOfAccount);
        assertEq(eTST.oracle(), address(oracle));
        assertEq(eTST.feeReceiver(), feeReceiver);
        assertEq(eTST.governorAdmin(), address(this));
    }

    function test_ProductLine_Core_EVCCompatibility() public {
        assertEq(eTST.configFlags(), 0);
        IEVault nested = IEVault(coreProductLine.createVault(address(eTST), address(oracle), unitOfAccount));
        assertEq(nested.configFlags(), CFG_EVC_COMPATIBLE_ASSET);
    }
}
