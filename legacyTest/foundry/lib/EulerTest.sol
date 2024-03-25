// // SPDX-License-Identifier: GPL-2.0-or-later

// pragma solidity ^0.8.0;

// import "forge-std/Test.sol";
// import "forge-std/console.sol";
// import { Euler } from "euler-contracts/Euler.sol";
// import { Installer } from "euler-contracts/modules/Installer.sol";
// import { Markets } from "euler-contracts/modules/Markets.sol";
// import { Liquidation } from "euler-contracts/modules/Liquidation.sol";
// import { Governance } from "euler-contracts/modules/Governance.sol";
// import { Exec } from "euler-contracts/modules/Exec.sol";
// import { SwapHub } from "euler-contracts/modules/SwapHub.sol";
// import { EVault } from "euler-contracts/modules/EVault.sol";
// import { DToken } from "euler-contracts/modules/DToken.sol";
// import { IRMDefault } from "euler-contracts/interestRateModels/IRMDefault.sol";
// import { IRMZero } from "euler-contracts/interestRateModels/test/IRMZero.sol";
// import { IRMFixed } from "euler-contracts/interestRateModels/test/IRMFixed.sol";
// import { Constants } from "euler-contracts/Constants.sol";
// import { MockAggregatorProxy } from "euler-contracts/test/MockEACAggregatorProxy.sol";
// import { TestERC20 } from "euler-contracts/test/TestERC20.sol";
// import { BaseModule } from "euler-contracts/BaseModule.sol";
// import { CreditVaultConnector } from "euler-evc/CreditVaultConnector.sol";
// import { IEVC } from "euler-evc/interfaces/ICreditVaultConnector.sol";
// import { RiskManagerCore } from "euler-contracts/riskManagers/core/RiskManagerCore.sol";
// import { RiskManagerCorePricing } from "euler-contracts/riskManagers/core/RiskManagerCorePricing.sol";
// import { MockUniswapV3Factory } from "euler-contracts/test/MockUniswapV3Factory.sol";
// import { MockUniswapV3Pool } from "euler-contracts/test/MockUniswapV3Pool.sol";

// contract EulerTest is Constants, Test {
//     // Pricing types
//     uint16 internal constant PRICINGTYPE__PEGGED = 1;
//     uint16 internal constant PRICINGTYPE__UNISWAP3_TWAP = 2;
//     uint16 internal constant PRICINGTYPE__CHAINLINK = 3;

//     // Wallets prefixed to prevent calling precompiles
//     address public wallet1 = address(0xffffffff1);
//     address public wallet2 = address(0xffffffff2);
//     address public wallet3 = address(0xffffffff3);
//     address[] public wallets = [wallet1, wallet2, wallet3];
//     address public governor = address(0xfffffff4);

//     // Modules (proxies)
//     Installer public installer;
//     Markets public markets;
//     Liquidation public liquidation;
//     Governance public governance;
//     Exec public exec;
//     SwapHub public swapHub;
//     EVault public eVault;
//     DToken public dToken;

//     // Module implementations
//     Installer public installerImpl;
//     Markets public marketsImpl;
//     Liquidation public liquidationImpl;
//     Governance public governanceImpl;
//     Exec public execImpl;
//     SwapHub public swapHubImpl;
//     EVault public eVaultImpl;
//     DToken public dTokenImpl;

//     // Tokens
//     TestERC20 public USDC;
//     TestERC20 public WETH;
//     TestERC20 public DAI;
//     TestERC20[] public tokens;

//     // eVaults
//     EVault public eUSDC;
//     EVault public eWETH;
//     EVault public eDAI;

//     // dTokens
//     DToken public dUSDC;
//     DToken public dWETH;
//     DToken public dDAI;

//     Euler public euler;
//     CreditVaultConnector public evc;
//     RiskManagerCore public riskManager;

//     // Uniswap
//     MockUniswapV3Factory public uniswapFactory;
//     MockUniswapV3Pool public USDCWETHPool;
//     MockUniswapV3Pool public DAIWETHPool;

//     // Price feeds
//     MockAggregatorProxy public USDCPriceFeed;
//     MockAggregatorProxy public DAIPriceFeed;

//     uint256 public constant USDC_START_PRICE = 523113340519705;
//     uint256 public constant DAI_START_PRICE = 527623601492955;

//     function setUp() public {
//         // Setup tokens
//         USDC = new TestERC20("USDC", "USDC", 6, false);
//         WETH = new TestERC20("WETH", "WETH", 18, false);
//         DAI = new TestERC20("DAI", "DAI", 18, false);

//         tokens.push(USDC);
//         tokens.push(WETH);
//         tokens.push(DAI);

