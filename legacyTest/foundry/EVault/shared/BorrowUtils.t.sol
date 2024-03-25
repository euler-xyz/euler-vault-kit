// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import "../../../../contracts/EVault/shared/BorrowUtils.sol";
import "../../../../contracts/EVault/shared/types/MarketCache.sol";
import "../../../../contracts/EVault/shared/types/Types.sol";
import "../../../../contracts/EVault/IEVault.sol";
import "../../../../contracts/EVault/shared/Errors.sol";
import "../../../../contracts/EVault/shared/Events.sol";
import "../../../../contracts/EVault/shared/EVCClient.sol";
import "../.././../../contracts/EVault/DToken.sol";

contract StorageInherit is BorrowUtils {
    using UserStorageLib for Storage.UserStorage;

    address dToken;

    constructor(address _evc) Base(_evc, address(0)) {
        dToken = address(new DToken());
    }

    function setUserInterestAccumulator(address account, uint256 interestAccumulator) public {
        marketStorage.users[account].interestAccumulator = interestAccumulator;
    }

    function setUserOwed(address account, Owed owed) public {
        marketStorage.users[account].setOwed(owed);
    }

    function _getCurrentOwed(MarketCache memory marketCache, address account, Owed owed) public view returns (Owed) {
        return getCurrentOwed(marketCache, account, owed);
    }

    function _getCurrentOwed(MarketCache memory marketCache, address account) public view returns (Owed) {
        return getCurrentOwed(marketCache, account);
    }

    function _updateUserBorrow(MarketCache memory marketCache, address account)
        public
        returns (Owed newOwed, Owed prevOwed)
    {
        prevOwed = marketStorage.users[account].getOwed();
        newOwed = getCurrentOwed(marketCache, account, prevOwed);

        marketStorage.users[account].setOwed(newOwed);
        marketStorage.users[account].interestAccumulator = marketCache.interestAccumulator;
    }

    function _increaseBorrow(MarketCache memory marketCache, address account, Assets assets) public {
        increaseBorrow(marketCache, account, assets);
    }

    function _decreaseBorrow(MarketCache memory marketCache, address account, Assets assets) public {
        decreaseBorrow(marketCache, account, assets);
    }

    function _transferBorrow(MarketCache memory marketCache, address from, address to, Assets assets) public {
        transferBorrow(marketCache, from, to, assets);
    }

    function _getRMLiability(MarketCache memory marketCache, address account)
        public
        view
        returns (IRiskManager.Liability memory liability)
    {
        return getRMLiability(marketCache, account);
    }

    function _updateInterestRate(MarketCache memory marketCache) public returns (uint72) {
        return updateInterestRate(marketCache);
    }
}

contract BorrowUtilsFuzzTest is Test {
    using TypesLib for uint256;

    StorageInherit store = new StorageInherit(address(0));
    MarketCache cache;
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function test_getCurrentOwed(uint144 owed, uint144 interestCache, uint144 interestUser) public {
        vm.assume(interestUser != 0);
        vm.assume(interestCache <= uint256(MAX_SANE_DEBT_AMOUNT) / (uint256(owed) + 1));

        store.setUserInterestAccumulator(alice, uint256(interestUser));
        cache.interestAccumulator = uint256(interestCache);

        Owed result = store._getCurrentOwed(cache, alice, uint256(owed).toOwed());

        uint256 value = uint256(owed) * uint256(interestCache) / uint256(interestUser);

        assertEq(result.toUint(), value);
    }

    function test_getCurrentOwed_Overload(uint144 owed, uint144 interestCache, uint144 interestUser) public {
        vm.assume(interestUser != 0);
        vm.assume(interestCache <= uint256(MAX_SANE_DEBT_AMOUNT) / (uint256(owed) + 1));

        store.setUserInterestAccumulator(alice, uint256(interestUser));
        store.setUserOwed(alice, uint256(owed).toOwed());
        cache.interestAccumulator = uint256(interestCache);

        Owed result = store._getCurrentOwed(cache, alice);

        uint256 value = uint256(owed) * uint256(interestCache) / uint256(interestUser);

        assertEq(result.toUint(), value);
    }

    function test_updateUserBorrow(uint144 owed, uint144 interestCache, uint144 interestUser) public {
        vm.assume(interestUser != 0);
        vm.assume(interestCache <= uint256(MAX_SANE_DEBT_AMOUNT) / (uint256(owed) + 1));

        store.setUserInterestAccumulator(alice, uint256(interestUser));
        store.setUserOwed(alice, uint256(owed).toOwed());
        cache.interestAccumulator = uint256(interestCache);

        (Owed newOwed, Owed prevOwed) = store._updateUserBorrow(cache, alice);

        uint256 value = uint256(owed) * uint256(interestCache) / uint256(interestUser);

        assertEq(newOwed.toUint(), value);
        assertEq(prevOwed.toUint(), uint256(owed));
    }

    function test_increaseBorrow(uint112 assets, uint144 owed, uint144 interestCache, uint144 interestUser) public {
        vm.assume(interestUser != 0);
        vm.assume(interestCache <= uint256(MAX_SANE_DEBT_AMOUNT) / (uint256(owed) + 1));

        store.setUserInterestAccumulator(alice, uint256(interestUser));
        store.setUserOwed(alice, uint256(owed).toOwed());
        cache.interestAccumulator = uint256(interestCache);

        store._increaseBorrow(cache, alice, uint256(assets).toAssets());
    }

    function test_decreaseBorrow(uint112 assets, uint144 owed, uint144 interestCache, uint144 interestUser) public {
        vm.assume(interestUser != 0);
        vm.assume(interestCache <= uint256(MAX_SANE_DEBT_AMOUNT) / (uint256(owed) + 1));
        vm.assume(
            uint256(assets)
                <= uint256(uint256(owed) * uint256(interestCache) / uint256(interestUser)).toOwed().toAssetsUp().toUint()
        );

        store.setUserInterestAccumulator(alice, uint256(interestUser));
        store.setUserOwed(alice, uint256(owed).toOwed());
        cache.interestAccumulator = uint256(interestCache);

        store._decreaseBorrow(cache, alice, uint256(assets).toAssets());
    }

    function test_transferBorrow(
        uint112 assets,
        uint144 owed,
        uint144 interestCache,
        uint144 interestAlice,
        uint144 interestBob
    ) public {
        vm.assume(interestAlice != 0);
        vm.assume(interestBob != 0);
        vm.assume(interestCache <= uint256(MAX_SANE_DEBT_AMOUNT) / (uint256(owed) + 1));
        vm.assume(
            uint256(assets)
                <= uint256(uint256(owed) * uint256(interestCache) / uint256(interestAlice)).toOwed().toAssetsUp().toUint()
        );

        store.setUserInterestAccumulator(alice, uint256(interestAlice));
        store.setUserInterestAccumulator(bob, uint256(interestBob));
        store.setUserOwed(alice, uint256(owed).toOwed());
        cache.interestAccumulator = uint256(interestCache);

        store._transferBorrow(cache, alice, bob, uint256(assets).toAssets());
    }
}
