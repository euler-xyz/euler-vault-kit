// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2, stdError} from "forge-std/Test.sol";
import {DeploymentAll} from "../../../script/02_DeploymentAll.s.sol";
import {GenericFactory} from "src/GenericFactory/GenericFactory.sol";
import {EVault} from "src/EVault/EVault.sol";
import {ProtocolConfig} from "src/ProtocolConfig/ProtocolConfig.sol";
import {IEVault} from "src/EVault/IEVault.sol";
import {TypesLib} from "src/EVault/shared/types/Types.sol";
import {Base} from "src/EVault/shared/Base.sol";

import {Core} from "src/ProductLines/Core.sol";
import {Escrow} from "src/ProductLines/Escrow.sol";

import {EthereumVaultConnector} from "ethereum-vault-connector/EthereumVaultConnector.sol";

import {TestERC20} from "../../mocks/TestERC20.sol";
import {MockBalanceTracker} from "../../mocks/MockBalanceTracker.sol";
import {MockPriceOracle} from "../../mocks/MockPriceOracle.sol";
import {IRMTestDefault} from "../../mocks/IRMTestDefault.sol";

import {AssertionsCustomTypes} from "../../helpers/AssertionsCustomTypes.sol";
import {EVaultLens} from "src/lens/EVaultLens.sol";

import "src/EVault/shared/Constants.sol";

contract EVaultTestBase is AssertionsCustomTypes, Test {
    DeploymentAll internal deployer;

    address admin;
    address feeReceiver;
    address protocolFeeReceiver;

    EthereumVaultConnector public evc;
    ProtocolConfig protocolConfig;
    address balanceTracker;
    address permit2;
    MockPriceOracle oracle;
    IRMTestDefault irm;
    GenericFactory public factory;
    EVaultLens public lens;

    address initializeModule;
    address tokenModule;
    address vaultModule;
    address borrowingModule;
    address liquidationModule;
    address riskManagerModule;
    address balanceForwarderModule;
    address governanceModule;

    TestERC20 assetTST;
    TestERC20 assetTST2;
    TestERC20 assetTST3;

    IEVault public eTST;
    IEVault public eTST2;
    IEVault public eTST3;

    address unitOfAccount;

    Core public coreProductLine;
    Escrow public escrowProductLine;

    function setUp() public virtual {
        admin = vm.addr(1000);
        feeReceiver = makeAddr("feeReceiver");
        protocolFeeReceiver = makeAddr("protocolFeeReceiver");

        deployer = new DeploymentAll();
        DeploymentAll.DeploymentAllResult memory result = deployer.deploy(admin, protocolFeeReceiver);

        evc = EthereumVaultConnector(payable(result.integrations.evc));
        protocolConfig = ProtocolConfig(result.integrations.protocolConfig);
        balanceTracker = result.integrations.balanceTracker;
        permit2 = result.integrations.permit2;
        oracle = MockPriceOracle(result.oracle);
        irm = IRMTestDefault(result.interestRateModel);
        factory = GenericFactory(result.factory);
        lens = EVaultLens(result.lens);

        initializeModule = result.modules.initialize;
        tokenModule = result.modules.token;
        vaultModule = result.modules.vault;
        borrowingModule = result.modules.borrowing;
        liquidationModule = result.modules.liquidation;
        riskManagerModule = result.modules.riskManager;
        balanceForwarderModule = result.modules.balanceForwarder;
        governanceModule = result.modules.governance;

        assetTST = TestERC20(result.assets[0]);
        assetTST2 = TestERC20(result.assets[1]);
        assetTST3 = TestERC20(result.assets[2]);

        eTST = IEVault(result.vaults[0]);
        eTST2 = IEVault(result.vaults[1]);
        eTST3 = IEVault(result.vaults[2]);

        unitOfAccount = result.assets[3];

        vm.startPrank(admin);
        for (uint256 i = 0; i < result.vaults.length; i++) {
            IEVault(result.vaults[i]).setGovernorAdmin(address(this));
        }
        vm.stopPrank();

        coreProductLine = new Core(address(factory), address(evc), address(this), feeReceiver);
        escrowProductLine = new Escrow(address(factory), address(evc));
    }

    address internal SYNTH_VAULT_HOOK_TARGET = address(new MockHook());
    uint32 internal constant SYNTH_VAULT_HOOKED_OPS = OP_DEPOSIT | OP_MINT | OP_REDEEM | OP_SKIM | OP_LOOP | OP_DELOOP;

    function createSynthEVault(address asset) internal returns (IEVault) {
        IEVault v = IEVault(factory.createProxy(true, abi.encodePacked(address(asset), address(oracle), unitOfAccount)));
        v.setInterestRateModel(address(new IRMTestDefault()));

        v.setInterestFee(1e4);

        v.setHookConfig(SYNTH_VAULT_HOOK_TARGET, SYNTH_VAULT_HOOKED_OPS);

        return v;
    }
}

contract MockHook {
    error E_OnlyAssetCanDeposit();
    error E_OperationDisabled();

    // deposit is only allowed for the asset
    function deposit(uint256, address) external view {
        address asset = IEVault(msg.sender).asset();

        if (asset != caller()) revert E_OnlyAssetCanDeposit();
    }

    function maxDeposit(address) public view virtual returns (uint256 max) {}

    // all the other hooked ops are disabled
    fallback() external {
        revert E_OperationDisabled();
    }

    function caller() internal pure returns (address _caller) {
        assembly {
            _caller := shr(96, calldataload(sub(calldatasize(), 20)))
        }
    }
}
