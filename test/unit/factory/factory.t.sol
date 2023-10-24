// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2, stdError} from "forge-std/Test.sol";
import {EVaultFactory} from "../src/EVaultFactory/EVaultFactory.sol";

import {MockEVault} from "./mocks/MockEVault.sol";
import {MockRiskManager, MockRiskManagerFail} from "./mocks/MockRiskManager.sol";
import {TestERC20} from "./mocks/TestERC20.sol";
import {ReentrancyAttack} from "./mocks/ReentrancyAttack.sol";

interface IEvents {
    event Genesis();
    event EVaultCreated(address indexed eVault, address indexed asset, address indexed riskManager);
    event SetEVaultImplementation(address indexed newImplementation);
    event SetUpgradeAdmin(address indexed newUpgradeAdmin);
    event SetGovernorAdmin(address indexed newGovernorAdmin);
    event SetProtocolFeesHolder(address indexed newProtocolFeesHolder);
}

contract FactoryTest is Test, IEvents {
    EVaultFactory public factory;
    address public upgradeAdmin;
    address public governorAdmin;
    address public protocolFeesHolder;

    function setUp() public {
        address admin = vm.addr(1000);

        vm.expectEmit();
        emit Genesis();

        vm.expectEmit(true, false, false, false);
        emit SetUpgradeAdmin(admin);

        vm.expectEmit(true, false, false, false);
        emit SetGovernorAdmin(admin);

        vm.expectEmit(true, false, false, false);
        emit SetProtocolFeesHolder(admin);

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
            (string memory outputArg, address theMsgSender, address marketAsset, address riskManager)
                = eTST.arbitraryFunction(inputArg);

            assertEq(outputArg, inputArg);
            assertEq(theMsgSender, randomUser);
            assertEq(marketAsset, address(asset));
            assertEq(riskManager, address(rm));
        }
    }

    function test_getEVaultsListLength() public {
        // Create and install mock eVault impl
        MockEVault mockEvaultImpl = new MockEVault(address(factory), address(1));
        vm.prank(upgradeAdmin);
        factory.setEVaultImplementation(address(mockEvaultImpl));
        MockRiskManager rm = new MockRiskManager();

        // Create Tokens and activate Markets
        uint amountEVault = 10;
        for(uint i; i < amountEVault; i++){
            TestERC20 TST = new TestERC20("Test Token", "TST" , 18, false);
            MockEVault(factory.activateMarket(address(TST), address(rm), ""));
        }

        uint lenEVaultList = factory.getEVaultsListLength();

        assertEq(lenEVaultList, amountEVault);
    }

    function test_getEVaultsList() public {

        // Create and install mock eVault impl
        MockEVault mockEvaultImpl = new MockEVault(address(factory), address(1));
        vm.prank(upgradeAdmin);
        factory.setEVaultImplementation(address(mockEvaultImpl));
        MockRiskManager rm = new MockRiskManager();

        // Create Tokens and activate Markets
        uint amountEVaults = 100;
        
        address[] memory eVaultsList = new address[](amountEVaults);

        for(uint i; i < amountEVaults; i++){
            TestERC20 TST = new TestERC20("Test Token", "TST" , 18, false);
            MockEVault eVault = MockEVault(factory.activateMarket(address(TST), address(rm), ""));
            eVaultsList[i] = address(eVault);
        }   

        //get eVaults List
        address[] memory listEVaultsTest;
        address[] memory listEVaultFactory;

        //test getEVaultsList(0, type(uint).max) - get all eVaults list
        uint startIndex = 0;
        uint amountNumbers = type(uint).max;

        listEVaultFactory = factory.getEVaultsList(startIndex, amountNumbers);

        listEVaultsTest = eVaultsList;

        assertEq(listEVaultFactory, listEVaultsTest);

        //test getEVaultsList(3, 10) - get 10 eVault's address starting with 3
        startIndex = 3;
        amountNumbers = 10;

        listEVaultFactory = factory.getEVaultsList(startIndex, amountNumbers);

        listEVaultsTest = new address[](amountNumbers);
        for(uint i; i < amountEVaults; i++){
            if(i >= startIndex && i < amountNumbers + startIndex){
                listEVaultsTest[i - startIndex] = eVaultsList[i];
            }
        }

        assertEq(listEVaultFactory, listEVaultsTest);
        
    }

    function test_getEVaultConfig() public {
        // Create and install mock eVault impl
        MockEVault mockEvaultImpl = new MockEVault(address(factory), address(1));
        vm.prank(upgradeAdmin);
        factory.setEVaultImplementation(address(mockEvaultImpl));
        MockRiskManager rm = new MockRiskManager();

        // Create Tokens and activate Markets
        TestERC20 TST = new TestERC20("Test Token", "TST" , 18, false);
        MockEVault eVault = MockEVault(factory.activateMarket(address(TST), address(rm), ""));

        (address asset, address riskManager) = factory.getEVaultConfig(address(eVault));

        assertEq(asset, address(TST));
        assertEq(riskManager, address(rm));

        TST = new TestERC20("Test Token", "TST" , 18, false);
        eVault = MockEVault(factory.activateMarket(address(TST), address(rm), ""));

        (asset, riskManager) = factory.getEVaultConfig(address(eVault));

        assertEq(asset, address(TST));
        assertEq(riskManager, address(rm));
    }

    function test_Event_EVaultCreated() public {
        // Create and install mock eVault impl
        MockEVault mockEvaultImpl = new MockEVault(address(factory), address(1));
        vm.prank(upgradeAdmin);
        factory.setEVaultImplementation(address(mockEvaultImpl));

        // Create token and activate it
        TestERC20 asset = new TestERC20("Test Token", "TST", 17, false);
        MockRiskManager rm = new MockRiskManager();

        vm.expectEmit(false, true, true, false);
        emit EVaultCreated(address(1), address(asset), address(rm));

        factory.activateMarket(address(asset), address(rm), "");
    }

    function test_Event_SetEVaultImplementation() public {
        vm.expectEmit(true, false, false, false);
        emit SetEVaultImplementation(address(1));

        vm.prank(upgradeAdmin);
        factory.setEVaultImplementation(address(1));
    }

    function test_Event_SetUpgradeAdmin() public {
        address newUpgradeAdmin = vm.addr(1002);

        vm.expectEmit(true, false, false, false, address(factory));
        emit SetUpgradeAdmin(newUpgradeAdmin);
        
        vm.prank(upgradeAdmin);
        factory.setUpgradeAdmin(newUpgradeAdmin);
    }

    function test_Event_SetGovernorAdmin() public {
        address newGovernorAdmin = vm.addr(1003);

        vm.expectEmit(true, false, false, false, address(factory));
        emit SetGovernorAdmin(newGovernorAdmin);
        
        vm.prank(upgradeAdmin);
        factory.setGovernorAdmin(newGovernorAdmin);
    }

    function test_Event_SetProtocolFeesHolder() public {
        address newProtocolFeesHolder = vm.addr(1004);

        vm.expectEmit(true, false, false, false, address(factory));
        emit SetProtocolFeesHolder(newProtocolFeesHolder);

        vm.prank(governorAdmin);
        factory.setProtocolFeesHolder(newProtocolFeesHolder);
    }

    function test_RevertIfUnauthorized() public {
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

    function test_RevertIfNonReentrancy_ActivateMarket() public {
        MockEVault mockEvaultImpl = new MockEVault(address(factory), address(1));
        vm.prank(upgradeAdmin);
        factory.setEVaultImplementation(address(mockEvaultImpl));
        
        address asset = vm.addr(1);
        ReentrancyAttack rm = new ReentrancyAttack(address(factory), address(asset));

        vm.expectRevert(EVaultFactory.E_Reentrancy.selector);
        factory.activateMarket(address(asset), address(rm), "");

    }

    function test_RevertIfInvalidAsset_ActivateMarket() public {
        MockEVault mockEvaultImpl = new MockEVault(address(factory), address(1));
        vm.prank(upgradeAdmin);
        factory.setEVaultImplementation(address(mockEvaultImpl));
        
        address rm = vm.addr(2);
        address asset = address(factory);

        vm.expectRevert(EVaultFactory.E_InvalidAsset.selector);
        factory.activateMarket(address(asset), address(rm), "");

        asset = address(0);
        vm.expectRevert(EVaultFactory.E_InvalidAsset.selector);
        factory.activateMarket(address(asset), address(rm), "");
    }

    function test_RevertIfImplementation_ActivateMarket() public {
        address rm = vm.addr(2);
        address asset = vm.addr(1);

        vm.expectRevert(EVaultFactory.E_Implementation.selector);
        factory.activateMarket(address(asset), address(rm), "");
    }

    function test_RevertIfBadAddress() public {
        vm.prank(upgradeAdmin);
        vm.expectRevert(EVaultFactory.E_BadAddress.selector);
        factory.setEVaultImplementation(address(0));

        vm.prank(upgradeAdmin);
        vm.expectRevert(EVaultFactory.E_BadAddress.selector);
        factory.setUpgradeAdmin(address(0));
        
        vm.prank(upgradeAdmin);
        vm.expectRevert(EVaultFactory.E_BadAddress.selector);
        factory.setGovernorAdmin(address(0));

        vm.prank(governorAdmin);
        vm.expectRevert(EVaultFactory.E_BadAddress.selector);
        factory.setProtocolFeesHolder(address(0));
    }

    function test_RevertIfRiskManagerHook_ActivateMarket() public {
        MockEVault mockEvaultImpl = new MockEVault(address(factory), address(1));
        vm.prank(upgradeAdmin);
        factory.setEVaultImplementation(address(mockEvaultImpl));

        address asset = vm.addr(1);
        MockRiskManagerFail rm = new MockRiskManagerFail();

        vm.expectRevert(EVaultFactory.E_RiskManagerHook.selector);
        factory.activateMarket(address(asset), address(rm), "");
    }

    function test_RevertIfErrorList_GetEVaultsList() public {
        // Create and install mock eVault impl
        MockEVault mockEvaultImpl = new MockEVault(address(factory), address(1));
        vm.prank(upgradeAdmin);
        factory.setEVaultImplementation(address(mockEvaultImpl));
        MockRiskManager rm = new MockRiskManager();

        // Create Tokens and activate Markets
        uint amountEVaults = 100;
        
        address[] memory eVaultsList = new address[](amountEVaults);

        for(uint i; i < amountEVaults; i++){
            TestERC20 TST = new TestERC20("Test Token", "TST" , 18, false);
            MockEVault eVault = MockEVault(factory.activateMarket(address(TST), address(rm), ""));
            eVaultsList[i] = address(eVault);
        }   

        uint startIndex = 0;
        uint amountNumbers = amountEVaults + 1;

        vm.expectRevert(EVaultFactory.E_List.selector);
        factory.getEVaultsList(startIndex, amountNumbers);

        startIndex = 1;
        amountNumbers = type(uint).max;

        vm.expectRevert(stdError.arithmeticError); // ????
        factory.getEVaultsList(startIndex, amountNumbers);

        startIndex = 32;
        amountNumbers = 92;

        vm.expectRevert(EVaultFactory.E_List.selector);
        factory.getEVaultsList(startIndex, amountNumbers);
    }

}
