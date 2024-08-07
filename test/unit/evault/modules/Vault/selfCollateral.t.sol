// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVaultTestBase, IEVault, IRMTestDefault} from "../../EVaultTestBase.t.sol";

import "../../../../../src/EVault/shared/types/Types.sol";
import "../../../../../src/EVault/shared/Constants.sol";

contract VaultTest_SelfCollateral is EVaultTestBase {
    using TypesLib for uint256;

    IEVault public eeTST;

    function setUp() public override {
        super.setUp();

        eeTST = IEVault(
            factory.createProxy(address(0), true, abi.encodePacked(address(eTST), address(oracle), unitOfAccount))
        );
        eeTST.setInterestRateModel(address(new IRMTestDefault()));

        oracle.setPrice(address(assetTST), unitOfAccount, 1e18);
        oracle.setPrice(address(eTST), unitOfAccount, 1e18);
        oracle.setPrice(address(eeTST), unitOfAccount, 1e18);
    }

    function test_selfCollateralDisallowed() public {
        vm.expectRevert(Errors.E_InvalidLTVAsset.selector);
        eTST.setLTV(address(eTST), 0.9e4, 0.9e4, 0);

        vm.expectRevert(Errors.E_Reentrancy.selector);
        eTST.setLTV(address(eeTST), 0.9e4, 0.9e4, 0);
    }
}
