// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {PegStabilityModule, EVCUtil} from "../../../src/Synths/PegStabilityModule.sol";
import {ESynth} from "../../../src/Synths/ESynth.sol";
import {TestERC20} from "../../mocks/TestERC20.sol";
import {EthereumVaultConnector} from "ethereum-vault-connector/EthereumVaultConnector.sol";
import {EVCUtil} from "ethereum-vault-connector/utils/EVCUtil.sol";

contract PSMTest is Test {
    uint256 public TO_UNDERLYING_FEE = 30;
    uint256 public TO_SYNTH_FEE = 30;
    uint256 public BPS_SCALE = 10000;
    uint256 public CONVERSION_PRICE = 1e18;
    uint256 public PRICE_SCALE = 1e18;

    ESynth public synth;
    TestERC20 public underlying;

    PegStabilityModule public psm;

    EthereumVaultConnector public evc;

    address public owner = makeAddr("owner");
    address public wallet1 = makeAddr("wallet1");
    address public wallet2 = makeAddr("wallet2");

    function setUp() public {
        // Deploy EVC
        evc = new EthereumVaultConnector();

        // Deploy synth
        vm.prank(owner);
        synth = new ESynth(address(evc), "TestSynth", "TSYNTH");

        // Deploy underlying
        underlying = new TestERC20("TestUnderlying", "TUNDERLYING", 18, false);

        // Deploy PSM
        vm.prank(owner);
        psm = new PegStabilityModule(
            address(evc), address(synth), address(underlying), TO_UNDERLYING_FEE, TO_SYNTH_FEE, CONVERSION_PRICE
        );
    }

    function fuzzSetUp(
        uint8 underlyingDecimals,
        uint256 _toUnderlyingFeeBPS,
        uint256 _toSynthFeeBPS,
        uint256 _conversionPrice
    ) internal {
        // Redeploy underlying
        underlying = new TestERC20("TestUnderlying", "TUNDERLYING", underlyingDecimals, false);

        // Redeploy PSM
        vm.prank(owner);
        psm = new PegStabilityModule(
            address(evc), address(synth), address(underlying), _toUnderlyingFeeBPS, _toSynthFeeBPS, _conversionPrice
        );

        // Give PSM and wallets some underlying
        uint128 amount = uint128(1e6 * 10 ** underlyingDecimals);
        underlying.mint(address(psm), amount);
        underlying.mint(wallet1, amount);
        underlying.mint(wallet2, amount);

        // Approve PSM to spend underlying
        vm.prank(wallet1);
        underlying.approve(address(psm), type(uint256).max);
        vm.prank(wallet2);
        underlying.approve(address(psm), type(uint256).max);

        // Set PSM as minter
        amount = 1e6 * 10 ** 18;
        vm.prank(owner);
        synth.setCapacity(address(psm), amount);

        // Mint some synth to wallets
        vm.startPrank(owner);
        synth.setCapacity(owner, uint128(2 * amount));
        synth.mint(wallet1, amount);
        synth.mint(wallet2, amount);
        vm.stopPrank();

        // Set approvals for PSM
        vm.prank(wallet1);
        synth.approve(address(psm), type(uint256).max);
        vm.prank(wallet2);
        synth.approve(address(psm), type(uint256).max);
    }

    function testConstructor() public view {
        assertEq(address(psm.EVC()), address(evc));
        assertEq(address(psm.synth()), address(synth));
        assertEq(address(psm.underlying()), address(underlying));
        assertEq(psm.TO_UNDERLYING_FEE(), TO_UNDERLYING_FEE);
        assertEq(psm.TO_SYNTH_FEE(), TO_SYNTH_FEE);
        assertEq(psm.CONVERSION_PRICE(), CONVERSION_PRICE);
    }

    function testConstructorToUnderlyingFeeExceedsBPS() public {
        vm.expectRevert(PegStabilityModule.E_FeeExceedsBPS.selector);
        new PegStabilityModule(
            address(evc), address(synth), address(underlying), BPS_SCALE + 1, TO_SYNTH_FEE, CONVERSION_PRICE
        );
    }

    function testConstructorToSynthFeeExceedsBPS() public {
        vm.expectRevert(PegStabilityModule.E_FeeExceedsBPS.selector);
        new PegStabilityModule(
            address(evc), address(synth), address(underlying), TO_UNDERLYING_FEE, BPS_SCALE + 1, CONVERSION_PRICE
        );
    }

    function testConstructorEVCZeroAddress() public {
        vm.expectRevert(bytes4(keccak256("EVC_InvalidAddress()")));
        new PegStabilityModule(
            address(0), address(synth), address(underlying), TO_UNDERLYING_FEE, TO_SYNTH_FEE, CONVERSION_PRICE
        );
    }

    function testConstructorSynthZeroAddress() public {
        vm.expectRevert(PegStabilityModule.E_ZeroAddress.selector);
        new PegStabilityModule(
            address(evc), address(0), address(underlying), TO_UNDERLYING_FEE, TO_SYNTH_FEE, CONVERSION_PRICE
        );
    }

    function testConstructorUnderlyingZeroAddress() public {
        vm.expectRevert(PegStabilityModule.E_ZeroAddress.selector);
        new PegStabilityModule(
            address(evc), address(synth), address(0), TO_UNDERLYING_FEE, TO_SYNTH_FEE, CONVERSION_PRICE
        );
    }

    function testConstructorZeroConversionPrice() public {
        vm.expectRevert(PegStabilityModule.E_ZeroConversionPrice.selector);
        new PegStabilityModule(address(evc), address(synth), address(underlying), TO_UNDERLYING_FEE, TO_SYNTH_FEE, 0);
    }

    function testSwapToUnderlyingGivenIn(uint8 underlyingDecimals, uint256 fee, uint256 amountInNoDecimals) public {
        underlyingDecimals = uint8(bound(underlyingDecimals, 6, 18));
        fee = bound(fee, 0, BPS_SCALE - 1);
        amountInNoDecimals = bound(amountInNoDecimals, 1, 100);
        fuzzSetUp(underlyingDecimals, fee, 0, 10 ** underlyingDecimals);

        uint256 amountIn = amountInNoDecimals * 10 ** 18;
        uint256 expectedAmountOut = amountInNoDecimals * 10 ** underlyingDecimals * (BPS_SCALE - fee) / BPS_SCALE;

        assertEq(psm.quoteToUnderlyingGivenIn(amountIn), expectedAmountOut);

        uint256 swapperSynthBalanceBefore = synth.balanceOf(wallet1);
        uint256 receiverBalanceBefore = underlying.balanceOf(wallet2);
        uint256 psmUnderlyingBalanceBefore = underlying.balanceOf(address(psm));

        vm.prank(wallet1);
        psm.swapToUnderlyingGivenIn(amountIn, wallet2);

        uint256 swapperSynthBalanceAfter = synth.balanceOf(wallet1);
        uint256 receiverBalanceAfter = underlying.balanceOf(wallet2);
        uint256 psmUnderlyingBalanceAfter = underlying.balanceOf(address(psm));

        assertEq(swapperSynthBalanceAfter, swapperSynthBalanceBefore - amountIn);
        assertEq(receiverBalanceAfter, receiverBalanceBefore + expectedAmountOut);
        assertEq(psmUnderlyingBalanceAfter, psmUnderlyingBalanceBefore - expectedAmountOut);
    }

    function testSwapToUnderlyingGivenOut(uint8 underlyingDecimals, uint256 fee, uint256 amountOutNoDecimals) public {
        underlyingDecimals = uint8(bound(underlyingDecimals, 6, 18));
        fee = bound(fee, 0, BPS_SCALE - 1);
        amountOutNoDecimals = bound(amountOutNoDecimals, 1, 100);
        fuzzSetUp(underlyingDecimals, fee, 0, 10 ** underlyingDecimals);

        uint256 amountOut = amountOutNoDecimals * 10 ** underlyingDecimals;
        uint256 expectedAmountIn =
            (amountOutNoDecimals * 10 ** 18 * BPS_SCALE + BPS_SCALE - fee - 1) / (BPS_SCALE - fee);

        assertEq(psm.quoteToUnderlyingGivenOut(amountOut), expectedAmountIn);

        uint256 swapperSynthBalanceBefore = synth.balanceOf(wallet1);
        uint256 receiverBalanceBefore = underlying.balanceOf(wallet2);
        uint256 psmUnderlyingBalanceBefore = underlying.balanceOf(address(psm));

        vm.prank(wallet1);
        psm.swapToUnderlyingGivenOut(amountOut, wallet2);

        uint256 swapperSynthBalanceAfter = synth.balanceOf(wallet1);
        uint256 receiverBalanceAfter = underlying.balanceOf(wallet2);
        uint256 psmUnderlyingBalanceAfter = underlying.balanceOf(address(psm));

        assertEq(swapperSynthBalanceAfter, swapperSynthBalanceBefore - expectedAmountIn);
        assertEq(receiverBalanceAfter, receiverBalanceBefore + amountOut);
        assertEq(psmUnderlyingBalanceAfter, psmUnderlyingBalanceBefore - amountOut);
    }

    function testSwapToSynthGivenIn(uint8 underlyingDecimals, uint256 fee, uint256 amountInNoDecimals) public {
        underlyingDecimals = uint8(bound(underlyingDecimals, 6, 18));
        fee = bound(fee, 0, BPS_SCALE - 1);
        amountInNoDecimals = bound(amountInNoDecimals, 1, 100);
        fuzzSetUp(underlyingDecimals, 0, fee, 10 ** underlyingDecimals);

        uint256 amountIn = amountInNoDecimals * 10 ** underlyingDecimals;
        uint256 expectedAmountOut = amountInNoDecimals * 10 ** 18 * (BPS_SCALE - fee) / BPS_SCALE;

        assertEq(psm.quoteToSynthGivenIn(amountIn), expectedAmountOut);

        uint256 swapperUnderlyingBalanceBefore = underlying.balanceOf(wallet1);
        uint256 receiverSynthBalanceBefore = synth.balanceOf(wallet2);
        uint256 psmUnderlyingBalanceBefore = underlying.balanceOf(address(psm));

        vm.prank(wallet1);
        psm.swapToSynthGivenIn(amountIn, wallet2);

        uint256 swapperUnderlyingBalanceAfter = underlying.balanceOf(wallet1);
        uint256 receiverSynthBalanceAfter = synth.balanceOf(wallet2);
        uint256 psmUnderlyingBalanceAfter = underlying.balanceOf(address(psm));

        assertEq(swapperUnderlyingBalanceAfter, swapperUnderlyingBalanceBefore - amountIn);
        assertEq(receiverSynthBalanceAfter, receiverSynthBalanceBefore + expectedAmountOut);
        assertEq(psmUnderlyingBalanceAfter, psmUnderlyingBalanceBefore + amountIn);
    }

    function testSwapToSynthGivenOut(uint8 underlyingDecimals, uint256 fee, uint256 amountOutNoDecimals) public {
        underlyingDecimals = uint8(bound(underlyingDecimals, 6, 18));
        fee = bound(fee, 0, BPS_SCALE - 1);
        amountOutNoDecimals = bound(amountOutNoDecimals, 1, 100);
        fuzzSetUp(underlyingDecimals, 0, fee, 10 ** underlyingDecimals);

        uint256 amountOut = amountOutNoDecimals * 10 ** 18;
        uint256 expectedAmountIn =
            (amountOutNoDecimals * 10 ** underlyingDecimals * BPS_SCALE + BPS_SCALE - fee - 1) / (BPS_SCALE - fee);

        assertEq(psm.quoteToSynthGivenOut(amountOut), expectedAmountIn);

        uint256 swapperUnderlyingBalanceBefore = underlying.balanceOf(wallet1);
        uint256 receiverSynthBalanceBefore = synth.balanceOf(wallet2);
        uint256 psmUnderlyingBalanceBefore = underlying.balanceOf(address(psm));

        vm.prank(wallet1);
        psm.swapToSynthGivenOut(amountOut, wallet2);

        uint256 swapperUnderlyingBalanceAfter = underlying.balanceOf(wallet1);
        uint256 receiverSynthBalanceAfter = synth.balanceOf(wallet2);
        uint256 psmUnderlyingBalanceAfter = underlying.balanceOf(address(psm));

        assertEq(swapperUnderlyingBalanceAfter, swapperUnderlyingBalanceBefore - expectedAmountIn);
        assertEq(receiverSynthBalanceAfter, receiverSynthBalanceBefore + amountOut);
        assertEq(psmUnderlyingBalanceAfter, psmUnderlyingBalanceBefore + expectedAmountIn);
    }

    function testSanityPriceConversions(uint8 underlyingDecimals, uint256 amount, uint256 multiplier) public {
        underlyingDecimals = uint8(bound(underlyingDecimals, 6, 18));
        amount = bound(amount, 1, 100);
        multiplier = bound(multiplier, 1, 10000);
        fuzzSetUp(underlyingDecimals, 0, 0, 10 ** underlyingDecimals * multiplier / 100);

        uint256 synthAmount = amount * 10 ** 18;
        uint256 underlyingAmount = amount * 10 ** underlyingDecimals * multiplier / 100;

        assertEq(psm.quoteToSynthGivenIn(underlyingAmount), synthAmount);
        assertEq(psm.quoteToSynthGivenOut(synthAmount), underlyingAmount);
        assertEq(psm.quoteToUnderlyingGivenIn(synthAmount), underlyingAmount);
        assertEq(psm.quoteToUnderlyingGivenOut(underlyingAmount), synthAmount);
    }

    function testRoundingPriceConversionsEqualDecimals() public view {
        assertEq(psm.quoteToSynthGivenIn(1), 0);
        assertEq(psm.quoteToSynthGivenOut(1), 2);
        assertEq(psm.quoteToUnderlyingGivenIn(1), 0);
        assertEq(psm.quoteToUnderlyingGivenOut(1), 2);
    }

    function testRoundingPriceConversionsDiffDecimals(uint8 underlyingDecimals) public {
        underlyingDecimals = uint8(bound(underlyingDecimals, 6, 17));
        fuzzSetUp(underlyingDecimals, 0, 0, 10 ** underlyingDecimals);

        assertEq(psm.quoteToSynthGivenIn(1), 10 ** (18 - underlyingDecimals));
        assertEq(psm.quoteToSynthGivenOut(1), 1);
        assertEq(psm.quoteToUnderlyingGivenIn(1), 0);
        assertEq(psm.quoteToUnderlyingGivenOut(1), 10 ** (18 - underlyingDecimals));
    }
}
