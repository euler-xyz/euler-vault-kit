// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVaultTestBase} from "../../EVaultTestBase.t.sol";
import {Errors} from "src/EVault/shared/Errors.sol";
import {IEVault} from "src/EVault/IEVault.sol";
import {TestERC20} from "../../../../mocks/TestERC20.sol";
import {IRMTestZero} from "../../../../mocks/IRMTestZero.sol";
import "src/EVault/shared/types/Types.sol";

contract VaultTest_LoopDeloop is EVaultTestBase {
    address user1;
    address user2;
    address user3;

    TestERC20 assetTST3;
    IEVault public eTST3;

    function setUp() public override {
        super.setUp();

        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");

        assetTST3 = new TestERC20("Test TST 3", "TST3", 18, false);

        eTST3 = IEVault(factory.createProxy(true, abi.encodePacked(address(assetTST3), address(oracle), unitOfAccount)));

        startHoax(address(this));
        eTST.setInterestRateModel(address(new IRMTestZero()));
        eTST2.setInterestRateModel(address(new IRMTestZero()));
        eTST3.setInterestRateModel(address(new IRMTestZero()));

        eTST.setLTV(address(eTST2), 0.3e4, 0);
        eTST2.setLTV(address(eTST), 0.3e4, 0);
        eTST3.setLTV(address(eTST), 0.3e4, 0);
        eTST3.setLTV(address(eTST2), 0.3e4, 0);

        startHoax(user1);
        assetTST.approve(address(eTST), type(uint256).max);
        assetTST2.approve(address(eTST2), type(uint256).max);
        evc.enableCollateral(user1, address(eTST));
        evc.enableCollateral(user1, address(eTST2));

        startHoax(user2);
        assetTST.approve(address(eTST), type(uint256).max);
        assetTST2.approve(address(eTST2), type(uint256).max);
        evc.enableCollateral(user2, address(eTST));
        evc.enableCollateral(user2, address(eTST2));

        startHoax(user3);
        assetTST.approve(address(eTST), type(uint256).max);
        assetTST2.approve(address(eTST2), type(uint256).max);
        evc.enableCollateral(user3, address(eTST));
        evc.enableCollateral(user3, address(eTST2));

        assetTST.mint(user1, 100e18);
        assetTST2.mint(user2, 100e18);
        assetTST2.mint(user3, 100e18);

        startHoax(user1);
        eTST.deposit(10e18, user1);

        startHoax(user2);
        eTST2.deposit(10e18, user2);

        oracle.setPrice(address(eTST), unitOfAccount, 2e18);
        oracle.setPrice(address(eTST2), unitOfAccount, 0.083e18);

        skip(31 * 60);
    }

    function test_loop_noLiquidity() public {
        startHoax(user3);
        evc.enableController(user3, address(eTST));
        vm.expectRevert(Errors.E_AccountLiquidity.selector);
        eTST.loop(1e18, user3);
    }

    //borrow on empty pool, and repay
    function test_loopDeloop_emptyPool() public {
        startHoax(address(this));
        eTST3.setInterestRateModel(address(new IRMTestZero()));

        assertEq(eTST3.totalSupply(), 0);
        assertEq(eTST3.totalBorrows(), 0);

        startHoax(user1);
        evc.enableController(user1, address(eTST3));
        eTST3.loop(1e18, user1);

        assertEq(eTST3.balanceOf(user1), 1e18);
        assertEq(eTST3.debtOf(user1), 1e18);

        eTST3.deloop(1e18, user1);

        assertEq(eTST3.debtOf(user1), 0);

        assetTST3.approve(address(eTST3), type(uint256).max);
        assetTST3.mint(user1, 1e18);
        eTST3.deposit(1e18, user1);

        assertEq(eTST3.balanceOf(user1), 1e18);
        assertEq(eTST3.debtOf(user1), 0);
        assertEq(eTST3.totalSupply(), 1e18);
        assertEq(eTST3.totalBorrows(), 0);
    }
}
