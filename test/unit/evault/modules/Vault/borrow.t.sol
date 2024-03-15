// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVaultTestBase} from "../../EVaultTestBase.t.sol";
import {Events} from "src/EVault/shared/Events.sol";
import {SafeERC20Lib} from "src/EVault/shared/lib/SafeERC20Lib.sol";
import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";

import "src/EVault/shared/types/Types.sol";
import "src/EVault/shared/Constants.sol";

contract ERC4626Test_Borrow is EVaultTestBase {
    using TypesLib for uint256;

    address depositor;
    address borrower;
    address borrower2;

    function setUp() public override {
        super.setUp();

        depositor = makeAddr("depositor");
        borrower = makeAddr("borrower");
        borrower2 = makeAddr("borrower_2");

        // Setup

        oracle.setPrice(address(assetTST), unitOfAccount, 1e18);
        oracle.setPrice(address(eTST2), unitOfAccount, 1e18);

        eTST.setLTV(address(eTST2), 0.9e4, 0);


        // Depositor

        startHoax(depositor);

        assetTST.mint(depositor, type(uint256).max);
        assetTST.approve(address(eTST), type(uint256).max);
        eTST.deposit(100e18, depositor);


        // Borrower

        startHoax(borrower);

        assetTST2.mint(borrower, type(uint256).max);
        assetTST2.approve(address(eTST2), type(uint256).max);
        eTST2.deposit(10e18, borrower);
    }


    function test_basicBorrow() public {
        startHoax(borrower);

        evc.enableCollateral(borrower, address(eTST2));
        evc.enableController(borrower, address(eTST));

        eTST.borrow(5e18, borrower);
        assertEq(assetTST.balanceOf(borrower), 5e18);

        // Should be able to borrow up to 9, so this should fail:

        vm.expectRevert(Errors.E_AccountLiquidity.selector);
        eTST.borrow(4.0001e18, borrower);

        // Disable collateral should fail

        vm.expectRevert(Errors.E_AccountLiquidity.selector);
        evc.disableCollateral(borrower, address(eTST2));

        // Repay

        assetTST.approve(address(eTST), type(uint256).max);
        eTST.repay(type(uint256).max, borrower);

        evc.disableCollateral(borrower, address(eTST2));
        assertEq(evc.getCollaterals(borrower).length, 0);

        eTST.disableController();
        assertEq(evc.getControllers(borrower).length, 0);
    }

    function test_repayWithPermit2() public {
        startHoax(borrower);

        evc.enableCollateral(borrower, address(eTST2));
        evc.enableController(borrower, address(eTST));

        eTST.borrow(5e18, borrower);
        assertEq(assetTST.balanceOf(borrower), 5e18);

        // deposit won't succeed without any approval
        vm.expectRevert(
            abi.encodeWithSelector(
                SafeERC20Lib.E_TransferFromFailed.selector, 
                abi.encodeWithSignature("Error(string)", "ERC20: transfer amount exceeds allowance"), 
                abi.encodeWithSelector(IAllowanceTransfer.AllowanceExpired.selector, 0)
            )
        );
        eTST.repay(type(uint256).max, borrower);

        // approve permit2 contract to spend the tokens
        assetTST.approve(permit2, type(uint160).max);

        // approve the vault to spend the tokens via permit2
        IAllowanceTransfer(permit2).approve(address(assetTST), address(eTST), type(uint160).max, type(uint48).max);

        // repay succeeds now
        eTST.repay(type(uint256).max, borrower);

        assertEq(eTST.debtOf(borrower), 0);
    }

    function test_pullDebt_when_from_equal_account() public {
        startHoax(borrower);
        uint256 amountToBorrow = 5e18;

        evc.enableCollateral(borrower, address(eTST2));
        evc.enableController(borrower, address(eTST));

        eTST.borrow(amountToBorrow, borrower);
        assertEq(assetTST.balanceOf(borrower), amountToBorrow);

        vm.expectRevert(Errors.E_SelfTransfer.selector);
        eTST.pullDebt(amountToBorrow, borrower);
    }

    function test_pullDebt_zero_amount() public {
        startHoax(borrower);
        uint256 amountToBorrow = 5e18;

        evc.enableCollateral(borrower, address(eTST2));
        evc.enableController(borrower, address(eTST));

        eTST.borrow(amountToBorrow, borrower);
        assertEq(assetTST.balanceOf(borrower), amountToBorrow);
        vm.stopPrank();


        startHoax(borrower2);

        evc.enableCollateral(borrower2, address(eTST2));
        evc.enableController(borrower2, address(eTST));

        eTST.pullDebt(0, borrower);
        vm.stopPrank();

        assertEq(eTST.debtOf(borrower), amountToBorrow);
        assertEq(eTST.debtOf(borrower2), 0);
    }

    function test_pullDebt_full_amount() public {
        startHoax(borrower);
        uint256 amountToBorrow = 5e18;

        evc.enableCollateral(borrower, address(eTST2));
        evc.enableController(borrower, address(eTST));

        eTST.borrow(amountToBorrow, borrower);
        assertEq(assetTST.balanceOf(borrower), amountToBorrow);

        // transfering some minted asset to borrower2
        assetTST2.transfer(borrower2, 10e18);
        vm.stopPrank();


        startHoax(borrower2);

        // deposit into eTST2 to cover the liability from pullDebt
        assetTST2.approve(address(eTST2), type(uint256).max);
        eTST2.deposit(10e18, borrower2);

        evc.enableCollateral(borrower2, address(eTST2));
        evc.enableController(borrower2, address(eTST));

        eTST.pullDebt(type(uint256).max, borrower);
        vm.stopPrank();

        assertEq(assetTST.balanceOf(borrower), amountToBorrow);
        assertEq(assetTST.balanceOf(borrower2), 0);
        assertEq(eTST.debtOf(borrower), 0);
        assertEq(eTST.debtOf(borrower2), amountToBorrow);
    }

    function test_pullDebt_amount_gt_debt() public {
        startHoax(borrower);
        uint256 amountToBorrow = 5e18;

        evc.enableCollateral(borrower, address(eTST2));
        evc.enableController(borrower, address(eTST));

        eTST.borrow(amountToBorrow, borrower);
        assertEq(assetTST.balanceOf(borrower), amountToBorrow);
        assertEq(eTST.debtOf(borrower), amountToBorrow);
        vm.stopPrank();


        startHoax(borrower2);

        evc.enableCollateral(borrower2, address(eTST2));
        evc.enableController(borrower2, address(eTST));

        vm.expectRevert(Errors.E_InsufficientBalance.selector);
        eTST.pullDebt(amountToBorrow+1, borrower);
        vm.stopPrank();
    }
}
