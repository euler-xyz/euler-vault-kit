// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {EVaultFactory} from "../src/EVaultFactory/EVaultFactory.sol";

import {MockEVault} from "./mocks/MockEVault.sol";
import {MockRiskManager} from "./mocks/MockRiskManager.sol";
import {TestERC20} from "./mocks/TestERC20.sol";

contract FactoryTest is Test {
    EVaultFactory public factory;
    address public upgradeAdmin;
    address public governorAdmin;
    address public protocolFeesHolder;

    function setUp() public {
        address admin = vm.addr(1000);
        factory = new EVaultFactory(admin);

        // Defaults are all set to admin
        assertEq(factory.getUpgradeAdmin(), admin);
        assertEq(factory.getGovernorAdmin(), admin);
        assertEq(factory.getProtocolFeesHolder(), admin);

        // Implementation starts at address(0)
        assertEq(factory.implementation(), address(0));

        upgradeAdmin = vm.addr(1000);
        governorAdmin = vm.addr(1001);
        protocolFeesHolder = vm.addr(1002);

        vm.prank(admin);
        factory.setUpgradeAdmin(upgradeAdmin);
        vm.prank(upgradeAdmin);
        factory.setGovernorAdmin(governorAdmin);
        vm.prank(governorAdmin);
        factory.setProtocolFeesHolder(protocolFeesHolder);

        // Newly set values
        assertEq(factory.getUpgradeAdmin(), upgradeAdmin);
        assertEq(factory.getGovernorAdmin(), governorAdmin);
        assertEq(factory.getProtocolFeesHolder(), protocolFeesHolder);
    }


    function test_adminAuth() public {
        // Nobody addresses are unauthorised

        vm.prank(vm.addr(2000));
        vm.expectRevert(EVaultFactory.E_Unauthorized.selector);
        factory.setUpgradeAdmin(address(1));

        vm.prank(vm.addr(2000));
        vm.expectRevert(EVaultFactory.E_Unauthorized.selector);
        factory.setGovernorAdmin(address(1));

        vm.prank(vm.addr(2000));
        vm.expectRevert(EVaultFactory.E_Unauthorized.selector);
        factory.setProtocolFeesHolder(address(1));


        // Only upgradeAdmin can upgrade, only governor can change protocolFeesHolder

        vm.prank(governorAdmin);
        vm.expectRevert(EVaultFactory.E_Unauthorized.selector);
        factory.setEVaultImplementation(address(1));

        vm.prank(protocolFeesHolder);
        vm.expectRevert(EVaultFactory.E_Unauthorized.selector);
        factory.setEVaultImplementation(address(1));
    }


    function test_setImplementationSimple() public {
        vm.prank(upgradeAdmin);
        factory.setEVaultImplementation(address(1));
        assertEq(factory.implementation(), address(1));

        vm.prank(upgradeAdmin);
        factory.setEVaultImplementation(address(2));
        assertEq(factory.implementation(), address(2));
    }


    function test_activateMarket() public {
        // Create and install mock eVault impl

        MockEVault mockEvaultImpl = new MockEVault(address(factory), address(1));
        vm.prank(upgradeAdmin);
        factory.setEVaultImplementation(address(mockEvaultImpl));

        // Create token and activate it

        TestERC20 asset = new TestERC20("Test Token", "TST", 17, false);
        MockRiskManager rm = new MockRiskManager();
        MockEVault eTST = MockEVault(factory.activateMarket(address(asset), address(rm), ""));

        // Verify proxying behaves as intended

        assertEq(eTST.implementation(), "TRANSPARENT");

        {
            string memory inputArg = "hello world! 12345678900987654321";

            address randomUser = vm.addr(5000);
            vm.prank(randomUser);
            (string memory outputArg, address theMsgSender, address marketAsset, uint8 assetDecimals, address riskManager)
                = eTST.arbitraryFunction(inputArg);

            assertEq(outputArg, inputArg);
            assertEq(theMsgSender, randomUser);
            assertEq(marketAsset, address(asset));
            assertEq(assetDecimals, 17);
            assertEq(riskManager, address(rm));
        }
    }
}
