// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVaultTestBase} from "../../EVaultTestBase.t.sol";
import {Events} from "src/EVault/shared/Events.sol";
import {SafeERC20Lib} from "src/EVault/shared/lib/SafeERC20Lib.sol";
import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";

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
    // function testFuzz_deposit(uint amount, address receiver, uint cash) public {
    //     amount = bound(amount, 1, MAX_SANE_AMOUNT);
    //     cash = bound(cash, 0, MAX_SANE_AMOUNT);
    //     vm.assume(cash + amount < MAX_SANE_AMOUNT);
    //     vm.assume(receiver != address(0));
    //     uint shares = amount / (cash + 1);

    //     vm.assume(shares > 0);

    //     // send tokens directly to the pool to inflate the exchange rate
    //     startHoax(user1);
    //     assetTST.transfer(address(eTST), cash);
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
    //     assertEq(assetTST.balanceOf(address(eTST)), amount + cash);
    //     assertEq(eTST.totalAssets(), amount + cash);

    //     // Shares were issued
    //     assertEq(eTST.balanceOf(receiver), shares);
    //     assertEq(eTST.totalSupply(), shares);
    // }

    // TODO zero receiver

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

    function test_directTransfer() public {
        uint amount = 1e18;

        vm.startPrank(user);
        assetTST.transfer(address(eTST), amount);

        assertEq(assetTST.balanceOf(address(eTST)), amount);
        assertEq(eTST.balanceOf(user), 0);
        assertEq(eTST.totalSupply(), 0);
        assertEq(eTST.totalAssets(), 0);

        eTST.deposit(amount, user);

        assertEq(assetTST.balanceOf(address(eTST)), amount*2);
        assertEq(eTST.balanceOf(user), amount);
        assertEq(eTST.totalSupply(), amount);
        assertEq(eTST.totalAssets(), amount);
    }

    function test_depositWithPermit2() public {
        uint amount = 1e18;

        // cancel the approval to the vault
        assetTST.approve(address(eTST), 0);

        // deposit won't succeed without any approval
        vm.expectRevert(
            abi.encodeWithSelector(
                SafeERC20Lib.E_TransferFromFailed.selector, 
                abi.encodeWithSignature("Error(string)", "ERC20: transfer amount exceeds allowance"), 
                abi.encodeWithSelector(IAllowanceTransfer.AllowanceExpired.selector, 0)
            )
        );
        eTST.deposit(amount, user);

        // approve permit2 contract to spend the tokens
        assetTST.approve(permit2, type(uint160).max);

        // approve the vault to spend the tokens via permit2
        IAllowanceTransfer(permit2).approve(address(assetTST), address(eTST), type(uint160).max, type(uint48).max);

        // deposit succeeds now
        eTST.deposit(amount, user);

        assertEq(assetTST.balanceOf(address(eTST)), amount);
        assertEq(eTST.balanceOf(user), amount);
        assertEq(eTST.totalSupply(), amount);
        assertEq(eTST.totalAssets(), amount);
    }
}
