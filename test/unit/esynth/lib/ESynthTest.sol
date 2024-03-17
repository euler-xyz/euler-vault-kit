// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {EthereumVaultConnector as EVC} from "ethereum-vault-connector/EthereumVaultConnector.sol";
import {ESynth} from "src/ESynth/Esynth.sol";
import {ESVault} from "src/ESVault/ESVault.sol";
import {Initialize} from "src/EVault/modules/Initialize.sol";
import {Token} from "src/EVault/modules/Token.sol";
import {Vault} from "src/EVault/modules/Vault.sol";
import {Borrowing} from "src/EVault/modules/Borrowing.sol";
import {Liquidation} from "src/EVault/modules/Liquidation.sol";
import {BalanceForwarder} from "src/EVault/modules/BalanceForwarder.sol";
import {Governance} from "src/EVault/modules/Governance.sol";
import {RiskManager} from "src/EVault/modules/RiskManager.sol";

import {DeployPermit2} from "permit2/test/utils/DeployPermit2.sol";

import {ProtocolConfig} from "src/ProtocolConfig/ProtocolConfig.sol";
import {MockPriceOracle} from "../../../mocks/MockPriceOracle.sol";
import {MockBalanceTracker} from "../../../mocks/MockBalanceTracker.sol";
import {TypesLib} from "src/EVault/shared/types/Types.sol";
import {Base} from "src/EVault/shared/Base.sol";

contract ESynthTest is Test, DeployPermit2 {
    EVC public evc;
    ESynth public esynth;
    ESVault public esvault;
    address admin;
    address feeReceiver;
    ProtocolConfig protocolConfig;
    address balanceTracker;
    MockPriceOracle oracle;
    address permit2;
    address unitOfAccount;
    address user1;
    address user2;

    function setUp() public {
        evc = new EVC();
        esynth = new ESynth(evc, "SynthTest", "sTST");

        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        admin = vm.addr(1000);
        feeReceiver = makeAddr("feeReceiver");

        protocolConfig = new ProtocolConfig(admin, feeReceiver);
        balanceTracker = address(new MockBalanceTracker());
        oracle = new MockPriceOracle();
        unitOfAccount = address(1);
        permit2 = deployPermit2();

        Base.Integrations memory integrations =
            Base.Integrations(address(evc), address(protocolConfig), balanceTracker, permit2);
        address initializeModule = address(new Initialize(integrations));
        address tokenModule = address(new Token(integrations));
        address vaultModule = address(new Vault(integrations));
        address borrowingModule = address(new Borrowing(integrations));
        address liquidationModule = address(new Liquidation(integrations));
        address riskManagerModule = address(new RiskManager(integrations));
        address balanceForwarderModule = address(new BalanceForwarder(integrations));
        address governanceModule = address(new Governance(integrations));
    }
}
