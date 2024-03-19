// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test, console2, stdError} from "forge-std/Test.sol";
import {DeployPermit2} from "permit2/test/utils/DeployPermit2.sol";
import {GenericFactory} from "src/GenericFactory/GenericFactory.sol";
import {EVault} from "src/EVault/EVault.sol";
import {ProtocolConfig} from "src/ProtocolConfig/ProtocolConfig.sol";
import {Dispatch} from "src/EVault/modules/Dispatch.sol";
import {Initialize} from "src/EVault/modules/Initialize.sol";
import {Token} from "src/EVault/modules/Token.sol";
import {Vault} from "src/EVault/modules/Vault.sol";
import {Borrowing} from "src/EVault/modules/Borrowing.sol";
import {Liquidation} from "src/EVault/modules/Liquidation.sol";
import {BalanceForwarder} from "src/EVault/modules/BalanceForwarder.sol";
import {Governance} from "src/EVault/modules/Governance.sol";
import {RiskManager} from "src/EVault/modules/RiskManager.sol";
import {IEVault, IERC20} from "src/EVault/IEVault.sol";
import {TypesLib} from "src/EVault/shared/types/Types.sol";
import {Base} from "src/EVault/shared/Base.sol";
import {EthereumVaultConnector} from "ethereum-vault-connector/EthereumVaultConnector.sol";
import {TestERC20} from "test/mocks/TestERC20.sol";
import {MockBalanceTracker} from "test/mocks/MockBalanceTracker.sol";
import {MockPriceOracle} from "test/mocks/MockPriceOracle.sol";
import {IRMTestDefault} from "test/mocks/IRMTestDefault.sol";
// import {AssertionsCustomTypes} from "test/helpers/AssertionsCustomTypes.sol";
import "src/EVault/shared/Constants.sol";

contract EVaultDeployerDefault is Test, DeployPermit2 {
    // ------------------------- Base -------------------------
    EthereumVaultConnector public evc;
    GenericFactory public factory;
    ProtocolConfig protocolConfig;
    MockPriceOracle oracle;
    Base.Integrations integrations;
    Dispatch.DeployedModules modules;
    address permit2;
    address balanceTracker;
    // ------------------------- Users -------------------------
    address admin;
    address feeReceiver;
    address unitOfAccount;
    address public user1;
    address public user2;
    // ------------------------- Modules -------------------------
    Initialize initializeModule;
    Token tokenModule;
    Vault vaultModule;
    Borrowing borrowingModule;
    Liquidation liquidationModule;
    RiskManager riskManagerModule;
    BalanceForwarder balanceForwarderModule;
    Governance governanceModule;
    // ------------------------- Assets -------------------------
    TestERC20 public assetTST1;
    TestERC20 public assetTST2;
    IEVault public eTST1;
    IEVault public eTST2;

    function setUp() public virtual {
        console2.log("user preparations");
        // ------------------------- Users Preparation -------------------------
        admin = vm.addr(1000);
        feeReceiver = makeAddr("feeReceiver");
        unitOfAccount = makeAddr("unitOfAccount");
        user1 = vm.addr(1001);
        user2 = vm.addr(1002);
        console2.log("base integrations");
        // ------------------------- Base Integrations -------------------------
        factory = new GenericFactory(admin);
        evc = new EthereumVaultConnector();
        protocolConfig = new ProtocolConfig(admin, feeReceiver);
        balanceTracker = address(new MockBalanceTracker());
        oracle = new MockPriceOracle();
        permit2 = deployPermit2();
        integrations = Base.Integrations(address(evc), address(protocolConfig), balanceTracker, permit2);
        console2.log("module deployments");
        // ------------------------- Module Deployments -------------------------
        modules = Dispatch.DeployedModules({
            initialize: address(new Initialize(integrations)),
            token: address(new Token(integrations)),
            vault: address(new Vault(integrations)),
            borrowing: address(new Borrowing(integrations)),
            liquidation: address(new Liquidation(integrations)),
            riskManager: address(new RiskManager(integrations)),
            balanceForwarder: address(new BalanceForwarder(integrations)),
            governance: address(new Governance(integrations))
        });
        address evaultImpl = address(new EVault(integrations, modules));
        console2.log("proxy deployments");
        // ------------------------- Proxy Deployments -------------------------
        vm.prank(admin);
        factory.setImplementation(evaultImpl);
        console2.log("asset deployments");
        // ------------------------- Asset Deployments -------------------------
        assetTST1 = new TestERC20("Test Token 1", "TST1", 18, false);
        assetTST2 = new TestERC20("Test Token 2", "TST2", 18, false);
        console2.log("eVault deployments");
        // ------------------------- EVault Deployments -------------------------
        eTST1 = IEVault(factory.createProxy(true, abi.encodePacked(address(assetTST1), address(oracle), unitOfAccount)));
        eTST1.setIRM(address(new IRMTestDefault()));
        eTST2 = IEVault(factory.createProxy(true, abi.encodePacked(address(assetTST2), address(oracle), unitOfAccount)));
        eTST2.setIRM(address(new IRMTestDefault()));
    }
}
