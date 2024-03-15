// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {ETHPSM} from "../../../src/pegStabilityModules/ETHPSM.sol";
import {ESynth, IEVC} from "../../../src/ESynth/ESynth.sol";
import {EthereumVaultConnector} from "ethereum-vault-connector/EthereumVaultConnector.sol";

contract ETHPSMTest is Test {
    // TODO tests where ETH transfers fail

    uint public TO_UNDERLYING_FEE = 30;
    uint public TO_SYNTH_FEE = 30;
    uint public BPS_SCALE = 10000;

    ESynth public synth;
    ETHPSM public psm;

    IEVC public evc;

    address public owner = makeAddr("owner");
    address public wallet1 = makeAddr("wallet1");
    address public wallet2 = makeAddr("wallet2");
    
    function setUp() public {
        // Deploy EVC
        evc = new EthereumVaultConnector();

        // Deploy synth
        vm.prank(owner);
        synth = new ESynth(IEVC(evc), "TestSynth", "TSYNTH");

        // Deploy PSM
        vm.prank(owner);
        psm = new ETHPSM(address(synth), TO_UNDERLYING_FEE, TO_SYNTH_FEE);

        // Give PSM and wallets some ETH
        vm.deal(address(psm), 100e18);
        vm.deal(wallet1, 100e18);
        vm.deal(wallet2, 100e18);

        // Set PSM as minter
        vm.prank(owner);
        synth.setCapacity(address(psm), 100e18);

        // Mint some synth to wallets
        vm.startPrank(owner);
        synth.setCapacity(owner, 200e18);
        synth.mint(wallet1, 100e18);
        synth.mint(wallet2, 100e18);
        vm.stopPrank();

        // Set approvals for PSM
        vm.prank(wallet1);
        synth.approve(address(psm), 100e18);
        vm.prank(wallet2);
        synth.approve(address(psm), 100e18);

    }

    function testConstructor() public {
        assertEq(address(psm.synth()), address(synth));
        assertEq(psm.TO_UNDERLYING_FEE(), TO_UNDERLYING_FEE);
        assertEq(psm.TO_SYNTH_FEE(), TO_SYNTH_FEE);
    }

    function testSwapToUnderlyingGivenIn() public {
        uint amountIn = 10e18;
        uint expectedAmountOut = amountIn * (BPS_SCALE - TO_UNDERLYING_FEE) / BPS_SCALE;

        uint swapperSynthBalanceBefore = synth.balanceOf(wallet1);
        uint receiverBalanceBefore = wallet2.balance;
        uint psmETHBalanceBefore = address(psm).balance;

        vm.prank(wallet1);
        psm.swapToUnderlyingGivenIn(amountIn, wallet2);

        uint swapperSynthBalanceAfter = synth.balanceOf(wallet1);
        uint receiverBalanceAfter = wallet2.balance;
        uint psmETHBalanceAfter = address(psm).balance;

        assertEq(swapperSynthBalanceAfter, swapperSynthBalanceBefore - amountIn);
        assertEq(receiverBalanceAfter, receiverBalanceBefore + expectedAmountOut);
        assertEq(psmETHBalanceAfter, psmETHBalanceBefore - expectedAmountOut);
    }

    function testSwapToUnderlyingGivenOut() public {
        uint amountOut = 10e18;
        uint expectedAmountIn = amountOut * BPS_SCALE / (BPS_SCALE - TO_UNDERLYING_FEE);

        uint swapperSynthBalanceBefore = synth.balanceOf(wallet1);
        uint receiverBalanceBefore = wallet2.balance;
        uint psmETHBalanceBefore = address(psm).balance;

        vm.prank(wallet1);
        psm.swapToUnderlyingGivenOut(amountOut, wallet2);

        uint swapperSynthBalanceAfter = synth.balanceOf(wallet1);
        uint receiverBalanceAfter = wallet2.balance;
        uint psmETHBalanceAfter = address(psm).balance;

        assertEq(swapperSynthBalanceAfter, swapperSynthBalanceBefore - expectedAmountIn);
        assertEq(receiverBalanceAfter, receiverBalanceBefore + amountOut);
        assertEq(psmETHBalanceAfter, psmETHBalanceBefore - amountOut);
    }

    function testSwapToSynthGivenIn() public {
        uint amountIn = 10e18;
        uint expectedAmountOut = amountIn * (BPS_SCALE - TO_SYNTH_FEE) / BPS_SCALE;

        uint swapperETHBalanceBefore = wallet1.balance;
        uint receiverSynthBalanceBefore = synth.balanceOf(wallet2);
        uint psmETHBalanceBefore = address(psm).balance;

        vm.prank(wallet1);
        psm.swapToSynthGivenIn{value: amountIn}(wallet2);

        uint swapperETHBalanceAfter = wallet1.balance;
        uint receiverSynthBalanceAfter = synth.balanceOf(wallet2);
        uint psmETHBalanceAfter = address(psm).balance;

        assertEq(swapperETHBalanceAfter, swapperETHBalanceBefore - amountIn);
        assertEq(receiverSynthBalanceAfter, receiverSynthBalanceBefore + expectedAmountOut);
        assertEq(psmETHBalanceAfter, psmETHBalanceBefore + amountIn);
    }

    function testSwapToSynthGivenOut() public {
        uint amountOut = 10e18;
        uint expectedAmountIn = amountOut * BPS_SCALE / (BPS_SCALE - TO_SYNTH_FEE);

        uint swapperETHBalanceBefore = wallet1.balance;
        uint receiverSynthBalanceBefore = synth.balanceOf(wallet2);
        uint psmETHBalanceBefore = address(psm).balance;

        vm.prank(wallet1);
        psm.swapToSynthGivenOut{value: expectedAmountIn}(amountOut, wallet2);

        uint swapperETHBalanceAfter = wallet1.balance;
        uint receiverSynthBalanceAfter = synth.balanceOf(wallet2);
        uint psmETHBalanceAfter = address(psm).balance;

        assertEq(swapperETHBalanceAfter, swapperETHBalanceBefore - expectedAmountIn);
        assertEq(receiverSynthBalanceAfter, receiverSynthBalanceBefore + amountOut);
        assertEq(psmETHBalanceAfter, psmETHBalanceBefore + expectedAmountIn);
    }

    function testSwapToSynthGivenOutToLittleETHSendShouldFail() public {
        uint amountOut = 10e18;
        uint expectedAmountIn = amountOut * BPS_SCALE / (BPS_SCALE - TO_SYNTH_FEE);
        
        vm.startPrank(wallet1);
        vm.expectRevert(stdError.arithmeticError);
        psm.swapToSynthGivenOut{value: expectedAmountIn - 10}(amountOut, wallet2);
        vm.stopPrank();
    }

    // Test quotes
    function testQuoteToUnderlyingGivenIn() public {
        uint amountIn = 10e18;
        uint expectedAmountOut = amountIn * (BPS_SCALE - TO_UNDERLYING_FEE) / BPS_SCALE;

        uint amountOut = psm.quoteToUnderlyingGivenIn(amountIn);

        assertEq(amountOut, expectedAmountOut);
    }

    function testQuoteToUnderlyingGivenOut() public {
        uint amountOut = 10e18;
        uint expectedAmountIn = amountOut * BPS_SCALE / (BPS_SCALE - TO_UNDERLYING_FEE);

        uint amountIn = psm.quoteToUnderlyingGivenOut(amountOut);

        assertEq(amountIn, expectedAmountIn);
    }

    function testQuoteToSynthGivenIn() public {
        uint amountIn = 10e18;
        uint expectedAmountOut = amountIn * (BPS_SCALE - TO_SYNTH_FEE) / BPS_SCALE;

        uint amountOut = psm.quoteToSynthGivenIn(amountIn);

        assertEq(amountOut, expectedAmountOut);
    }

    function testQuoteToSynthGivenOut() public {
        uint amountOut = 10e18;
        uint expectedAmountIn = amountOut * BPS_SCALE / (BPS_SCALE - TO_SYNTH_FEE);

        uint amountIn = psm.quoteToSynthGivenOut(amountOut);

        assertEq(amountIn, expectedAmountIn);
    }
}