// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2, stdError} from "forge-std/Test.sol";

import {EVaultFactory} from "src/EVaultFactory/EVaultFactory.sol";

import {EVault} from "src/EVault/EVault.sol";
import {ERC20} from "src/EVault/modules/ERC20.sol";
import {ERC4626} from "src/EVault/modules/ERC4626.sol";
import {Borrowing} from "src/EVault/modules/Borrowing.sol";
import {Liquidation} from "src/EVault/modules/Liquidation.sol";
import {Admin} from "src/EVault/modules/Admin.sol";

import {IEVault, IERC20} from "src/EVault/IEVault.sol";

import {CreditVaultConnector} from "lib/euler-cvc/src/CreditVaultConnector.sol";

import {TestERC20} from "../../mocks/TestERC20.sol";
import {MockRiskManager} from "../../mocks/MockRiskManager.sol";

import {AssertionsCustomTypes} from "../../helpers/AssertionsCustomTypes.sol";

import "src/EVault/shared/Constants.sol";


contract EVaultTestBase is Test, AssertionsCustomTypes {
    CreditVaultConnector public cvc;
    EVaultFactory public factory;
    TestERC20 assetTST;
    IEVault public eTST;

    function setUp() public virtual {
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
        eTST = IEVault(factory.activateMarket(address(assetTST), address(rm), ""));
    }
}
