// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVaultTestBase} from "../../EVaultTestBase.t.sol";
import {Events} from "src/EVault/shared/Events.sol";

import "src/EVault/shared/types/Types.sol";

contract ERC4626Test_Deposit is EVaultTestBase {
    using TypesLib for uint256;

    address user;
    address user1;

    function setUp() public override {
        super.setUp();

        user = makeAddr("depositor");
        user1 = makeAddr("user1");

        assetTST.mint(user1, type(uint256).max);
        hoax(user1);
        assetTST.approve(address(eTST), type(uint256).max);

        assetTST.mint(user, type(uint256).max);
        startHoax(user);
        assetTST.approve(address(eTST), type(uint256).max);
    }

    function test_maxSaneAmount() public {
        vm.expectRevert(Errors.E_AmountTooLargeToEncode.selector);
        eTST.deposit(MAX_SANE_AMOUNT + 1, user);

        eTST.deposit(MAX_SANE_AMOUNT, user);

        assertEq(assetTST.balanceOf(address(eTST)), MAX_SANE_AMOUNT);

        vm.expectRevert(Errors.E_AmountTooLargeToEncode.selector);
        eTST.deposit(1, user);
    }

    function test_zeroAmountIsNoop() public {
        assertEq(assetTST.balanceOf(address(eTST)), 0);
        assertEq(eTST.balanceOf(user), 0);

        eTST.deposit(0, user);

        assertEq(assetTST.balanceOf(address(eTST)), 0);
        assertEq(eTST.balanceOf(user), 0);
    }

    // TODO
    // function testFuzz_deposit(uint amount, address receiver, uint poolSize) public {
    //     amount = bound(amount, 1, MAX_SANE_AMOUNT);
    //     poolSize = bound(poolSize, 0, MAX_SANE_AMOUNT);
    //     vm.assume(poolSize + amount < MAX_SANE_AMOUNT);
    //     vm.assume(receiver != address(0));
    //     uint shares = amount / (poolSize + 1);

    //     vm.assume(shares > 0);

    //     // send tokens directly to the pool to inflate the exchange rate
    //     startHoax(user1);
    //     assetTST.transfer(address(eTST), poolSize);
    //     startHoax(user);

    //     vm.expectEmit();
    //     emit Events.RequestDeposit({owner: user, receiver: receiver, assets: amount});
    //     vm.expectEmit(address(eTST));
    //     emit Events.Transfer({from: address(0), to: receiver, value: shares});
    //     vm.expectEmit();
    //     emit Events.Deposit({sender: user, owner: receiver, assets: amount, shares: shares});

    //     uint result = eTST.deposit(amount, receiver);
    //     assertEq(result, shares);

    //     // Asset was transferred
    //     assertEq(assetTST.balanceOf(user), type(uint).max - amount);
    //     assertEq(assetTST.balanceOf(address(eTST)), amount + poolSize);
    //     assertEq(eTST.totalAssets(), amount + poolSize);

    //     // Shares were issued
    //     assertEq(eTST.balanceOf(receiver), shares);
    //     assertEq(eTST.totalSupply(), shares);
    // }

    function test_defaultReceiver() public {
        uint256 amount = 1e18;

        vm.expectEmit(address(eTST));
        emit Events.Transfer({from: address(0), to: user, value: amount});
        vm.expectEmit();
        emit Events.Deposit({sender: user, owner: user, assets: amount, shares: amount});

        eTST.deposit(amount, address(0));

        assertEq(eTST.balanceOf(user), amount);
        assertEq(eTST.totalSupply(), amount);
    }

    function test_zeroShares() public {
        // TODO
        // assetTST.transfer(address(eTST), 2e18);

        // vm.expectRevert(Errors.E_ZeroShares.selector);
        // eTST.deposit(1e18, user);
    }

    function test_maxUintAmount() public {
        address user2 = makeAddr("user2");
        startHoax(user2);

        eTST.deposit(type(uint256).max, user2);

        assertEq(eTST.totalAssets(), 0);
        assertEq(eTST.balanceOf(user2), 0);
        assertEq(eTST.totalSupply(), 0);

        uint256 walletBalance = 2e18;

        assetTST.mint(user2, walletBalance);
        assetTST.approve(address(eTST), type(uint256).max);

        eTST.deposit(type(uint256).max, user2);

        assertEq(eTST.totalAssets(), walletBalance);
        assertEq(eTST.balanceOf(user2), walletBalance);
        assertEq(eTST.totalSupply(), walletBalance);
    }
}
