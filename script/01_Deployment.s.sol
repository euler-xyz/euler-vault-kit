// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import {EthereumVaultConnector} from "ethereum-vault-connector/EthereumVaultConnector.sol";
//import {StakingFreeRewardStreams} from "reward-streams/StakingFreeRewardStreams.sol";
//import {IEVC} from "reward-streams/StakingFreeRewardStreams.sol";
import {ProtocolConfig} from "../src/ProtocolConfig/ProtocolConfig.sol";
import {GenericFactory} from "../src/GenericFactory/GenericFactory.sol";
import {Base} from "../src/EVault/shared/Base.sol";
import {Initialize} from "../src/EVault/modules/Initialize.sol";
import {Token} from "../src/EVault/modules/Token.sol";
import {Vault} from "../src/EVault/modules/Vault.sol";
import {Borrowing} from "../src/EVault/modules/Borrowing.sol";
import {Liquidation} from "../src/EVault/modules/Liquidation.sol";
import {RiskManager} from "../src/EVault/modules/RiskManager.sol";
import {BalanceForwarder} from "../src/EVault/modules/BalanceForwarder.sol";
import {Governance} from "../src/EVault/modules/Governance.sol";
import {Dispatch} from "../src/EVault/Dispatch.sol";
import {EVault} from "../src/EVault/EVault.sol";
import {EVaultLens} from "../src/lens/EVaultLens.sol";
import {VaultInfo} from "../src/lens/LensTypes.sol";
import {MockPriceOracle} from "../test/mocks/MockPriceOracle.sol";
import {IRMTestDefault} from "../test/mocks/IRMTestDefault.sol";
import {TestERC20} from "../test/mocks/TestERC20.sol";

/// @title Deployment script
/// @notice This script is used for deploying a couple vaults along with supporting contracts for testing purposes
contract Deployment is Script {
    address internal constant PERMIT2_ADDRESS = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    function run() public returns (address[] memory vaults, address lens) {
        uint256 deployerPrivateKey = vm.deriveKey(vm.envString("MNEMONIC"), 0);
        address deployer = vm.addr(deployerPrivateKey);
        GenericFactory factory;
        vaults = new address[](3);

        vm.startBroadcast(deployerPrivateKey);

        {
            // deploy the EVC
            address evc = address(new EthereumVaultConnector());

            // deploy the reward streams contract
            address rewardStreams = address(0); //address(new StakingFreeRewardStreams(IEVC(evc), 10 days));

            // deploy the protocol config
            address protocolConfig = address(new ProtocolConfig(deployer, deployer));

            // define the integrations struct
            Base.Integrations memory integrations =
                Base.Integrations(evc, protocolConfig, rewardStreams, PERMIT2_ADDRESS);

            // deploy the EVault modules
            Dispatch.DeployedModules memory modules = Dispatch.DeployedModules({
                initialize: address(new Initialize(integrations)),
                token: address(new Token(integrations)),
                vault: address(new Vault(integrations)),
                borrowing: address(new Borrowing(integrations)),
                liquidation: address(new Liquidation(integrations)),
                riskManager: address(new RiskManager(integrations)),
                balanceForwarder: address(new BalanceForwarder(integrations)),
                governance: address(new Governance(integrations))
            });

            // deploy the factory
            factory = new GenericFactory(deployer);

            // set up the factory deploying the EVault implementation
            factory.setImplementation(address(new EVault(integrations, modules)));
        }

        {
            // deploy the price oracle
            address oracle = address(new MockPriceOracle());

            // deploy a default interest rate model
            address interestRateModel = address(new IRMTestDefault());

            address[] memory assets = new address[](vaults.length);
            for (uint256 i = 0; i < vaults.length; ++i) {
                // deploy mock ERC-20 tokens
                assets[i] = address(
                    new TestERC20(
                        string(abi.encodePacked("Asset ", i + 1)),
                        string(abi.encodePacked("A", i + 1)),
                        i == 2 ? 6 : 18,
                        false
                    )
                );

                // mint some tokens to the deployer
                TestERC20(assets[i]).mint(deployer, 1e6 * 10 ** TestERC20(assets[i]).decimals());

                // deploy vault proxies
                vaults[i] = factory.createProxy(true, abi.encodePacked(assets[i], oracle, assets[0]));

                // set vault name and symbol
                EVault(vaults[i]).setName(string(abi.encodePacked("Vault Asset ", i + 1)));
                EVault(vaults[i]).setSymbol(string(abi.encodePacked("VA", i + 1)));
            }

            // no need to further set up vault[0] because it is an escrow vault

            // set up vault[1]
            EVault(vaults[1]).setInterestRateModel(interestRateModel);
            EVault(vaults[1]).setLTV(vaults[0], 1e4 / 2, 0); // 50% LTV

            // set up vault[2]
            EVault(vaults[2]).setInterestRateModel(interestRateModel);
            EVault(vaults[2]).setLTV(vaults[0], 1e4 * 5 / 10, 0); // 50% LTV
            EVault(vaults[2]).setLTV(vaults[1], 1e4 * 8 / 10, 0); // 80% LTV

            // set up the price oracle
            MockPriceOracle(oracle).setPrice(assets[0], assets[0], 1e18); // 1 A1 = 1 A1
            MockPriceOracle(oracle).setPrice(assets[1], assets[0], 1e16); // 1 A2 = 0.01 A1
            MockPriceOracle(oracle).setPrice(assets[2], assets[0], 1e18); // 1 A3 = 1 A1
            MockPriceOracle(oracle).setResolvedVault(vaults[0], true);
            MockPriceOracle(oracle).setResolvedVault(vaults[1], true);
            MockPriceOracle(oracle).setResolvedVault(vaults[2], true);
        }

        // deploy the lens
        lens = address(new EVaultLens());

        vm.stopBroadcast();
    }
}
