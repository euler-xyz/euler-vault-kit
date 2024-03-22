// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVaultTestBase} from "../../EVaultTestBase.t.sol";

import {TestERC20} from "../../../../mocks/TestERC20.sol";

import "src/EVault/shared/types/Types.sol";

contract Initialize_ConfigFlags is EVaultTestBase {
    using TypesLib for uint256;

    function setUp() public override {
        super.setUp();
    }

    function test_evc_compatiblity() public {
        // Incompatible asset
        {
            TestERC20 assetJUNK = new TestERC20("Test Token", "JUNK", 18, false);

            IEVault eJUNK = IEVault(factory.createProxy(true, abi.encodePacked(address(assetJUNK), address(oracle), unitOfAccount)));
            assertTrue(eJUNK.configFlags() & CFG_EVC_COMPATIBLE_ASSET == 0);
        }

        // Compatible asset
        {
            TestERC20 assetJUNK = new TestERC20("Test Token", "JUNK", 18, false);
            assetJUNK.configure("evc/address", abi.encode(address(evc)));

            IEVault eJUNK = IEVault(factory.createProxy(true, abi.encodePacked(address(assetJUNK), address(oracle), unitOfAccount)));
            assertTrue(eJUNK.configFlags() & CFG_EVC_COMPATIBLE_ASSET != 0);
        }

        // Different EVC
        {
            TestERC20 assetJUNK = new TestERC20("Test Token", "JUNK", 18, false);
            assetJUNK.configure("evc/address", abi.encode(address(eTST)));

            IEVault eJUNK = IEVault(factory.createProxy(true, abi.encodePacked(address(assetJUNK), address(oracle), unitOfAccount)));
            assertTrue(eJUNK.configFlags() & CFG_EVC_COMPATIBLE_ASSET == 0);
        }
    }
}
