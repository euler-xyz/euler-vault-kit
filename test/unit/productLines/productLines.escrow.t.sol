// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "src/ProductLines/Escrow.sol";
import "../evault/EVaultTestBase.t.sol";

contract ProductLine_Escrow is EVaultTestBase {
    uint32 constant ESCROW_DISABLED_OPS = OP_BORROW | OP_REPAY | OP_LOOP | OP_DELOOP | OP_PULL_DEBT | OP_CONVERT_FEES | OP_LIQUIDATE | OP_TOUCH
                | OP_ACCRUE_INTEREST;

    function test_ProductLine_Escrow_basicViews() public {
        IEVault escrowTST = IEVault(escrowProductLine.createVault(address(assetTST)));

        assertEq(factory.getProxyConfig(address(escrowTST)).upgradeable, false);

        assertEq(escrowTST.name(), "Escrow vault: Test Token");
        assertEq(escrowTST.symbol(), "eTST");
        assertEq(escrowTST.unitOfAccount(), address(0));
        assertEq(escrowTST.oracle(), address(0));
        assertEq(escrowTST.disabledOps(), ESCROW_DISABLED_OPS);
    }

    function test_ProductLine_Escrow_RevertWhenAlreadyCreated() public {
        escrowProductLine.createVault(address(assetTST));

        vm.expectRevert(Escrow.E_AlreadyCreated.selector);
        escrowProductLine.createVault(address(assetTST));
    }
}
