// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import {Utils} from "./Utils.s.sol";
import "./01_Deployment.s.sol";
import {Core} from "src/ProductLines/Core.sol";

contract DeploymentAll is Utils {
    struct DeploymentAllDeployers {
        DeploymentAssets deploymentAssets;
        DeploymentIntegrations deploymentIntegrations;
        DeploymentPeripherals deploymentPeripherals;
        DeploymentEVault deploymentEVault;
        DeploymentFactory deploymentFactory;
        DeploymentVaults deploymentVaults;
    }

    struct DeploymentAllConfigVault {
        address asset;
        string name;
        string symbol;
        address unitOfAccount;
        bool upgradable;
    }

    struct DeploymentAllResult {
        address[] assets;
        address[] vaults;
        address oracle;
        address interestRateModel;
        address factory;
        address implementation;
        Base.Integrations integrations;
        Dispatch.DeployedModules modules;
        address lens;
    }

    function run() public returns (DeploymentAllResult memory result) {
        string memory json = getConfig("02_DeploymentAll", "DeploymentAll.json");
        bytes memory configAdminBytes = vm.parseJson(json, ".admin");
        bytes memory configFeeReceiverBytes = vm.parseJson(json, ".feeReceiver");
        address admin = abi.decode(configAdminBytes, (address));
        address feeReceiver = abi.decode(configFeeReceiverBytes, (address));

        DeploymentAllConfigVault[] memory config;
        if (vm.keyExistsJson(json, ".vaults")) {
            bytes memory configVaultsBytes = vm.parseJson(json, ".vaults");
            config = abi.decode(configVaultsBytes, (DeploymentAllConfigVault[]));
        }

        ConfigAsset[] memory configAssets;
        ConfigVault[] memory configVaults;
        if (config.length == 0) {
            (configAssets, configVaults) = getTestSetup();
        } else {
            configVaults = new ConfigVault[](config.length);
            for (uint256 i = 0; i < config.length; ++i) {
                configVaults[i] = ConfigVault({
                    asset: config[i].asset,
                    oracle: result.oracle,
                    unitOfAccount: config[i].unitOfAccount,
                    interestRateModel: result.interestRateModel,
                    name: config[i].name,
                    symbol: config[i].symbol,
                    upgradable: config[i].upgradable
                });
            }
        }

        result = deployInternal(admin, feeReceiver, configAssets, configVaults, true);

        string memory object = vm.serializeAddress("", "assets", result.assets);
        object = vm.serializeAddress("", "vaults", result.vaults);
        object = vm.serializeAddress("", "admin", admin);
        object = vm.serializeAddress("", "feeReceiver", feeReceiver);
        object = vm.serializeAddress("", "oracle", result.oracle);
        object = vm.serializeAddress("", "interestRateModel", result.interestRateModel);
        object = vm.serializeAddress("", "factory", result.factory);
        object = vm.serializeAddress("", "implementation", result.implementation);
        object = vm.serializeAddress("", "lens", result.lens);

        string memory object2 = vm.serializeAddress("integrations", "evc", result.integrations.evc);
        object2 = vm.serializeAddress("integrations", "protocolConfig", result.integrations.protocolConfig);
        object2 = vm.serializeAddress("integrations", "balanceTracker", result.integrations.balanceTracker);
        object2 = vm.serializeAddress("integrations", "permit2", result.integrations.permit2);

        string memory object3 = vm.serializeAddress("modules", "initialize", result.modules.initialize);
        object3 = vm.serializeAddress("modules", "token", result.modules.token);
        object3 = vm.serializeAddress("modules", "vault", result.modules.vault);
        object3 = vm.serializeAddress("modules", "borrowing", result.modules.borrowing);
        object3 = vm.serializeAddress("modules", "liquidation", result.modules.liquidation);
        object3 = vm.serializeAddress("modules", "riskManager", result.modules.riskManager);
        object3 = vm.serializeAddress("modules", "balanceForwarder", result.modules.balanceForwarder);
        object3 = vm.serializeAddress("modules", "governance", result.modules.governance);

        object = vm.serializeString("", "integrations", object2);
        object = vm.serializeString("", "modules", object3);

        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/output/02_DeploymentAll/DeploymentAll.json"));
    }

    function deploy(address admin, address feeReceiver) public returns (DeploymentAllResult memory) {
        (ConfigAsset[] memory configAssets, ConfigVault[] memory configVaults) = getTestSetup();
        return deployInternal(admin, feeReceiver, configAssets, configVaults, false);
    }

    function deployInternal(
        address admin,
        address feeReceiver,
        ConfigAsset[] memory configAssets,
        ConfigVault[] memory configVaults,
        bool configureLTVAndOracle
    ) internal returns (DeploymentAllResult memory result) {
        DeploymentAllDeployers memory deployers = DeploymentAllDeployers({
            deploymentAssets: new DeploymentAssets(),
            deploymentIntegrations: new DeploymentIntegrations(),
            deploymentPeripherals: new DeploymentPeripherals(),
            deploymentEVault: new DeploymentEVault(),
            deploymentFactory: new DeploymentFactory(),
            deploymentVaults: new DeploymentVaults()
        });

        result.integrations = deployers.deploymentIntegrations.deploy(admin, feeReceiver);
        (result.oracle, result.interestRateModel, result.lens) = deployers.deploymentPeripherals.deploy();
        (result.modules, result.implementation) = deployers.deploymentEVault.deploy(result.integrations);
        result.factory = deployers.deploymentFactory.deploy(result.implementation, admin);

        if (configAssets.length != 0) {
            result.assets = deployers.deploymentAssets.deploy(configAssets, admin, 1e6);

            configVaults[0].asset = result.assets[0];
            configVaults[0].unitOfAccount = result.assets[0];
            configVaults[0].oracle = result.oracle;
            configVaults[0].interestRateModel = result.interestRateModel;

            configVaults[1].asset = result.assets[1];
            configVaults[1].unitOfAccount = result.assets[0];
            configVaults[1].oracle = result.oracle;
            configVaults[1].interestRateModel = result.interestRateModel;

            configVaults[2].asset = result.assets[2];
            configVaults[2].unitOfAccount = result.assets[0];
            configVaults[2].oracle = result.oracle;
            configVaults[2].interestRateModel = result.interestRateModel;

            result.vaults = deployers.deploymentVaults.deploy(configVaults, result.factory);

            if (configureLTVAndOracle) {
                startBroadcast();  
                // no need to set up vaults[0] (escrow vault)

                // set up vaults[1]
                EVault(result.vaults[1]).setLTV(result.vaults[0], 1e4 / 2, 0); // 50% LTV

                // set up vaults[2]
                EVault(result.vaults[2]).setLTV(result.vaults[0], 1e4 * 5 / 10, 0); // 50% LTV
                EVault(result.vaults[2]).setLTV(result.vaults[1], 1e4 * 8 / 10, 0); // 80% LTV

                // set up the price oracle
                MockPriceOracle(result.oracle).setPrice(configVaults[0].asset, configVaults[0].asset, 1e18); // 1 A1 = 1 A1
                MockPriceOracle(result.oracle).setPrice(configVaults[1].asset, configVaults[0].asset, 1e16); // 1 A2 = 0.01 A1
                MockPriceOracle(result.oracle).setPrice(configVaults[2].asset, configVaults[0].asset, 1e18); // 1 A3 = 1 A1
                MockPriceOracle(result.oracle).setResolvedVault(result.vaults[0], true);
                MockPriceOracle(result.oracle).setResolvedVault(result.vaults[1], true);
                MockPriceOracle(result.oracle).setResolvedVault(result.vaults[2], true);

                vm.stopBroadcast();
            }
        } else {
            result.vaults = deployers.deploymentVaults.deploy(configVaults, result.factory);
        }

        startBroadcast();

        for (uint256 i = 0; i < result.vaults.length; ++i) {
            EVault(result.vaults[i]).setGovernorAdmin(admin);
        }

        vm.stopBroadcast();
    }

    function getTestSetup() internal pure returns (ConfigAsset[] memory, ConfigVault[] memory) {
        ConfigAsset[] memory configAssets = new ConfigAsset[](3);
        ConfigVault[] memory configVaults = new ConfigVault[](3);

        configAssets[0] = ConfigAsset({name: "Test Token", symbol: "TST", decimals: 18, secureMode: false});
        configAssets[1] = ConfigAsset({name: "Test Token 2", symbol: "TST2", decimals: 18, secureMode: false});
        configAssets[2] = ConfigAsset({name: "Test Token 3", symbol: "TST3", decimals: 6, secureMode: false});

        configVaults[0].name = "Test Vault";
        configVaults[0].symbol = "TV";
        configVaults[0].upgradable = false;

        configVaults[1].name = "Test Vault 2";
        configVaults[1].symbol = "TV2";
        configVaults[1].upgradable = true;

        configVaults[2].name = "Test Vault 3";
        configVaults[2].symbol = "TV3";
        configVaults[2].upgradable = true;

        return (configAssets, configVaults);
    }
}
