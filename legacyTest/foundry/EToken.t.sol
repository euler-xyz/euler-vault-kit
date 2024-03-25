// // SPDX-License-Identifier: GPL-2.0-or-later

// pragma solidity ^0.8.0;

// import { EulerTest, console } from "./lib/EulerTest.sol";

// contract EVaultTest is EulerTest {

//     function testName() public {
//         string memory name = eUSDC.name();
//         string memory underlyingName = USDC.name();
//         string memory expectedName = string(abi.encodePacked("Euler Pool: ", underlyingName));

//         assertEq(name, expectedName);
//     }

//     function testSymbol() public {
//         string memory symbol = eUSDC.symbol();
//         string memory underlyingSymbol = USDC.symbol();
//         string memory expectedSymbol = string(abi.encodePacked("e", underlyingSymbol));

//         assertEq(symbol, expectedSymbol);
//     }

//     function testDecimals() public {
//         // Should always be 18 (for now)
//         assertEq(eUSDC.decimals(), 18);
//     }

//     function testAsset() public {
//         // Should return correct underlying address
//         assertEq(eUSDC.asset(), address(USDC));
//     }

//     function testRiskManager() public {
//         // Should return correct risk manager address
//         assertEq(eUSDC.riskManager(), address(riskManager));
//     }

//     function testInitialTotalSupply() public {
//         uint256 totalSupply = eUSDC.totalSupply();
//         // Should be 1e6 (initial reserves)
//         assertEq(totalSupply, INITIAL_RESERVES);
//     }

//     function testInitialTotalAssets() public {
//         uint256 totalAssets = eUSDC.totalAssets();
//         console.log("totalAssets", totalAssets);
//     }
// }
