// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import {Utils} from "./Utils.s.sol";
import {EthereumVaultConnector} from "ethereum-vault-connector/EthereumVaultConnector.sol";
//import {StakingFreeRewardStreams} from "reward-streams/StakingFreeRewardStreams.sol";
//import {IEVC} from "reward-streams/StakingFreeRewardStreams.sol";
import {DeployPermit2} from "permit2/test/utils/DeployPermit2.sol";
import {ProtocolConfig} from "../src/ProtocolConfig/ProtocolConfig.sol";
import {Base} from "../src/EVault/shared/Base.sol";
import {Dispatch} from "../src/EVault/Dispatch.sol";
import {Initialize} from "../src/EVault/modules/Initialize.sol";
import {Token} from "../src/EVault/modules/Token.sol";
import {Vault} from "../src/EVault/modules/Vault.sol";
import {Borrowing} from "../src/EVault/modules/Borrowing.sol";
import {Liquidation} from "../src/EVault/modules/Liquidation.sol";
import {BalanceForwarder} from "../src/EVault/modules/BalanceForwarder.sol";
import {Governance} from "../src/EVault/modules/Governance.sol";
import {RiskManager} from "../src/EVault/modules/RiskManager.sol";
import {GenericFactory} from "../src/GenericFactory/GenericFactory.sol";
import {EVault} from "../src/EVault/EVault.sol";
import {EVaultLens} from "../src/lens/EVaultLens.sol";
import {MockPriceOracle} from "../test/mocks/MockPriceOracle.sol";
import {IRMTestDefault} from "../test/mocks/IRMTestDefault.sol";
import {MockBalanceTracker} from "../test/mocks/MockBalanceTracker.sol";
import {TestERC20} from "../test/mocks/TestERC20.sol";

struct ConfigIntegrations {
    address balanceTracker;
    address evc;
    address permit2;
    address protocolConfig;
}

struct ConfigAsset {
    uint8 decimals;
    string name;
    bool secureMode;
    string symbol;
}

struct ConfigVault {
    address asset;
    address interestRateModel;
    string name;
    address oracle;
    string symbol;
    address unitOfAccount;
    bool upgradable;
}

contract DeploymentPeripherals is Utils {
    function run() public returns (address oracle, address interestRateModel, address lens) {
        (oracle, interestRateModel, lens) = deployInternal();

        string memory object = vm.serializeAddress("peripherals", "oracle", oracle);
        object = vm.serializeAddress("peripherals", "interestRateModel", interestRateModel);
        object = vm.serializeAddress("peripherals", "lens", lens);
        vm.writeJson(
            vm.serializeString("", "peripherals", object),
            string.concat(vm.projectRoot(), "/script/output/01_Deployment/Peripherals.json")
        );
    }

    function deploy() public returns (address, address, address) {
        return deployInternal();
    }

    function deployInternal() internal returns (address oracle, address interestRateModel, address lens) {
        startBroadcast();

        // deploy the price oracle
        oracle = address(new MockPriceOracle());

        // deploy a default interest rate model
        interestRateModel = address(new IRMTestDefault());

        // deploy the lens
        lens = address(new EVaultLens());

        vm.stopBroadcast();
    }
}

contract DeploymentIntegrations is Utils {
    address internal constant PERMIT2_ADDRESS = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address internal _admin;
    address internal _feeReceiver;

    function run() public returns (Base.Integrations memory integrations) {
        integrations = deployInternal(true);

        string memory object = vm.serializeAddress("integrations", "evc", integrations.evc);
        object = vm.serializeAddress("integrations", "protocolConfig", integrations.protocolConfig);
        object = vm.serializeAddress("integrations", "balanceTracker", integrations.balanceTracker);
        object = vm.serializeAddress("integrations", "permit2", integrations.permit2);
        vm.writeJson(
            vm.serializeString("", "integrations", object),
            string.concat(vm.projectRoot(), "/script/output/01_Deployment/Integrations.json")
        );
    }

    function deploy(address admin, address feeReceiver) public returns (Base.Integrations memory) {
        _admin = admin;
        _feeReceiver = feeReceiver;
        return deployInternal(false);
    }

    function deployInternal(bool useConfig) internal returns (Base.Integrations memory integrations) {
        DeployPermit2 deployPermit2 = new DeployPermit2();

        address admin;
        address feeReceiver;
        if (useConfig) {
            string memory json = getConfig("01_Deployment", "Integrations.json");
            bytes memory configAdminBytes = vm.parseJson(json, ".protocolConfig.admin");
            bytes memory configFeeReceiverBytes = vm.parseJson(json, ".protocolConfig.feeReceiver");
            admin = abi.decode(configAdminBytes, (address));
            feeReceiver = abi.decode(configFeeReceiverBytes, (address));
        } else {
            admin = _admin;
            feeReceiver = _feeReceiver;
        }

        startBroadcast();

        // deploy the EVC
        integrations.evc = address(new EthereumVaultConnector());

        // deploy the protocol config
        integrations.protocolConfig = address(new ProtocolConfig(admin, feeReceiver));

        // deploy the reward streams contract
        integrations.balanceTracker = address(new MockBalanceTracker());

        // assign permit2 address
        integrations.permit2 = PERMIT2_ADDRESS;

        // deploy permit2 if it's not already deployed
        if (PERMIT2_ADDRESS.code.length == 0) {
            deployPermit2.deployPermit2();
        }

        vm.stopBroadcast();
    }
}

