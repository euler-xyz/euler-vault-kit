// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVaultTestBase} from "../../EVaultTestBase.t.sol";
import {Events} from "src/EVault/shared/Events.sol";
import {SafeERC20Lib} from "src/EVault/shared/lib/SafeERC20Lib.sol";
import {IRMMax} from "../../../../mocks/IRMMax.sol";

import {IEVault, IRMTestDefault} from "../../EVaultTestBase.t.sol";

import "src/EVault/shared/types/Types.sol";
import "src/EVault/shared/Constants.sol";


contract VaultTest_Nested is EVaultTestBase {
    using TypesLib for uint256;

    address depositor;
    address borrower;

    IEVault public eTSTNested;
    IEVault public eTSTDoubleNested;

    function setUp() public override {
        super.setUp();

        eTSTNested = IEVault(coreProductLine.createVault(address(eTST), address(oracle), unitOfAccount));
        eTSTNested.setInterestRateModel(address(new IRMTestDefault()));

        depositor = makeAddr("depositor");
        borrower = makeAddr("borrower");

        // Setup

        oracle.setPrice(address(assetTST), unitOfAccount, 1e18);
        oracle.setPrice(address(eTST2), unitOfAccount, 1e18);
        eTST.setLTV(address(eTST2), 0.9e4, 0);

        eTSTNested.setLTV(address(eTST2), 0.9e4, 0);

        // Depositor

        startHoax(depositor);

        assetTST.mint(depositor, type(uint256).max);
        assetTST.approve(address(eTST), type(uint256).max);
        eTST.deposit(100e18, depositor);
        vm.stopPrank();
    }

    function test_basicDeposit() public {
        startHoax(depositor);

        eTST.approve(address(eTSTNested), type(uint256).max);
        eTSTNested.deposit(10e18, depositor);
        
        assertEq(eTST.balanceOf(depositor), 90e18);
        assertEq(eTSTNested.balanceOf(depositor), 10e18);
    }


    function test_basicBorrow() public {
        startHoax(depositor);

        eTST.approve(address(eTSTNested), type(uint256).max);
        eTSTNested.deposit(10e18, depositor);
        vm.stopPrank();


        startHoax(borrower);

        assetTST2.mint(borrower, type(uint256).max);
        assetTST2.approve(address(eTST2), type(uint256).max);
        eTST2.deposit(10e18, borrower);

        evc.enableCollateral(borrower, address(eTST2));
        evc.enableController(borrower, address(eTSTNested));

        eTSTNested.borrow(5e18, borrower);
        assertEq(eTST.balanceOf(borrower), 5e18);
    }


    function test_basicBorrowAndRedeem() public {
        startHoax(depositor);

        eTST.approve(address(eTSTNested), type(uint256).max);
        eTSTNested.deposit(10e18, depositor);
        vm.stopPrank();

        startHoax(borrower);

        assetTST2.mint(borrower, type(uint256).max);
        assetTST2.approve(address(eTST2), type(uint256).max);
        eTST2.deposit(10e18, borrower);

        evc.enableCollateral(borrower, address(eTST2));
        evc.enableController(borrower, address(eTSTNested));

        eTSTNested.borrow(5e18, borrower);

        eTST.redeem(5e18, borrower, borrower);

        assertEq(eTST.balanceOf(borrower), 0);
        assertEq(assetTST.balanceOf(borrower), 5e18);
    }

    function test_borrowAndOriginalDepositorWithdraws() public {
        startHoax(depositor);

        eTST.approve(address(eTSTNested), type(uint256).max);
        eTSTNested.deposit(10e18, depositor);
        vm.stopPrank();

        startHoax(borrower);

        assetTST2.mint(borrower, type(uint256).max);
        assetTST2.approve(address(eTST2), type(uint256).max);
        eTST2.deposit(10e18, borrower);

        evc.enableCollateral(borrower, address(eTST2));
        evc.enableController(borrower, address(eTSTNested));

        eTSTNested.borrow(5e18, borrower);

        vm.stopPrank();
        
        startHoax(depositor);

        // expect this to rever as there is some amount borrowed
        vm.expectRevert(Errors.E_InsufficientCash.selector);
        eTSTNested.redeem(10e18, depositor, depositor);

        uint256 maxRedeemAmount = eTSTNested.maxRedeem(depositor);
        eTSTNested.redeem(maxRedeemAmount, depositor, depositor);

        assertEq(eTSTNested.balanceOf(depositor), 10e18 - maxRedeemAmount, "eTSTNested Balance");
        assertEq(eTST.balanceOf(depositor), 90e18 + maxRedeemAmount, "eTST Balance");
    }

    function test_doubleNestedDepositAndBorrow() public {
        eTSTDoubleNested = IEVault(coreProductLine.createVault(address(eTSTNested), address(oracle), unitOfAccount));
        eTSTDoubleNested.setInterestRateModel(address(new IRMTestDefault()));

        eTSTDoubleNested.setLTV(address(eTST2), 0.9e4, 0);


        startHoax(depositor);

        eTST.approve(address(eTSTNested), type(uint256).max);
        eTSTNested.deposit(20e18, depositor);


        eTSTNested.approve(address(eTSTDoubleNested), type(uint256).max);
        eTSTDoubleNested.deposit(15e18, depositor);

        assertEq(eTSTNested.balanceOf(depositor), 5e18);
        assertEq(eTSTDoubleNested.balanceOf(depositor), 15e18);

        vm.stopPrank();

        startHoax(borrower);

        assetTST2.mint(borrower, type(uint256).max);
        assetTST2.approve(address(eTST2), type(uint256).max);
        eTST2.deposit(10e18, borrower);

        evc.enableCollateral(borrower, address(eTST2));
        evc.enableController(borrower, address(eTSTDoubleNested));

        vm.expectRevert(Errors.E_ControllerDisabled.selector);
        eTSTNested.borrow(5e18, borrower);
        
        eTSTDoubleNested.borrow(5e18, borrower);
        assertEq(eTSTNested.balanceOf(borrower), 5e18);
    }
}