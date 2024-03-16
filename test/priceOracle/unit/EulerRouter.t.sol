// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";
import {IERC4626} from "forge-std/interfaces/IERC4626.sol";
import {LibPRNG} from "@solady/utils/LibPRNG.sol";
import {boundAddr} from "test/utils/TestUtils.sol";
import {IPriceOracle} from "src/interfaces/IPriceOracle.sol";
import {Errors} from "src/lib/Errors.sol";
import {EulerRouter} from "src/EulerRouter.sol";

contract StubERC4626 {
    address public asset;
    uint256 private rate;

    constructor(address _asset, uint256 _rate) {
        asset = _asset;
        rate = _rate;
    }

    function convertToAssets(uint256 shares) external view returns (uint256) {
        return shares * rate / 1e18;
    }

    function convertToShares(uint256 assets) external view returns (uint256) {
        return assets * 1e18 / rate;
    }
}

contract StubPriceOracle {
    mapping(address => mapping(address => uint256)) prices;

    function setPrice(address base, address quote, uint256 price) external {
        prices[base][quote] = price;
    }

    function getQuote(uint256 inAmount, address base, address quote) external view returns (uint256) {
        return _calcQuote(inAmount, base, quote);
    }

    function getQuotes(uint256 inAmount, address base, address quote) external view returns (uint256, uint256) {
        return (_calcQuote(inAmount, base, quote), _calcQuote(inAmount, base, quote));
    }

    function _calcQuote(uint256 inAmount, address base, address quote) internal view returns (uint256) {
        return inAmount * prices[base][quote] / 1e18;
    }
}