contract DeploymentEVault is Utils {
    Base.Integrations internal _configIntegrations;

    function run() public returns (Dispatch.DeployedModules memory modules, address implementation) {
        (modules, implementation) = deployInternal(true);

        string memory object = vm.serializeAddress("", "implementation", implementation);
        object = vm.serializeAddress("modules", "initialize", modules.initialize);
        object = vm.serializeAddress("modules", "token", modules.token);
        object = vm.serializeAddress("modules", "vault", modules.vault);
        object = vm.serializeAddress("modules", "borrowing", modules.borrowing);
        object = vm.serializeAddress("modules", "liquidation", modules.liquidation);
        object = vm.serializeAddress("modules", "riskManager", modules.riskManager);
        object = vm.serializeAddress("modules", "balanceForwarder", modules.balanceForwarder);
        object = vm.serializeAddress("modules", "governance", modules.governance);
        vm.writeJson(
            vm.serializeString("", "modules", object),
            string.concat(vm.projectRoot(), "/script/output/01_Deployment/EVault.json")
        );
    }

    function deploy(Base.Integrations memory configIntegrations)
        public
        returns (Dispatch.DeployedModules memory, address)
    {
        _configIntegrations = configIntegrations;
        return deployInternal(false);
    }

    function deployInternal(bool useConfig)
        internal
        returns (Dispatch.DeployedModules memory modules, address implementation)
    {
        Base.Integrations memory integrations;
        if (useConfig) {
            string memory json = getConfig("01_Deployment", "EVault.json");
            bytes memory configIntegrationsBytes = vm.parseJson(json, ".integrations");
            ConfigIntegrations memory configIntegrations = abi.decode(configIntegrationsBytes, (ConfigIntegrations));

            integrations = Base.Integrations({
                evc: configIntegrations.evc,
                protocolConfig: configIntegrations.protocolConfig,
                balanceTracker: configIntegrations.balanceTracker,
                permit2: configIntegrations.permit2
            });
        } else {
            integrations = _configIntegrations;
        }

        startBroadcast();

        // deploy the EVault modules
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

        implementation = address(new EVault(integrations, modules));

        vm.stopBroadcast();
    }
}

contract DeploymentFactory is Utils {
    address internal _implementation;
    address internal _admin;

    function run() public returns (address factory) {
        factory = deployInternal(true);

        vm.writeJson(
            vm.serializeAddress("", "factory", factory),
            string.concat(vm.projectRoot(), "/script/output/01_Deployment/Factory.json")
        );
    }

    function deploy(address implementation, address admin) public returns (address) {
        _implementation = implementation;
        _admin = admin;
        return deployInternal(false);
    }

    function deployInternal(bool useConfig) internal returns (address factory) {
        address implementation;
        address admin;
        if (useConfig) {
            string memory json = getConfig("01_Deployment", "Factory.json");
            bytes memory configImplementationBytes = vm.parseJson(json, ".implementation");
            bytes memory configAdminBytes = vm.parseJson(json, ".admin");
            implementation = abi.decode(configImplementationBytes, (address));
            admin = abi.decode(configAdminBytes, (address));
        } else {
            implementation = _implementation;
            admin = _admin;
        }

        startBroadcast();

        // deploy the factory
        factory = address(new GenericFactory(getDeployer()));

        // set up the factory deploying the EVault implementation
        GenericFactory(factory).setImplementation(implementation);

        // set the factory admin
        GenericFactory(factory).setUpgradeAdmin(admin);

        vm.stopBroadcast();
    }
}

