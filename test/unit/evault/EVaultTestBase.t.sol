// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2, stdError} from "forge-std/Test.sol";

import {GenericFactory} from "src/GenericFactory/GenericFactory.sol";

import {EVault} from "src/EVault/EVault.sol";
import {IRMClassStable} from "src/interestRateModels/IRMClassStable.sol";
import {ProtocolAdmin} from "src/ProtocolAdmin/ProtocolAdmin.sol";

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

import {AssertionsCustomTypes} from "../../helpers/AssertionsCustomTypes.sol";


import "src/EVault/shared/Constants.sol";

contract EVaultTestBase is Test, AssertionsCustomTypes {
    EthereumVaultConnector public evc;
    address protocolAdmin;
    address balanceTracker;
    GenericFactory public factory;
    TestERC20 assetTST;
    IEVault public eTST;

    function setUp() public virtual {
        address admin = vm.addr(1000);
        factory = new GenericFactory(admin);

        evc = new EthereumVaultConnector();
        protocolAdmin = address(new ProtocolAdmin(address(0), address(0)));
        balanceTracker = address(new MockBalanceTracker());

        address initializeModule = address(new Initialize(address(evc), protocolAdmin, balanceTracker));
        address tokenModule = address(new Token(address(evc), protocolAdmin, balanceTracker));
        address erc4626Module = address(new ERC4626(address(evc), protocolAdmin, balanceTracker));
        address borrowingModule = address(new Borrowing(address(evc), protocolAdmin, balanceTracker));
        address liquidationModule = address(new Liquidation(address(evc), protocolAdmin, balanceTracker));
        address feesModule = address(new FeesInstance(address(evc), protocolAdmin, balanceTracker));
        address balanceForwarderModule = address(new BalanceForwarder(address(evc), protocolAdmin, balanceTracker));
        address governanceModule = address(new Governance(address(evc), protocolAdmin, balanceTracker));
        address riskManagerModule = address(new RiskManager(address(evc), protocolAdmin, balanceTracker));

        address evaultImpl = address(
            new EVault(
                address(evc),
                protocolAdmin,
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

        assetTST = new TestERC20("Test Token", "TST", 17, false);

        eTST = IEVault(factory.createProxy(true, abi.encodePacked(address(assetTST))));

        address irm = address(new IRMClassStable());
        eTST.setIRM(irm, "");

        //address oracle = address(0);
        // FIXME: set oracle
    }
}
