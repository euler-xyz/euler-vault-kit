// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2, stdError} from "forge-std/Test.sol";

import {EFactory} from "src/EFactory/EFactory.sol";

import {EVault} from "src/EVault/EVault.sol";

import {Initialize} from "src/EVault/modules/Initialize.sol";
import {Token} from "src/EVault/modules/Token.sol";
import {ERC4626} from "src/EVault/modules/ERC4626.sol";
import {Borrowing} from "src/EVault/modules/Borrowing.sol";
import {Liquidation} from "src/EVault/modules/Liquidation.sol";
import {FeesInstance} from "src/EVault/modules/Fees.sol";

import {IEVault, IERC20} from "src/EVault/IEVault.sol";

import {EthereumVaultConnector} from "ethereum-vault-connector/EthereumVaultConnector.sol";

import {TestERC20} from "../../mocks/TestERC20.sol";
import {MockRiskManager} from "../../mocks/MockRiskManager.sol";

import {AssertionsCustomTypes} from "../../helpers/AssertionsCustomTypes.sol";

import "src/EVault/shared/Constants.sol";


contract EVaultTestBase is Test, AssertionsCustomTypes {
    EthereumVaultConnector public evc;
    EFactory public factory;
    TestERC20 assetTST;
    IEVault public eTST;

    function setUp() public virtual {
        address admin = vm.addr(1000);
        factory = new EFactory(admin);

		evc = new EthereumVaultConnector();

		address initializeModule = address(new Initialize(address(evc)));
		address tokenModule = address(new Token(address(evc)));
		address erc4626Module = address(new ERC4626(address(evc)));
		address borrowingModule = address(new Borrowing(address(evc)));
		address liquidationModule = address(new Liquidation(address(evc)));
		address feesModule = address(new FeesInstance(address(evc)));

		address evaultImpl = address(new EVault(address(evc), initializeModule, tokenModule, erc4626Module, borrowingModule, liquidationModule, feesModule));

        vm.prank(admin);
		factory.setImplementation(evaultImpl);

        assetTST = new TestERC20("Test Token", "TST", 17, false);
        MockRiskManager rm = new MockRiskManager();
        eTST = IEVault(factory.createProxy(true, abi.encodePacked(address(assetTST), address(rm))));
    }
}
