// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Libraries
import {EthereumVaultConnector} from "ethereum-vault-connector/EthereumVaultConnector.sol";

// Contracts
import {GenericFactory} from "src/GenericFactory/GenericFactory.sol";
import {EVault} from "src/EVault/EVault.sol";
import {ProtocolConfig} from "src/ProtocolConfig/ProtocolConfig.sol";
import {IRMClassStable} from "src/interestRateModels/IRMClassStable.sol";
import {Base} from "src/EVault/shared/Base.sol";

// Modules
import {Initialize} from "src/EVault/modules/Initialize.sol";
import {Token} from "src/EVault/modules/Token.sol";
import {Vault} from "src/EVault/modules/Vault.sol";
import {Borrowing} from "src/EVault/modules/Borrowing.sol";
import {Liquidation} from "src/EVault/modules/Liquidation.sol";
import {BalanceForwarder} from "src/EVault/modules/BalanceForwarder.sol";
import {Governance} from "src/EVault/modules/Governance.sol";
import {RiskManager} from "src/EVault/modules/RiskManager.sol";

// Test Contracts
import {TestERC20} from "../mocks/TestERC20.sol";
import {MockBalanceTracker} from "../mocks/MockBalanceTracker.sol";
import {MockPriceOracle} from "../mocks/MockPriceOracle.sol";
import {Actor} from "./utils/Actor.sol";
import {BaseTest} from "./base/BaseTest.t.sol";
import {EVaultExtended} from "test/invariants/helpers/extended/EVaultExtended.sol";

/// @title Setup
/// @notice Setup contract for the invariant test Suite, inherited by Tester
contract Setup is BaseTest {
    function _setUp() internal {
        // Deplopy EVC and needed contracts
        _deployProtocolCore();

        // Deploy vaults
        _deployVaults();
    }

    function _deployProtocolCore() internal {

        // Deploy the EVC
        evc = new EthereumVaultConnector();

        // Setup the protocol config
        feeReceiver = _makeAddr("feeReceiver");
        protocolConfig = new ProtocolConfig(address(this), feeReceiver);

        // Deploy the Balance Tracker and the Price Oracle
        balanceTracker = address(new MockBalanceTracker());
        oracle = new MockPriceOracle();

        // Deploy the mock assets
        assetTST = new TestERC20("Test Token", "TST", 18, false);
        assetTST2 = new TestERC20("Test Token 2", "TST2", 18, false);
        baseAssets.push(address(assetTST));
        baseAssets.push(address(assetTST2));
    }

    function _deployVaults() internal {
        // Deploy the modules
        Base.Integrations memory integrations = Base.Integrations(address(evc), address(protocolConfig), balanceTracker);
        
        address initializeModule = address(new Initialize(integrations));
        address tokenModule = address(new Token(integrations));
        address vaultModule = address(new Vault(integrations));
        address borrowingModule = address(new Borrowing(integrations));
        address liquidationModule = address(new Liquidation(integrations));
        address riskManagerModule = address(new RiskManager(integrations));
        address balanceForwarderModule = address(new BalanceForwarder(integrations));
        address governanceModule = address(new Governance(integrations));

        // Deploy the vault implementation
        address evaultImpl = address(
            new EVaultExtended(
                integrations,
                initializeModule,
                tokenModule,
                vaultModule,
                borrowingModule,
                liquidationModule,
                riskManagerModule,
                balanceForwarderModule,
                governanceModule
            )
        );

        // Deploy the vault factory and set the implementation
        factory = new GenericFactory(address(this));
        factory.setImplementation(evaultImpl);

        // Deploy the vaults
        eTST = EVaultExtended(factory.createProxy(true, abi.encodePacked(address(assetTST), address(oracle), unitOfAccount)));
        eTST.setIRM(address(new IRMClassStable()), "");
        vaults.push(address(eTST));

        eTST2 = EVaultExtended(factory.createProxy(true, abi.encodePacked(address(assetTST2), address(oracle), unitOfAccount)));
        eTST2.setIRM(address(new IRMClassStable()), "");
        vaults.push(address(eTST2));
    }

    function _setUpActors() internal {
        address[] memory addresses = new address[](3);
        addresses[0] = USER1;
        addresses[1] = USER2;
        addresses[2] = USER3;

        address[] memory tokens = new address[](2);
        tokens[0] = address(assetTST);
        tokens[1] = address(assetTST2);

        for (uint256 i = 0; i < NUMBER_OF_ACTORS; i++) {
            // Deply actor proxies and approve system contracts
            address _actor = _setUpActor(addresses[i], tokens, vaults);

            // Mint initial balances to actors
            for (uint256 j = 0; j < tokens.length; j++) {
                TestERC20 _token = TestERC20(tokens[j]);
                _token.mint(_actor, INITIAL_BALANCE);
            }
            actorAddresses.push(_actor);
        }
    }

    function _setUpActor(
        address userAddress,
        address[] memory tokens,
        address[] memory callers
    ) internal returns (address actorAddress) {
        bool success;
        Actor _actor = new Actor(tokens, callers);
        actors[userAddress] = _actor;
        (success,) = address(_actor).call{value: INITIAL_ETH_BALANCE}("");
        assert(success);
        actorAddress = address(_actor);
    }
}
