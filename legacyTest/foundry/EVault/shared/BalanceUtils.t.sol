// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import "../../../../contracts/EVault/shared/BalanceUtils.sol";
import "../../../../contracts/EVault/shared/types/MarketCache.sol";
import "../../../../contracts/EVault/shared/types/Types.sol";
import "../../../../contracts/EVault/IEVault.sol";
import "../../../../contracts/EVault/shared/Errors.sol";
import "../../../../contracts/EVault/shared/Events.sol";

contract StorageInherit is BalanceUtils {
    using UserStorageLib for Storage.UserStorage;

    function getAllowance(address from, address to) public view returns (uint256) {
        return marketStorage.eVaultAllowance[from][to];
    }

    function setAllowance(address from, address to, uint256 allowance) public {
        marketStorage.eVaultAllowance[from][to] = allowance;
    }

    function getBalance(address account) public view returns (uint256) {
        return marketStorage.users[account].getBalance().toUint();
    }

    function setBalance(address account, Shares balance) public {
        marketStorage.users[account].setBalance(balance);
    }

    function _increaseBalance(
        MarketCache memory marketCache,
        address account,
        address sender,
        Shares amount,
        Assets assets
    ) public {
        increaseBalance(marketCache, account, sender, amount, assets);
    }

    function _decreaseBalance(
        MarketCache memory marketCache,
        address account,
        address sender,
        address receiver,
        Shares amount,
        Assets assets
    ) public {
        decreaseBalance(marketCache, account, sender, receiver, amount, assets);
    }

    function _transferBalance(address from, address to, Shares amount) public {
        transferBalance(from, to, amount);
    }

    function _decreaseAllowance(address from, address to, Shares amount) public {
        decreaseAllowance(from, to, amount);
    }
}

contract BalanceUtilsFuzzTest is Test, Events {
    using TypesLib for uint256;

    StorageInherit store = new StorageInherit();
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    MarketCache cache;

    function test_increaseBalance(uint112 amount, uint112 balance, uint112 totalShares) public {
        vm.assume(uint256(amount) + uint256(balance) <= MAX_SANE_AMOUNT);
        vm.assume(uint256(amount) + uint256(totalShares) <= MAX_SANE_AMOUNT);
        vm.assume(totalShares >= balance);

        cache.totalShares = uint256(totalShares).toShares();
        store.setBalance(alice, uint256(balance).toShares());

        vm.expectEmit(true, true, true, true, address(store));
        emit Events.Transfer(address(0), alice, uint256(amount));

        store._increaseBalance(cache, alice, bob, uint256(amount).toShares(), uint256(amount).toAssets());

        assertEq(store.getBalance(alice), uint256(balance) + uint256(amount));
    }

    function test_RevertWhenOverflowBalance_increaseBalance(uint112 amount, uint112 balance, uint112 totalShares)
        public
    {
        vm.assume(totalShares >= balance);
        vm.assume(uint256(amount) + uint256(balance) > MAX_SANE_AMOUNT);

        cache.totalShares = uint256(totalShares).toShares();
        store.setBalance(alice, uint256(balance).toShares());

        vm.expectRevert(Errors.E_AmountTooLargeToEncode.selector);

        store._increaseBalance(cache, alice, bob, uint256(amount).toShares(), uint256(amount).toAssets());
    }

    function test_decreaseBalance(uint112 amount, uint112 balance, uint112 totalShares) public {
        vm.assume(balance >= amount);
        vm.assume(totalShares >= balance);

        cache.totalShares = uint256(totalShares).toShares();
        store.setBalance(alice, uint256(balance).toShares());

        vm.expectEmit(true, true, true, true, address(store));
        emit Events.Transfer(alice, address(0), uint256(amount));

        store._decreaseBalance(cache, alice, bob, alice, uint256(amount).toShares(), uint256(amount).toAssets());

        assertEq(store.getBalance(alice), uint256(balance) - uint256(amount));
    }

    function test_RevertWhenNotEnoughBalance_decreaseBalance(uint112 amount, uint112 balance, uint112 totalShares)
        public
    {
        vm.assume(totalShares >= balance);
        vm.assume(balance < amount);

        cache.totalShares = uint256(totalShares).toShares();
        store.setBalance(alice, uint256(balance).toShares());

        vm.expectRevert(Errors.E_InsufficientBalance.selector);

        store._decreaseBalance(cache, alice, bob, alice, uint256(amount).toShares(), uint256(amount).toAssets());
    }

    function test_transferBalance(uint112 amount, uint112 balanceAlice, uint112 balanceBob, uint112 totalShares)
        public
    {
        vm.assume(totalShares >= uint256(balanceAlice) + uint256(balanceBob));
        vm.assume(balanceAlice >= amount);

        cache.totalShares = uint256(totalShares).toShares();
        store.setBalance(alice, uint256(balanceAlice).toShares());
        store.setBalance(bob, uint256(balanceBob).toShares());

        vm.expectEmit(true, true, true, true, address(store));
        emit Events.Transfer(alice, bob, uint256(amount));

        store._transferBalance(alice, bob, uint256(amount).toShares());

        assertEq(store.getBalance(alice), uint256(balanceAlice) - uint256(amount));
        assertEq(store.getBalance(bob), uint256(balanceBob) + uint256(amount));
    }

    function test_RevertWhenNotEnoughBalance_transferBalance(uint112 amount, uint112 balanceAlice) public {
        vm.assume(balanceAlice < amount);

        store.setBalance(alice, uint256(balanceAlice).toShares());

        vm.expectRevert(Errors.E_InsufficientBalance.selector);

        store._transferBalance(alice, bob, uint256(amount).toShares());
    }

    function test_decreaseAllowance(uint112 amount, uint112 allowance) public {
        vm.assume(allowance >= amount);

        store.setAllowance(alice, bob, uint256(allowance));

        vm.expectEmit(true, true, true, true, address(store));
        emit Events.Approval(alice, bob, uint256(allowance) - uint256(amount));

        store._decreaseAllowance(alice, bob, uint256(amount).toShares());

        assertEq(store.getAllowance(alice, bob), uint256(allowance) - uint256(amount));
    }

    function test_RevertWhenOverflowAmounts_decreaseAllowance(uint112 amount, uint112 allowance) public {
        vm.assume(allowance < amount);

        store.setAllowance(alice, bob, uint256(allowance));

        vm.expectRevert(Errors.E_InsufficientAllowance.selector);

        store._decreaseAllowance(alice, bob, uint256(amount).toShares());
    }
}
