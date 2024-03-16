// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {PSM} from "../../../src/pegStabilityModules/PSM.sol";
import {ESynth, IEVC} from "../../../src/ESynth/ESynth.sol";
import {TestERC20} from "../../mocks/TestERC20.sol";
import {EthereumVaultConnector} from "ethereum-vault-connector/EthereumVaultConnector.sol";


contract PSMTest is Test {
    // TODO tests where ETH transfers fail

    uint public TO_UNDERLYING_FEE = 30;
    uint public TO_SYNTH_FEE = 30;
    uint public BPS_SCALE = 10000;

    ESynth public synth;
    TestERC20 public underlying;

    PSM public psm;

    IEVC public evc;

    address public owner = makeAddr("owner");
    address public wallet1 = makeAddr("wallet1");
    address public wallet2 = makeAddr("wallet2");
    
    function setUp() public {
        // Deploy EVC
        evc = new EthereumVaultConnector();

        // Deploy underlying
        underlying = new TestERC20("TestUnderlying", "TUNDERLYING", 18, false);

        // Deploy synth
        vm.prank(owner);
        synth = new ESynth(evc, "TestSynth", "TSYNTH");

        // Deploy PSM
        vm.prank(owner);
        psm = new PSM(address(evc), address(synth), address(underlying), TO_UNDERLYING_FEE, TO_SYNTH_FEE);

        // Give PSM and wallets some underlying
        underlying.mint(address(psm), 100e18);
        underlying.mint(wallet1, 100e18);
        underlying.mint(wallet2, 100e18);

        // Approve PSM to spend underlying
        vm.prank(wallet1);
        underlying.approve(address(psm), 100e18);
        vm.prank(wallet2);
        underlying.approve(address(psm), 100e18);

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
        uint receiverBalanceBefore = underlying.balanceOf(wallet2);
        uint psmUnderlyingBalanceBefore = underlying.balanceOf(address(psm));

        vm.prank(wallet1);
        psm.swapToUnderlyingGivenIn(amountIn, wallet2);

        uint swapperSynthBalanceAfter = synth.balanceOf(wallet1);
        uint receiverBalanceAfter = underlying.balanceOf(wallet2);
        uint psmUnderlyingBalanceAfter = underlying.balanceOf(address(psm));

        assertEq(swapperSynthBalanceAfter, swapperSynthBalanceBefore - amountIn);
        assertEq(receiverBalanceAfter, receiverBalanceBefore + expectedAmountOut);
        assertEq(psmUnderlyingBalanceAfter, psmUnderlyingBalanceBefore - expectedAmountOut);
    }

    function testSwapToUnderlyingGivenOut() public {
        uint amountOut = 10e18;
        uint expectedAmountIn = amountOut * BPS_SCALE / (BPS_SCALE - TO_UNDERLYING_FEE);

        uint swapperSynthBalanceBefore = synth.balanceOf(wallet1);
        uint receiverBalanceBefore = underlying.balanceOf(wallet2);
        uint psmUnderlyingBalanceBefore = underlying.balanceOf(address(psm));

        vm.prank(wallet1);
        psm.swapToUnderlyingGivenOut(amountOut, wallet2);

        uint swapperSynthBalanceAfter = synth.balanceOf(wallet1);
        uint receiverBalanceAfter = underlying.balanceOf(wallet2);
        uint psmUnderlyingBalanceAfter = underlying.balanceOf(address(psm));

        assertEq(swapperSynthBalanceAfter, swapperSynthBalanceBefore - expectedAmountIn);
        assertEq(receiverBalanceAfter, receiverBalanceBefore + amountOut);
        assertEq(psmUnderlyingBalanceAfter, psmUnderlyingBalanceBefore - amountOut);
    }

    function testSwapToSynthGivenIn() public {
        uint amountIn = 10e18;
        uint expectedAmountOut = amountIn * (BPS_SCALE - TO_SYNTH_FEE) / BPS_SCALE;

        uint swapperUnderlyingBalanceBefore = underlying.balanceOf(wallet1);
        uint receiverSynthBalanceBefore = synth.balanceOf(wallet2);
        uint psmUnderlyingBalanceBefore = underlying.balanceOf(address(psm));

        vm.prank(wallet1);
        psm.swapToSynthGivenIn(amountIn, wallet2);

        uint swapperUnderlyingBalanceAfter = underlying.balanceOf(wallet1);
        uint receiverSynthBalanceAfter = synth.balanceOf(wallet2);
        uint psmUnderlyingBalanceAfter = underlying.balanceOf(address(psm));

        assertEq(swapperUnderlyingBalanceAfter, swapperUnderlyingBalanceBefore - amountIn);
        assertEq(receiverSynthBalanceAfter, receiverSynthBalanceBefore + expectedAmountOut);
        assertEq(psmUnderlyingBalanceAfter, psmUnderlyingBalanceBefore + amountIn);
    }

    function testSwapToSynthGivenOut() public {
        uint amountOut = 10e18;
        uint expectedAmountIn = amountOut * BPS_SCALE / (BPS_SCALE - TO_SYNTH_FEE);

        uint swapperUnderlyingBalanceBefore = underlying.balanceOf(wallet1);
        uint receiverSynthBalanceBefore = synth.balanceOf(wallet2);
        uint psmUnderlyingBalanceBefore = underlying.balanceOf(address(psm));

        vm.prank(wallet1);
        psm.swapToSynthGivenOut(amountOut, wallet2);

        uint swapperUnderlyingBalanceAfter = underlying.balanceOf(wallet1);
        uint receiverSynthBalanceAfter = synth.balanceOf(wallet2);
        uint psmUnderlyingBalanceAfter = underlying.balanceOf(address(psm));

        assertEq(swapperUnderlyingBalanceAfter, swapperUnderlyingBalanceBefore - expectedAmountIn);
        assertEq(receiverSynthBalanceAfter, receiverSynthBalanceBefore + amountOut);
        assertEq(psmUnderlyingBalanceAfter, psmUnderlyingBalanceBefore + expectedAmountIn);
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