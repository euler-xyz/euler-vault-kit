// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "test/unit/evault/EVaultTestBase.t.sol";
import {DToken} from "src/EVault/DToken.sol";
import {Errors} from "src/EVault/shared/Errors.sol";
import {Events} from "src/EVault/shared/Events.sol";

contract DTokenTest is EVaultTestBase {
    address user = makeAddr("user");

    DToken dToken;

    function setUp() public override {
        super.setUp();

        assetTST.mint(user, type(uint256).max);
        vm.prank(user);
        assetTST.approve(address(eTST), type(uint256).max);
        
        dToken = DToken(eTST.dToken());
    }

    function test_EVaultAddress() public {
        assertEq(dToken.eVault(), address(eTST));
    }

    function test_StringMetadata() public {
        assertNotEq(dToken.symbol(), "");
        assertNotEq(dToken.name(), "");
    }

    function test_Decimals_MirrorsEVault() public {
        assertEq(dToken.decimals(), eTST.decimals());
    }

    function test_Approve_NotSupported(address caller, address to, uint256 amount) public {
        vm.expectRevert(Errors.E_NotSupported.selector);
        vm.prank(caller);
        dToken.approve(to, amount);
    }

    function test_Transfer_NotSupported(address caller, address to, uint256 amount) public {
        vm.expectRevert(Errors.E_NotSupported.selector);
        vm.prank(caller);
        dToken.transfer(to, amount);
    }

    function test_TransferFrom_NotSupported(address caller, address from, address to, uint256 amount) public {
        vm.expectRevert(Errors.E_NotSupported.selector);
        vm.prank(caller);
        dToken.transferFrom(from, to, amount);
    }

    function test_Allowance_AlwaysZero(address from, address to) public {
        assertEq(dToken.allowance(from, to), 0);
    }

    function test_OnBorrow(uint256 amount) public {
        setUpCollateral();
        amount = bound(amount, 1, MAX_SANE_AMOUNT);
        vm.prank(user);
        eTST.deposit(amount, user);

        assertEq(dToken.balanceOf(user), 0);
        assertEq(dToken.totalSupply(), 0);
        
        vm.expectEmit();
        emit Events.Transfer(address(0), user, amount);
        vm.prank(user);
        eTST.borrow(amount, user);

        assertEq(dToken.balanceOf(user), amount);
        assertEq(dToken.totalSupply(), amount);
    }

    function test_OnWind(uint256 amount) public {
        setUpCollateral();
        amount = bound(amount, 1, MAX_SANE_AMOUNT);
        vm.expectEmit();
        emit Events.Transfer(address(0), user, amount);
        vm.prank(user);
        eTST.wind(amount, user);

        assertEq(dToken.balanceOf(user), amount);
        assertEq(dToken.totalSupply(), amount);
    }

    function test_OnRepay(uint256 amountBorrow, uint256 amountRepay) public {
        setUpCollateral();
        amountBorrow = bound(amountBorrow, 1, MAX_SANE_AMOUNT);
        amountRepay = bound(amountRepay, 1, amountBorrow);
        vm.prank(user);
        eTST.deposit(amountBorrow, user);
        vm.prank(user);
        eTST.borrow(amountBorrow, user);
        
        vm.expectEmit();
        emit Events.Transfer(user, address(0), amountRepay);
        vm.prank(user);
        eTST.repay(amountRepay, user);

        assertEq(dToken.balanceOf(user), amountBorrow - amountRepay);
        assertEq(dToken.totalSupply(), amountBorrow - amountRepay);
    }

    function test_OnUnwind(uint256 amountWind, uint256 amountUnwind) public {
        setUpCollateral();
        amountWind = bound(amountWind, 1, MAX_SANE_AMOUNT);
        amountUnwind = bound(amountUnwind, 1, amountWind);
        vm.prank(user);
        eTST.wind(amountWind, user);
        
        vm.expectEmit();
        emit Events.Transfer(user, address(0), amountUnwind);
        vm.prank(user);
        eTST.unwind(amountUnwind, user);

        assertEq(dToken.balanceOf(user), amountWind - amountUnwind);
        assertEq(dToken.totalSupply(), amountWind - amountUnwind);
    }

    function test_onPullDebt() public {
        vm.skip(true);
    }

    function test_onLiquidation() public {
        vm.skip(true);
    }

    function setUpCollateral() internal {
        eTST.setLTV(address(eTST2), uint16(CONFIG_SCALE), 0);

        vm.startPrank(user);
        assetTST2.mint(user, type(uint256).max);
        assetTST2.approve(address(eTST2), type(uint256).max);
        eTST2.deposit(MAX_SANE_AMOUNT / 100, user);

        evc.enableController(user, address(eTST));
        evc.enableCollateral(user, address(eTST2));

        oracle.setPrice(address(assetTST), unitOfAccount, 1 ether);
        oracle.setPrice(address(eTST2), unitOfAccount, 1000 ether);
        vm.stopPrank();
    }
}