contract DeploymentAssets is Utils {
    ConfigAsset[] internal _configAssets;
    address internal _mintTo;
    uint256 internal _mintAmount;

    function run() public returns (address[] memory assets) {
        assets = deployInternal(true);

        vm.writeJson(
            vm.serializeAddress("", "assets", assets),
            string.concat(vm.projectRoot(), "/script/output/01_Deployment/Assets.json")
        );
    }

    function deploy(ConfigAsset[] memory configAssets, address mintTo, uint256 mintAmount)
        public
        returns (address[] memory)
    {
        for (uint256 i = 0; i < configAssets.length; ++i) {
            _configAssets.push(configAssets[i]);
        }
        _mintTo = mintTo;
        _mintAmount = mintAmount;

        return deployInternal(false);
    }

    function deployInternal(bool useConfig) internal returns (address[] memory assets) {
        ConfigAsset[] memory configAssets;
        address mintTo;
        uint256 mintAmount;
        if (useConfig) {
            string memory json = getConfig("01_Deployment", "Assets.json");
            bytes memory configAssetsBytes = vm.parseJson(json, ".assets");
            bytes memory configMintToBytes = vm.parseJson(json, ".mintTo");
            bytes memory configMintAmountBytes = vm.parseJson(json, ".mintAmount");
            configAssets = abi.decode(configAssetsBytes, (ConfigAsset[]));
            mintTo = abi.decode(configMintToBytes, (address));
            mintAmount = abi.decode(configMintAmountBytes, (uint256));
        } else {
            configAssets = _configAssets;
            mintTo = _mintTo;
            mintAmount = _mintAmount;
        }

        assets = new address[](configAssets.length);
        startBroadcast();

        for (uint256 i = 0; i < assets.length; ++i) {
            assets[i] = address(
                new TestERC20(
                    configAssets[i].name, configAssets[i].symbol, configAssets[i].decimals, configAssets[i].secureMode
                )
            );

            if (mintAmount > 0) TestERC20(assets[i]).mint(mintTo, mintAmount * 10 ** configAssets[i].decimals);
        }

        vm.stopBroadcast();
    }
}

contract DeploymentVaults is Utils {
    ConfigVault[] internal _configVaults;
    address internal _factory;

    function run() public returns (address[] memory vaults) {
        vaults = deployInternal(true);

        vm.writeJson(
            vm.serializeAddress("", "vaults", vaults),
            string.concat(vm.projectRoot(), "/script/output/01_Deployment/Vaults.json")
        );
    }

    function deploy(ConfigVault[] memory configVaults, address factory) public returns (address[] memory) {
        for (uint256 i = 0; i < configVaults.length; ++i) {
            _configVaults.push(configVaults[i]);
        }
        _factory = factory;

        return deployInternal(false);
    }

    function deployInternal(bool useConfig) internal returns (address[] memory vaults) {
        ConfigVault[] memory configVaults;
        address factory;
        if (useConfig) {
            string memory json = getConfig("01_Deployment", "Vaults.json");
            bytes memory configVaultsBytes = vm.parseJson(json, ".vaults");
            bytes memory configFactoryBytes = vm.parseJson(json, ".factory");
            configVaults = abi.decode(configVaultsBytes, (ConfigVault[]));
            factory = abi.decode(configFactoryBytes, (address));
        } else {
            configVaults = _configVaults;
            factory = _factory;
        }

        vaults = new address[](configVaults.length);
        startBroadcast();

        for (uint256 i = 0; i < vaults.length; ++i) {
            // deploy vault proxies
            vaults[i] = GenericFactory(factory).createProxy(
                configVaults[i].upgradable,
                abi.encodePacked(configVaults[i].asset, configVaults[i].oracle, configVaults[i].unitOfAccount)
            );

            // set vault name and symbol
            EVault(vaults[i]).setName(configVaults[i].name);
            EVault(vaults[i]).setSymbol(configVaults[i].symbol);

            // set interest rate model
            EVault(vaults[i]).setInterestRateModel(configVaults[i].interestRateModel);
        }

        vm.stopBroadcast();
    }
}
