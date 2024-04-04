// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVaultTestBase} from "../../EVaultTestBase.t.sol";
import {Events} from "src/EVault/shared/Events.sol";
import {SafeERC20Lib} from "src/EVault/shared/lib/SafeERC20Lib.sol";
import {Permit2ECDSASigner} from "../../../../mocks/Permit2ECDSASigner.sol";
import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";
import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";

import "src/EVault/shared/types/Types.sol";

contract VaultTest_Deposit is EVaultTestBase {
    using TypesLib for uint256;

    error InvalidNonce();
    error InsufficientAllowance(uint256 amount);

    uint256 userPK;
    address user;
    address user1;

    Permit2ECDSASigner permit2Signer;

    function setUp() public override {
        super.setUp();

        permit2Signer = new Permit2ECDSASigner(address(permit2));

        userPK = 0x123400;
        user = vm.addr(userPK);
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
        uint256 amount = 1e18;

        vm.startPrank(user);
        assetTST.transfer(address(eTST), amount);

        assertEq(assetTST.balanceOf(address(eTST)), amount);
        assertEq(eTST.balanceOf(user), 0);
        assertEq(eTST.totalSupply(), 0);
        assertEq(eTST.totalAssets(), 0);

        eTST.deposit(amount, user);

        assertEq(assetTST.balanceOf(address(eTST)), amount * 2);
        assertEq(eTST.balanceOf(user), amount);
        assertEq(eTST.totalSupply(), amount);
        assertEq(eTST.totalAssets(), amount);
    }

    function test_depositWithPermit2() public {
        uint256 amount = 1e18;

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

    function test_depositWithPermit2InBatch() public {
        uint256 amount = 1e18;
        vm.warp(100);

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

        // build permit2 object
        IAllowanceTransfer.PermitSingle memory permitSingle = IAllowanceTransfer.PermitSingle({
            details: IAllowanceTransfer.PermitDetails({
                token: address(assetTST),
                amount: type(uint160).max,
                expiration: type(uint48).max,
                nonce: 0
            }),
            spender: address(eTST),
            sigDeadline: type(uint256).max
        });

        // build a deposit batch with permit2
        IEVC.BatchItem[] memory items = new IEVC.BatchItem[](2);
        items[0].onBehalfOfAccount = user;
        items[0].targetContract = permit2;
        items[0].value = 0;
        items[0].data = abi.encodeWithSignature(
            "permit(address,((address,uint160,uint48,uint48),address,uint256),bytes)",
            user,
            permitSingle,
            permit2Signer.signPermitSingle(userPK, permitSingle)
        );

        items[1].onBehalfOfAccount = user;
        items[1].targetContract = address(eTST);
        items[1].value = 0;
        items[1].data = abi.encodeCall(eTST.deposit, (amount, user));

        evc.batch(items);
        assertEq(assetTST.balanceOf(address(eTST)), amount);
        assertEq(eTST.balanceOf(user), amount);
        assertEq(eTST.totalSupply(), amount);
        assertEq(eTST.totalAssets(), amount);

        // cannot replay the same batch
        vm.expectRevert(InvalidNonce.selector);
        evc.batch(items);

        // modify permit
        permitSingle.details.amount = uint160(amount - 1);
        permitSingle.details.nonce = 1;

        // modify batch item
        items[0].data = abi.encodeWithSignature(
            "permit(address,((address,uint160,uint48,uint48),address,uint256),bytes)",
            user,
            permitSingle,
            permit2Signer.signPermitSingle(userPK, permitSingle)
        );

        // not enough permitted
        vm.expectRevert(
            abi.encodeWithSelector(
                SafeERC20Lib.E_TransferFromFailed.selector,
                abi.encodeWithSignature("Error(string)", "ERC20: transfer amount exceeds allowance"),
                abi.encodeWithSelector(InsufficientAllowance.selector, amount - 1)
            )
        );
        evc.batch(items);

        // cancel the approval to the vault via permit2
        IAllowanceTransfer(permit2).approve(address(assetTST), address(eTST), type(uint160).max, 1);

        // permit2 approval is expired
        vm.expectRevert(
            abi.encodeWithSelector(
                SafeERC20Lib.E_TransferFromFailed.selector,
                abi.encodeWithSignature("Error(string)", "ERC20: transfer amount exceeds allowance"),
                abi.encodeWithSelector(IAllowanceTransfer.AllowanceExpired.selector, 1)
            )
        );
        eTST.deposit(amount, user);

        // once again approve the vault
        assetTST.approve(address(eTST), amount);

        // deposit succeeds now
        eTST.deposit(amount, user);
        assertEq(assetTST.balanceOf(address(eTST)), 2 * amount);
        assertEq(eTST.balanceOf(user), 2 * amount);
        assertEq(eTST.totalSupply(), 2 * amount);
        assertEq(eTST.totalAssets(), 2 * amount);
    }
}
