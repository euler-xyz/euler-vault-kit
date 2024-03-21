// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVaultTestBase, Test} from "../../EVaultTestBase.t.sol";
import {Events} from "src/EVault/shared/Events.sol";

import {console2} from "forge-std/Test.sol";

import "src/EVault/shared/types/Types.sol";
import "src/EVault/shared/Constants.sol";

// From Borrowing.sol
/// @notice Definition of callback method that flashLoan will invoke on your contract
interface IFlashLoan {
    function onFlashLoan(bytes memory data) external;
}

// Mocks
contract MockFlashloanReceiverDoesNothing is IFlashLoan, Test {
    function onFlashLoan(bytes memory data) external {
        (address assetTSTAddress, uint256 flashloanAmount) = abi.decode(data, (address, uint256));
        uint256 assetTSTBalance = IERC20(assetTSTAddress).balanceOf(address(this));

        assertEq(assetTSTBalance, flashloanAmount);
    }
}

contract MockFlashloanReceiverReturnsFunds is IFlashLoan, Test {
    function onFlashLoan(bytes memory data) external {
        (address eTSTAddress, address assetTSTAddress, uint256 repayAmount) = abi.decode(data, (address, address, uint256));

        IERC20(assetTSTAddress).transfer(eTSTAddress, repayAmount);
    }
}

contract MockFlashloanReceiverTriesReentry is IFlashLoan {
    function onFlashLoan(bytes memory data) external {

    }
}

contract MockFlashloanReceiverTriesReadReentry is IFlashLoan {
    function onFlashLoan(bytes memory data) external {

    }
}

contract VaultTest_Flashloan is EVaultTestBase {
    using TypesLib for uint256;

    address depositor;
    address borrower;
    
    address FLRDoesNothing;
    address FLRReturnsFunds;
    address FLRTriesReentry;
    address FLRTriesReadReentry;

    function setUp() public override {
        super.setUp();

        depositor = makeAddr("depositor");
        borrower = makeAddr("borrower");

        FLRDoesNothing = address(new MockFlashloanReceiverDoesNothing());
        FLRReturnsFunds = address(new MockFlashloanReceiverReturnsFunds());
        FLRTriesReentry = address(new MockFlashloanReceiverTriesReentry());
        FLRTriesReadReentry = address(new MockFlashloanReceiverTriesReadReentry());

        // Setup

        oracle.setPrice(address(assetTST), unitOfAccount, 1e18);
        oracle.setPrice(address(eTST2), unitOfAccount, 1e18);

        eTST.setLTV(address(eTST2), 0.9e4, 0);

        // Depositor

        startHoax(depositor);

        assetTST.mint(depositor, type(uint256).max);
        assetTST.approve(address(eTST), type(uint256).max);
        eTST.deposit(100e18, depositor);
    }

    function test_flashloanDoesNotRepay() public {
        startHoax(FLRDoesNothing);
        uint256 flashloanAmount = 10e18;

        // Expect this to revert as we won't be repaying
        vm.expectRevert(Errors.E_FlashLoanNotRepaid.selector);
        eTST.flashLoan(flashloanAmount, abi.encode(address(assetTST), flashloanAmount));
    }

    function test_flashloanUnderRepay() public {
        startHoax(FLRReturnsFunds);

        uint256 flashloanAmount = 10e18;
        uint256 repayAmount = flashloanAmount - 1e18;

        // Expect this to revert as we will under repay
        vm.expectRevert(Errors.E_FlashLoanNotRepaid.selector);
        eTST.flashLoan(flashloanAmount, abi.encode(address(eTST), address(assetTST), repayAmount));
    }

    function test_flashloanRepayLoan() public {
        startHoax(FLRReturnsFunds);

        uint256 assetTSTBalanceBefore = assetTST.balanceOf(address(eTST));

        uint256 flashloanAmount = 10e18;
        uint256 repayAmount = flashloanAmount;

        eTST.flashLoan(flashloanAmount, abi.encode(address(eTST), address(assetTST), repayAmount));

        uint256 assetTSTBalanceAfter = assetTST.balanceOf(address(eTST));

        assertEq(assetTSTBalanceBefore, assetTSTBalanceAfter);

        // TODO: Users borrows unaffected
    }

    function test_flashloanTryReentry() public {
        // TODO
    }

    function test_flashloanTryReadReentry() public {
        // TODO
    }

    function test_flashloanOpDisabled() public {
        vm.stopPrank();
        
        eTST.setDisabledOps(OP_FLASHLOAN);

        startHoax(FLRReturnsFunds);

        uint256 flashloanAmount = 10e18;
        uint256 repayAmount = flashloanAmount;

        // Expect this to revert as flashloan is disabled
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.flashLoan(flashloanAmount, abi.encode(address(eTST), address(assetTST), repayAmount));
    }
}
