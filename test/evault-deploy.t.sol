// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2, stdError} from "forge-std/Test.sol";

import {EVaultFactory} from "../src/EVaultFactory/EVaultFactory.sol";
import {EVault} from "../src/EVault/EVault.sol";
import { BaseLogic, ERC20, ERC4626, Borrowing, Liquidation, Admin } from "../src/EVault/modules/EVaultModules.sol";
import {CreditVaultConnector} from "../lib/euler-cvc/src/CreditVaultConnector.sol";

import {TestERC20} from "./mocks/TestERC20.sol";
import {MockRiskManager} from "./mocks/MockRiskManager.sol";



contract EVaultUnitTests is Test {
	CreditVaultConnector public cvc;
    EVaultFactory public factory;
	TestERC20 assetTST;
	EVault public eTST;

    function setUp() public {
        address admin = vm.addr(1000);
        factory = new EVaultFactory(admin);

		cvc = new CreditVaultConnector();

		address erc20Module = address(new ERC20(address(factory), address(cvc)));
		address erc4626Module = address(new ERC4626(address(factory), address(cvc)));
		address borrowingModule = address(new Borrowing(address(factory), address(cvc)));
		address liquidationModule = address(new Liquidation(address(factory), address(cvc)));
		address adminModule = address(new Admin(address(factory), address(cvc)));

		address evaultImpl = address(new EVault(address(factory), address(cvc), erc20Module, erc4626Module, borrowingModule, liquidationModule, adminModule));

        vm.prank(admin);
		factory.setEVaultImplementation(evaultImpl);

        assetTST = new TestERC20("Test Token", "TST", 17, false);
        MockRiskManager rm = new MockRiskManager();
        eTST = EVault(factory.activateMarket(address(assetTST), address(rm), ""));
    }

    function test_basicViews() public {
        assertEq(eTST.name(), "Euler Pool: Test Token");
        assertEq(eTST.symbol(), "eTST");
    }

    function test_deposit() public {
		address user = vm.addr(10);

		assetTST.mint(user, 100e18);

		vm.prank(user);
		assetTST.approve(address(eTST), 10e18);

		vm.prank(user);
		eTST.deposit(1e18, user);

		// Asset was transferred

		assertEq(assetTST.balanceOf(user), 99e18);
		assertEq(assetTST.balanceOf(address(eTST)), 1e18);

		// Shares were issued

		assertEq(eTST.balanceOf(user), 1e18);
	}
}
