// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2, stdError} from "forge-std/Test.sol";

import {GenericFactory} from "src/GenericFactory/GenericFactory.sol";

import {EVault} from "src/EVault/EVault.sol";
import {IRMClassStable} from "src/interestRateModels/IRMClassStable.sol";
import {ProtocolConfig} from "src/ProtocolConfig/ProtocolConfig.sol";

import {Initialize} from "src/EVault/modules/Initialize.sol";
import {Token} from "src/EVault/modules/Token.sol";
import {ERC4626} from "src/EVault/modules/ERC4626.sol";
import {Borrowing} from "src/EVault/modules/Borrowing.sol";
import {Liquidation} from "src/EVault/modules/Liquidation.sol";
import {FeesInstance} from "src/EVault/modules/Fees.sol";
import {BalanceForwarder} from "src/EVault/modules/BalanceForwarder.sol";
import {Governance} from "src/EVault/modules/Governance.sol";
import {RiskManager} from "src/EVault/modules/RiskManager.sol";

import {IEVault, IERC20} from "src/EVault/IEVault.sol";

import {TypesLib} from "src/EVault/shared/types/Types.sol";

import {EthereumVaultConnector} from "ethereum-vault-connector/EthereumVaultConnector.sol";

import {TestERC20} from "../../mocks/TestERC20.sol";
import {MockBalanceTracker} from "../../mocks/MockBalanceTracker.sol";
import {MockPriceOracle} from "../../mocks/MockPriceOracle.sol";

import {AssertionsCustomTypes} from "../../helpers/AssertionsCustomTypes.sol";


import "src/EVault/shared/Constants.sol";

contract EVaultTestBase is Test, AssertionsCustomTypes {
    EthereumVaultConnector public evc;
    address admin;
    address feeReceiver;
    address protocolConfig;
    address balanceTracker;
    MockPriceOracle oracle;
    address unitOfAccount;
    GenericFactory public factory;

    TestERC20 assetTST;
    TestERC20 assetTST2;

    IEVault public eTST;
    IEVault public eTST2;

    function setUp() public virtual {
        admin = vm.addr(1000);
        feeReceiver = makeAddr("feeReceiver");
        factory = new GenericFactory(admin);

        evc = new EthereumVaultConnector();
        protocolConfig = address(new ProtocolConfig(admin, feeReceiver));
        balanceTracker = address(new MockBalanceTracker());
        oracle = new MockPriceOracle();
        unitOfAccount = address(1);

        address initializeModule = address(new Initialize(address(evc), protocolConfig, balanceTracker));
        address tokenModule = address(new Token(address(evc), protocolConfig, balanceTracker));
        address erc4626Module = address(new ERC4626(address(evc), protocolConfig, balanceTracker));
        address borrowingModule = address(new Borrowing(address(evc), protocolConfig, balanceTracker));
        address liquidationModule = address(new Liquidation(address(evc), protocolConfig, balanceTracker));
        address feesModule = address(new FeesInstance(address(evc), protocolConfig, balanceTracker));
        address balanceForwarderModule = address(new BalanceForwarder(address(evc), protocolConfig, balanceTracker));
        address governanceModule = address(new Governance(address(evc), protocolConfig, balanceTracker));
        address riskManagerModule = address(new RiskManager(address(evc), protocolConfig, balanceTracker));

        address evaultImpl = address(
            new EVault(
                address(evc),
                protocolConfig,
                balanceTracker,
                initializeModule,
                tokenModule,
                erc4626Module,
                borrowingModule,
                liquidationModule,
                feesModule,
                balanceForwarderModule,
                governanceModule,
                riskManagerModule
            )
        );

        vm.prank(admin);
        factory.setImplementation(evaultImpl);

        assetTST = new TestERC20("Test Token", "TST", 18, false);
        assetTST2 = new TestERC20("Test Token 2", "TST2", 18, false);

        eTST = IEVault(factory.createProxy(true, abi.encodePacked(address(assetTST), address(oracle), unitOfAccount)));
        eTST.setIRM(address(new IRMClassStable()), "");

        eTST2 = IEVault(factory.createProxy(true, abi.encodePacked(address(assetTST2), address(oracle), unitOfAccount)));
        eTST2.setIRM(address(new IRMClassStable()), "");
    }
}