contract EulerRouterTest is Test {
    address GOVERNOR = makeAddr("GOVERNOR");
    EulerRouter router;

    address WETH = makeAddr("WETH");
    address eWETH;
    address eeWETH;

    address DAI = makeAddr("DAI");
    address eDAI;
    address eeDAI;

    StubPriceOracle eOracle;

    function setUp() public {
        router = new EulerRouter(GOVERNOR);
    }

    function test_Constructor_Integrity() public view {
        assertEq(router.fallbackOracle(), address(0));
    }

    function test_GovSetConfig_Integrity(address base, address quote, address oracle) public {
        vm.expectEmit();
        emit EulerRouter.ConfigSet(base, quote, oracle);
        vm.prank(GOVERNOR);
        router.govSetConfig(base, quote, oracle);

        assertEq(router.oracles(base, quote), oracle);
    }

    function test_GovSetConfig_Integrity_OverwriteOk(address base, address quote, address oracleA, address oracleB)
        public
    {
        vm.expectEmit();
        emit EulerRouter.ConfigSet(base, quote, oracleA);
        vm.prank(GOVERNOR);
        router.govSetConfig(base, quote, oracleA);

        vm.expectEmit();
        emit EulerRouter.ConfigSet(base, quote, oracleB);
        vm.prank(GOVERNOR);
        router.govSetConfig(base, quote, oracleB);

        assertEq(router.oracles(base, quote), oracleB);
    }

    function test_GovSetConfig_RevertsWhen_CallerNotGovernor(
        address caller,
        address base,
        address quote,
        address oracle
    ) public {
        vm.assume(caller != GOVERNOR);

        vm.expectRevert(Errors.Governance_CallerNotGovernor.selector);
        vm.prank(caller);
        router.govSetConfig(base, quote, oracle);
    }

    function test_GovSetVaultResolver_Integrity(address vault, address asset) public {
        vault = boundAddr(vault);
        vm.mockCall(vault, abi.encodeWithSelector(IERC4626.asset.selector), abi.encode(asset));
        vm.expectEmit();
        emit EulerRouter.ResolvedVaultSet(vault, asset);

        vm.prank(GOVERNOR);
        router.govSetResolvedVault(vault, true);

        assertEq(router.resolvedVaults(vault), asset);
    }

    function test_GovSetVaultResolver_Integrity_OverwriteOk(address vault, address assetA, address assetB) public {
        vault = boundAddr(vault);
        vm.mockCall(vault, abi.encodeWithSelector(IERC4626.asset.selector), abi.encode(assetA));
        vm.prank(GOVERNOR);
        router.govSetResolvedVault(vault, true);

        vm.mockCall(vault, abi.encodeWithSelector(IERC4626.asset.selector), abi.encode(assetB));
        vm.prank(GOVERNOR);
        router.govSetResolvedVault(vault, true);

        assertEq(router.resolvedVaults(vault), assetB);
    }

    function test_GovSetVaultResolver_RevertsWhen_CallerNotGovernor(address caller, address vault) public {
        vm.assume(caller != GOVERNOR);

        vm.expectRevert(Errors.Governance_CallerNotGovernor.selector);
        vm.prank(caller);
        router.govSetResolvedVault(vault, true);
    }

    function test_GovSetFallbackOracle_Integrity(address fallbackOracle) public {
        vm.prank(GOVERNOR);
        router.govSetFallbackOracle(fallbackOracle);

        assertEq(router.fallbackOracle(), fallbackOracle);
    }

    function test_GovSetFallbackOracle_OverwriteOk(address fallbackOracleA, address fallbackOracleB) public {
        vm.prank(GOVERNOR);
        router.govSetFallbackOracle(fallbackOracleA);

        vm.prank(GOVERNOR);
        router.govSetFallbackOracle(fallbackOracleB);

        assertEq(router.fallbackOracle(), fallbackOracleB);
    }

    function test_GovSetFallbackOracle_ZeroOk() public {
        vm.prank(GOVERNOR);
        router.govSetFallbackOracle(address(0));

        assertEq(router.fallbackOracle(), address(0));
    }

    function test_GovSetFallbackOracle_RevertsWhen_CallerNotGovernor(address caller, address fallbackOracle) public {
        vm.assume(caller != GOVERNOR);

        vm.expectRevert(Errors.Governance_CallerNotGovernor.selector);
        vm.prank(caller);
        router.govSetFallbackOracle(fallbackOracle);
    }

    function test_GetQuote_Integrity_BaseEqQuote(uint256 inAmount, address base, address oracle) public view {
        base = boundAddr(base);
        oracle = boundAddr(oracle);
        vm.assume(base != oracle);
        inAmount = bound(inAmount, 1, type(uint128).max);
        uint256 outAmount = router.getQuote(inAmount, base, base);
        assertEq(outAmount, inAmount);
    }

    function test_GetQuote_Integrity_HasOracle(
        uint256 inAmount,
        address base,
        address quote,
        address oracle,
        uint256 outAmount
    ) public {
        base = boundAddr(base);
        quote = boundAddr(quote);
        oracle = boundAddr(oracle);
        vm.assume(base != quote && quote != oracle && base != oracle);
        inAmount = bound(inAmount, 1, type(uint128).max);

        vm.mockCall(
            oracle, abi.encodeWithSelector(IPriceOracle.getQuote.selector, inAmount, base, quote), abi.encode(outAmount)
        );
        vm.mockCall(
            oracle,
            abi.encodeWithSelector(IPriceOracle.getQuotes.selector, inAmount, base, quote),
            abi.encode(outAmount, outAmount)
        );
        vm.prank(GOVERNOR);
        router.govSetConfig(base, quote, oracle);

        uint256 _outAmount = router.getQuote(inAmount, base, quote);
        assertEq(_outAmount, outAmount);
        (uint256 bidOutAmount, uint256 askOutAmount) = router.getQuotes(inAmount, base, quote);
        assertEq(bidOutAmount, outAmount);
        assertEq(askOutAmount, outAmount);
    }

    function test_GetQuote_Integrity_BaseIsVault(
        uint256 inAmount,
        address base,
        address baseAsset,
        address quote,
        address oracle,
        uint256 outAmount
    ) public {
        base = boundAddr(base);
        baseAsset = boundAddr(baseAsset);
        quote = boundAddr(quote);
        oracle = boundAddr(oracle);
        vm.assume(
            base != baseAsset && base != quote && base != oracle && baseAsset != quote && baseAsset != oracle
                && quote != oracle
        );
        inAmount = bound(inAmount, 1, type(uint128).max);
        vm.prank(GOVERNOR);
        router.govSetConfig(baseAsset, quote, oracle);

        vm.mockCall(base, abi.encodeWithSelector(IERC4626.asset.selector), abi.encode(baseAsset));
        vm.mockCall(base, abi.encodeWithSelector(IERC4626.convertToAssets.selector, inAmount), abi.encode(inAmount));
        vm.prank(GOVERNOR);
        router.govSetResolvedVault(base, true);

        vm.mockCall(
            oracle,
            abi.encodeWithSelector(IPriceOracle.getQuote.selector, inAmount, baseAsset, quote),
            abi.encode(outAmount)
        );
        vm.mockCall(
            oracle,
            abi.encodeWithSelector(IPriceOracle.getQuotes.selector, inAmount, baseAsset, quote),
            abi.encode(outAmount, outAmount)
        );
        uint256 _outAmount = router.getQuote(inAmount, base, quote);
        assertEq(_outAmount, outAmount);
        (uint256 bidOutAmount, uint256 askOutAmount) = router.getQuotes(inAmount, base, quote);
        assertEq(bidOutAmount, outAmount);
        assertEq(askOutAmount, outAmount);
    }

    function test_GetQuote_Integrity_QuoteIsVault(
        uint256 inAmount,
        address base,
        address quoteAsset,
        address quote,
        address oracle,
        uint256 outAmount
    ) public {
        base = boundAddr(base);
        quoteAsset = boundAddr(quoteAsset);
        quote = boundAddr(quote);
        oracle = boundAddr(oracle);
        vm.assume(
            base != quoteAsset && base != quote && base != oracle && quoteAsset != quote && quoteAsset != oracle
                && quote != oracle
        );
        inAmount = bound(inAmount, 1, type(uint128).max);
        vm.prank(GOVERNOR);
        router.govSetConfig(base, quoteAsset, oracle);

        vm.mockCall(quote, abi.encodeWithSelector(IERC4626.asset.selector), abi.encode(quoteAsset));
        vm.mockCall(quote, abi.encodeWithSelector(IERC4626.convertToShares.selector, inAmount), abi.encode(inAmount));
        vm.prank(GOVERNOR);
        router.govSetResolvedVault(quote, true);

        vm.mockCall(
            oracle,
            abi.encodeWithSelector(IPriceOracle.getQuote.selector, inAmount, base, quoteAsset),
            abi.encode(outAmount)
        );
        vm.mockCall(
            oracle,
            abi.encodeWithSelector(IPriceOracle.getQuotes.selector, inAmount, base, quoteAsset),
            abi.encode(outAmount, outAmount)
        );
        uint256 _outAmount = router.getQuote(inAmount, base, quote);
        assertEq(_outAmount, outAmount);
        (uint256 bidOutAmount, uint256 askOutAmount) = router.getQuotes(inAmount, base, quote);
        assertEq(bidOutAmount, outAmount);
        assertEq(askOutAmount, outAmount);
    }

    function test_GetQuote_Integrity_NoOracleButHasFallback(
        uint256 inAmount,
        address base,
        address quote,
        address fallbackOracle,
        uint256 outAmount
    ) public {
        base = boundAddr(base);
        quote = boundAddr(quote);
        fallbackOracle = boundAddr(fallbackOracle);
        vm.assume(base != quote && quote != fallbackOracle && base != fallbackOracle);
        inAmount = bound(inAmount, 1, type(uint128).max);

        vm.prank(GOVERNOR);
        router.govSetFallbackOracle(fallbackOracle);

        vm.mockCall(
            fallbackOracle,
            abi.encodeWithSelector(IPriceOracle.getQuote.selector, inAmount, base, quote),
            abi.encode(outAmount)
        );
        vm.mockCall(
            fallbackOracle,
            abi.encodeWithSelector(IPriceOracle.getQuotes.selector, inAmount, base, quote),
            abi.encode(outAmount, outAmount)
        );
        uint256 _outAmount = router.getQuote(inAmount, base, quote);
        assertEq(_outAmount, outAmount);
        (uint256 bidOutAmount, uint256 askOutAmount) = router.getQuotes(inAmount, base, quote);
        assertEq(bidOutAmount, outAmount);
        assertEq(askOutAmount, outAmount);
    }

    function test_GetQuote_RevertsWhen_NoOracleNoFallback(uint256 inAmount, address base, address quote) public {
        base = boundAddr(base);
        quote = boundAddr(quote);
        vm.assume(base != quote);
        inAmount = bound(inAmount, 1, type(uint128).max);

        vm.expectRevert(abi.encodeWithSelector(Errors.PriceOracle_NotSupported.selector, base, quote));
        router.getQuote(inAmount, base, quote);
        vm.expectRevert(abi.encodeWithSelector(Errors.PriceOracle_NotSupported.selector, base, quote));
        router.getQuotes(inAmount, base, quote);
    }

    function test_GetQuote_InverseProperty(uint256 inAmount, uint256 i, uint256 j) public {
        eWETH = address(new StubERC4626(WETH, 1.2e18));
        eeWETH = address(new StubERC4626(eWETH, 1.1e18));
        eDAI = address(new StubERC4626(DAI, 1.5e18));
        eeDAI = address(new StubERC4626(eDAI, 1.25e18));

        eOracle = new StubPriceOracle();
        eOracle.setPrice(WETH, DAI, 2500e18);
        eOracle.setPrice(DAI, WETH, 0.0004e18);

        vm.startPrank(GOVERNOR);
        router.govSetConfig(WETH, DAI, address(eOracle));
        router.govSetConfig(DAI, WETH, address(eOracle));
        router.govSetResolvedVault(eDAI, true);
        router.govSetResolvedVault(eeDAI, true);
        router.govSetResolvedVault(eWETH, true);
        router.govSetResolvedVault(eeWETH, true);
        vm.stopPrank();

        address[] memory tokens = new address[](6);
        tokens[0] = WETH;
        tokens[1] = eWETH;
        tokens[2] = eeWETH;
        tokens[3] = DAI;
        tokens[4] = eDAI;
        tokens[5] = eeDAI;

        inAmount = bound(inAmount, 1, type(uint128).max);
        i = bound(i, 0, tokens.length - 2);
        j = bound(j, i + 1, tokens.length - 1);

        uint256 outAmount_ij = router.getQuote(inAmount, tokens[i], tokens[j]);
        uint256 outAmount_ij_ji = router.getQuote(outAmount_ij, tokens[j], tokens[i]);
        assertApproxEqAbs(outAmount_ij_ji, inAmount, 10);

        (uint256 bidOutAmount_ij, uint256 askOutAmount_ij) = router.getQuotes(inAmount, tokens[i], tokens[j]);
        uint256 bidOutAmount_ij_ji = router.getQuote(bidOutAmount_ij, tokens[j], tokens[i]);
        uint256 askOutAmount_ij_ji = router.getQuote(askOutAmount_ij, tokens[j], tokens[i]);
        assertApproxEqAbs(bidOutAmount_ij_ji, inAmount, 10);
        assertApproxEqAbs(askOutAmount_ij_ji, inAmount, 10);
    }

    function test_GetQuote_ClosedLoopProperty(uint256 inAmount, LibPRNG.PRNG memory prng) public {
        eWETH = address(new StubERC4626(WETH, 1.2e18));
        eeWETH = address(new StubERC4626(eWETH, 1.1e18));
        eDAI = address(new StubERC4626(DAI, 1.5e18));
        eeDAI = address(new StubERC4626(eDAI, 1.25e18));

        eOracle = new StubPriceOracle();
        eOracle.setPrice(WETH, DAI, 2500e18);
        eOracle.setPrice(DAI, WETH, 0.0004e18);

        vm.startPrank(GOVERNOR);
        router.govSetConfig(WETH, DAI, address(eOracle));
        router.govSetConfig(DAI, WETH, address(eOracle));
        router.govSetResolvedVault(eDAI, true);
        router.govSetResolvedVault(eeDAI, true);
        router.govSetResolvedVault(eWETH, true);
        router.govSetResolvedVault(eeWETH, true);
        vm.stopPrank();

        address[] memory tokens = new address[](6);
        tokens[0] = WETH;
        tokens[1] = eWETH;
        tokens[2] = eeWETH;
        tokens[3] = DAI;
        tokens[4] = eDAI;
        tokens[5] = eeDAI;

        _shuffle(prng, tokens);

        inAmount = bound(inAmount, 1e18, type(uint128).max);

        uint256 initInAmount = inAmount;

        for (uint256 i = 0; i < tokens.length; ++i) {
            uint256 j = (i + 1) % tokens.length;
            inAmount = router.getQuote(inAmount, tokens[i], tokens[j]);
        }
        assertApproxEqRel(initInAmount, inAmount, 0.00000001e18);
    }

    function test_TransferGovernance_RevertsWhen_CallerNotGovernor(address caller, address newGovernor) public {
        vm.assume(caller != GOVERNOR);
        vm.expectRevert(Errors.Governance_CallerNotGovernor.selector);
        vm.prank(caller);
        router.transferGovernance(newGovernor);
    }

    function test_TransferGovernance_Integrity(address newGovernor) public {
        vm.assume(newGovernor != address(0));
        vm.prank(GOVERNOR);
        router.transferGovernance(newGovernor);

        assertEq(router.governor(), newGovernor);
    }

    function test_TransferGovernance_Integrity_ZeroAddress() public {
        vm.prank(GOVERNOR);
        router.transferGovernance(address(0));

        assertEq(router.governor(), address(0));
    }

    function _shuffle(LibPRNG.PRNG memory prng, address[] memory a) private pure {
        uint256[] memory a_;
        assembly {
            a_ := a
        }
        LibPRNG.shuffle(prng, a_);
    }
}