//         for(uint256 i = 0; i < tokens.length; i++) {
//             for(uint256 j = 0; j < wallets.length; j++) {
//                 tokens[i].mint(wallets[j], 1000000e18);
//             }
//         }

//         // Setup price feeds
//         USDCPriceFeed = new MockAggregatorProxy(6);
//         DAIPriceFeed = new MockAggregatorProxy(18);
//         USDCPriceFeed.mockSetValidAnswer(int256(USDC_START_PRICE));
//         DAIPriceFeed.mockSetValidAnswer(int256(DAI_START_PRICE));

//         // Deploy mock uniswap factory
//         uniswapFactory = new MockUniswapV3Factory();
//         // Deploy mock uniswap pools
//         USDCWETHPool = MockUniswapV3Pool(uniswapFactory.createPool(address(USDC), address(WETH), 3000));
//         DAIWETHPool = MockUniswapV3Pool(uniswapFactory.createPool(address(DAI), address(WETH), 3000));
//         // TODO set initial price

//         // Deploy evc
//         evc = new CreditVaultConnector();

//         // Deploy modules
//         installerImpl = new Installer(bytes32("0x1"));
//         marketsImpl = new Markets(address(evc), bytes32("0x1"));
//         liquidationImpl = new Liquidation(address(evc), bytes32("0x1"));
//         governanceImpl = new Governance(address(evc), bytes32("0x1"));
//         execImpl = new Exec(address(evc), bytes32("0x1"));
//         swapHubImpl = new SwapHub(address(evc), bytes32("0x1"));
//         eVaultImpl = new EVault(address(evc), bytes32("0x1"));
//         dTokenImpl = new DToken(address(evc), bytes32("0x1"));

//         // Deploy Euler
//         euler = new Euler(governor, address(installerImpl));
//         // Set installer proxy
//         installer = Installer(euler.moduleIdToProxy(MODULEID__INSTALLER));

//         // Install modules
//         vm.prank(governor);
//         installer.installModules(moduleInstallArr());

//         // Set module proxies
//         markets = Markets(euler.moduleIdToProxy(MODULEID__MARKETS));
//         liquidation = Liquidation(euler.moduleIdToProxy(MODULEID__LIQUIDATION));
//         governance = Governance(euler.moduleIdToProxy(MODULEID__GOVERNANCE));
//         exec = Exec(euler.moduleIdToProxy(MODULEID__EXEC));
//         swapHub = SwapHub(euler.moduleIdToProxy(MODULEID__SWAPHUB));

//         // Deploy IRMs
//         IRMDefault irmDefault = new IRMDefault(bytes32("0x1"));
//         IRMZero irmZero = new IRMZero(bytes32("0x1"));
//         IRMFixed irmFixed = new IRMFixed(bytes32("0x1"));

//         // Deploy risk manager
//         riskManager = new RiskManagerCore(
//             bytes32("0x1"), // git commit
//             RiskManagerCorePricing.RiskManagerSettings({
//                 referenceAsset: address(WETH),
//                 uniswapFactory: address(uniswapFactory),
//                 uniswapPoolInitCodeHash: keccak256(type(MockUniswapV3Pool).creationCode)
//             }),
//             governor,
//             address(euler),
//             address(irmZero)
//         );

//         // Activate markets
//         eWETH = EVault(genericFactory(address(WETH), address(riskManager), bytes("")));
//         eUSDC = EVault(genericFactory(address(USDC), address(riskManager), bytes("")));
//         eDAI = EVault(genericFactory(address(DAI), address(riskManager), bytes("")));

//         vm.startPrank(governor);

//         // Set chainlink pricefeeds for underlying
//         riskManager.setChainlinkPriceFeed(address(USDC), address(USDCPriceFeed));
//         riskManager.setChainlinkPriceFeed(address(DAI), address(DAIPriceFeed));

//         // // Set market price configs
//         // riskManager.setPricingConfig(address(eUSDC), PRICINGTYPE__CHAINLINK, 0);
//         // riskManager.setPricingConfig(address(eDAI), PRICINGTYPE__CHAINLINK, 0);

//         vm.stopPrank();
//     }

//     function moduleInstallArr() public view returns(address[] memory) {
//         address[] memory result = new address[](7);

//         result[0] = address(marketsImpl);
//         result[1] = address(liquidationImpl);
//         result[2] = address(governanceImpl);
//         result[3] = address(execImpl);
//         result[4] = address(swapHubImpl);
//         result[5] = address(eVaultImpl);
//         result[6] = address(dTokenImpl);

//         return result;
//     }

// }
