// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "../evault/EVaultTestBase.t.sol";
import {BaseProductLine} from "../../../src/ProductLines/BaseProductLine.sol";

contract ErrorThrower {
    error NoGood();

    bytes4 throwOn;

    function set(bytes4 selector) public {
        throwOn = selector;
    }

    fallback() external {
        if (bytes4(msg.data) == throwOn) revert NoGood();
    }
}

contract ProductLine_Base is EVaultTestBase {
    function test_ProductLine_Base_lookup() public {
        assertEq(coreProductLine.vaultLookup(address(eTST)), true);
        assertEq(coreProductLine.vaultLookup(vm.addr(100)), false);
        assertEq(coreProductLine.getVaultListLength(), 2);
        assertEq(coreProductLine.getVaultListSlice(0, type(uint256).max)[0], address(eTST));
        assertEq(coreProductLine.getVaultListSlice(0, type(uint256).max)[1], address(eTST2));

        vm.expectRevert(BaseProductLine.E_BadQuery.selector);
        coreProductLine.getVaultListSlice(0, 3);
    }

    function test_ProductLine_tokenNameAndSymbol() public {
        ErrorThrower wrongAsset = new ErrorThrower();
        wrongAsset.set(IERC20.name.selector);

        vm.expectRevert(ErrorThrower.NoGood.selector);
        coreProductLine.createVault(address(wrongAsset), address(oracle), unitOfAccount);

        wrongAsset.set(IERC20.symbol.selector);

        vm.expectRevert(ErrorThrower.NoGood.selector);
        coreProductLine.createVault(address(wrongAsset), address(oracle), unitOfAccount);
    }
}
