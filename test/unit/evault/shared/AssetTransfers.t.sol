// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "src/EVault/shared/AssetTransfers.sol";
import "src/EVault/shared/Errors.sol";

import "../EVaultTestBase.t.sol";

contract AssetTransfersHarness is AssetTransfers {
    function exposed_pullTokens(MarketCache memory cache, address from, Assets amount) external {
        pullTokens(cache, from, amount);
    }
}

contract AssetTransfersTest is EVaultTestBase {
    using TypesLib for uint256;

    AssetTransfersHarness tc; // tested contract
    address from;

    function setUp() public override {
        super.setUp();

        tc = new AssetTransfersHarness();
        from = makeAddr("depositor");
        assetTST.mint(from, type(uint256).max);
        hoax(from);
        assetTST.approve(address(tc), type(uint256).max);
    }

    function testFuzz_pullTokens(uint256 cash, uint256 amount) public {
        cash = bound(cash, 0, MAX_SANE_AMOUNT);
        amount = bound(amount, 0, MAX_SANE_AMOUNT);
        vm.assume(cash + amount < MAX_SANE_AMOUNT);
        MarketCache memory cache = initCache();

        cache.cash = cash.toAssets();
        assetTST.setBalance(address(tc), cash);

        Assets assets = amount.toAssets();

        tc.exposed_pullTokens(cache, from, assets);
        uint256 cashAfter = assetTST.balanceOf(address(tc));
        Assets transferred = (cashAfter - cash).toAssets();

        assertEq(transferred, assets);
        assertEq(transferred.toUint(), assetTST.balanceOf(address(tc)) - cash);
    }

    function test_pullTokens_zeroIsNoop() public {
        MarketCache memory cache = initCache();

        tc.exposed_pullTokens(cache, from, Assets.wrap(0));
        uint256 cashAfter = assetTST.balanceOf(address(tc));
        Assets transferred = cashAfter.toAssets();

        assertEq(transferred, ZERO_ASSETS);
        assertEq(assetTST.balanceOf(address(tc)), 0);
    }

    function test_pullTokens_deflationaryTransfer() public {
        MarketCache memory cache = initCache();

        assetTST.configure("transfer/deflationary", abi.encode(0.5e18));

        tc.exposed_pullTokens(cache, from, Assets.wrap(1e18));
        uint256 cashAfter = assetTST.balanceOf(address(tc));
        Assets transferred = cashAfter.toAssets();

        assertEq(transferred, Assets.wrap(0.5e18));
        assertEq(assetTST.balanceOf(address(tc)), 0.5e18);
    }

    function test_pullTokens_inflationaryTransfer() public {
        MarketCache memory cache = initCache();

        assetTST.configure("transfer/inflationary", abi.encode(0.5e18));

        tc.exposed_pullTokens(cache, from, Assets.wrap(1e18));
        uint256 cashAfter = assetTST.balanceOf(address(tc));
        Assets transferred = cashAfter.toAssets();

        assertEq(transferred, Assets.wrap(1.5e18));
        assertEq(assetTST.balanceOf(address(tc)), 1.5e18);
    }

    function test_RevertWhenCashAfterOverflows_pullTokens() public {
        MarketCache memory cache = initCache();

        cache.cash = MAX_ASSETS;
        assetTST.setBalance(address(tc), MAX_ASSETS.toUint());

        vm.expectRevert(Errors.E_AmountTooLargeToEncode.selector);
        tc.exposed_pullTokens(cache, from, Assets.wrap(1));

        cache.cash = Assets.wrap(1);
        assetTST.setBalance(address(tc), 1);

        vm.expectRevert(Errors.E_AmountTooLargeToEncode.selector);
        tc.exposed_pullTokens(cache, from, MAX_ASSETS);
    }

    function initCache() internal view returns (MarketCache memory cache) {
        cache.asset = IERC20(address(assetTST));
    }
}
