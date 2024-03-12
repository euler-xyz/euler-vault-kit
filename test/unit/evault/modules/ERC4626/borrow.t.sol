// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVaultTestBase} from "../../EVaultTestBase.t.sol";
import {Events} from "src/EVault/shared/Events.sol";

import "src/EVault/shared/types/Types.sol";
import "src/EVault/shared/Constants.sol";

contract ERC4626Test_Borrow is EVaultTestBase {
    using TypesLib for uint256;

    address depositor;
    address borrower;

    function setUp() public override {
        super.setUp();

        depositor = makeAddr("depositor");
        borrower = makeAddr("borrower");

        // Setup

        oracle.setPrice(address(assetTST), unitOfAccount, 1e18);
        oracle.setPrice(address(eTST2), unitOfAccount, 1e18);

        eTST.setLTV(address(eTST2), uint16(9 * CONFIG_SCALE / 10), 0);


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
}
