// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import "../../../../contracts/EVault/shared/AssetTransfers.sol";
import "../../../../contracts/test/TestERC20.sol";
import "../../../../contracts/EVault/shared/types/MarketCache.sol";
import "../../../../contracts/EVault/shared/types/Types.sol";
import "../../../../contracts/EVault/IEVault.sol";
import "../../../../contracts/EVault/shared/Errors.sol";

contract StorageInherit is AssetTransfers {
    function getPoolSize() public returns (Assets) {
        return marketStorage.poolSize;
    }

    function _pullTokens(MarketCache memory marketCache, address from, Assets amount) public {
        pullTokens(marketCache, from, amount);
    }

    function _pushTokens(MarketCache memory marketCache, address to, Assets amount) public {
        pushTokens(marketCache, to, amount);
    }
}

contract AssetTransfersFuzzTest is Test {
    using TypesLib for uint256;

    TestERC20 TST = new TestERC20("Test Token", "TST", 18, false);
    StorageInherit store = new StorageInherit();
    MarketCache cache;
    address alice = makeAddr("alice");

    uint256 assetAlice = MAX_SANE_AMOUNT;

    function setUp() public {
        TST.mint(alice, assetAlice);

        vm.prank(alice);
        TST.approve(address(store), assetAlice);

        cache.asset = IERC20(address(TST));
    }

    function test_pullTokens(uint112 amount) public {
        store._pullTokens(cache, alice, uint256(amount).toAssets());
        assertEq(store.getPoolSize().toUint(), uint256(amount));
    }

    function test_RevertWhenOverflowPoolSize_pullTokens(uint112 amount, uint112 storageAsset) public {
        vm.assume(uint256(amount) + uint256(storageAsset) > MAX_SANE_AMOUNT);

        TST.mint(address(store), uint256(storageAsset));
        cache.poolSize = uint256(storageAsset).toAssets();

        vm.expectRevert(Errors.E_AmountTooLargeToEncode.selector);

        store._pullTokens(cache, alice, uint256(amount).toAssets());
    }

    function test_pushTokens(uint112 amount, uint112 storageAsset) public {
        vm.assume(amount <= storageAsset);

        TST.mint(address(store), uint256(storageAsset));
        cache.poolSize = uint256(storageAsset).toAssets();

        store._pushTokens(cache, alice, uint256(amount).toAssets());

        assertEq(store.getPoolSize().toUint(), uint256(storageAsset - amount));
    }

    function test_RevertWhenNotEnoughPoolSize_pushTokens(uint112 amount, uint112 storageAsset) public {
        vm.assume(amount > storageAsset);

        TST.mint(address(store), uint256(storageAsset));
        cache.poolSize = uint256(storageAsset).toAssets();

        vm.expectRevert("ERC20: transfer amount exceeds balance");

        store._pushTokens(cache, alice, uint256(amount).toAssets());
    }
}
