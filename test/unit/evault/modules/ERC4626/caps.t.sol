// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVaultTestBase} from "test/unit/evault/EVaultTestBase.t.sol";
import {Errors} from "src/EVault/shared/Errors.sol";
import {Events} from "src/EVault/shared/Events.sol";
import "src/EVault/shared/types/Types.sol";

contract ERC4626Test_Caps is EVaultTestBase {
    using TypesLib for uint256;

    address user = makeAddr("user");

    function setUp() public override {
        super.setUp();

        assetTST.mint(user, type(uint256).max);
        vm.prank(user);
        assetTST.approve(address(eTST), type(uint256).max);
    }

    function test_SetMarketPolicy_Integrity(
        uint16 pauseBitmask, 
        uint16 supplyCap, 
        uint16 borrowCap
    ) public {
        uint256 supplyCapAmount = AmountCap.wrap(supplyCap).toUint();
        uint256 borrowCapAmount = AmountCap.wrap(borrowCap).toUint();
        vm.assume(supplyCapAmount <= MAX_SANE_AMOUNT && borrowCapAmount <= MAX_SANE_AMOUNT);

        vm.expectEmit();
        emit Events.GovSetMarketPolicy(pauseBitmask, supplyCap, borrowCap);

        eTST.setMarketPolicy(pauseBitmask, supplyCap, borrowCap);

        (uint32 pauseBitmask_, uint16 supplyCap_, uint16 borrowCap_) = eTST.marketPolicy();
        assertEq(pauseBitmask_, pauseBitmask);
        assertEq(supplyCap_, supplyCap);
        assertEq(borrowCap_, borrowCap);
    }

    function test_SetMarketPolicy_SupplyCapMaxMethods(uint16 supplyCap, address userA) public {
        uint256 supplyCapAmount = AmountCap.wrap(supplyCap).toUint();
        vm.assume(supplyCapAmount <= MAX_SANE_AMOUNT);

        eTST.setMarketPolicy(0, supplyCap, 0);

        assertEq(eTST.maxDeposit(userA), supplyCapAmount);
        assertEq(eTST.maxMint(userA), supplyCapAmount);
    }

    function test_SetMarketPolicy_RevertsWhen_AmountTooLarge(
        uint16 pauseBitmask, 
        uint16 supplyCap, 
        uint16 borrowCap
    ) public {
        vm.assume(
            AmountCap.wrap(supplyCap).toUint() > MAX_SANE_AMOUNT || 
            AmountCap.wrap(borrowCap).toUint() > MAX_SANE_AMOUNT
        );

        vm.expectRevert(Errors.RM_InvalidAmountCap.selector);
        eTST.setMarketPolicy(pauseBitmask, supplyCap, borrowCap);
    }

    function test_SetMarketPolicy_AccessControl(address caller) public {
        vm.assume(caller != eTST.governorAdmin());
        vm.expectRevert(Errors.RM_Unauthorized.selector);
        vm.prank(caller);
        eTST.setMarketPolicy(0, 0, 0);
    }

    function test_SupplyCap_UnlimitedByDefault() public {
        (, uint16 supplyCap,) = eTST.marketPolicy();
        assertEq(supplyCap, 0);

        vm.prank(user);
        eTST.deposit(MAX_SANE_AMOUNT, user);
        assertEq(eTST.totalSupply(), MAX_SANE_AMOUNT);

        vm.expectRevert();
        vm.prank(user);
        eTST.deposit(1, user);
    }

    function test_SupplyCap_CanBeZero() public {
        eTST.setMarketPolicy(0, 1, 0);
        vm.expectRevert();
        vm.prank(user);
        eTST.deposit(1, user);
    }

    function test_SupplyCap_WhenUnder_IncreasingActions(uint16 supplyCap, uint256 initAmount, uint256 amount) public {
        setUpCollateral();
        uint256 remaining = setUpUnderSupplyCap(supplyCap, initAmount);
        amount = bound(amount, 1, MAX_SANE_AMOUNT);
        bool shouldRevert = amount > remaining;
        uint256 snapshot = vm.snapshot();
        
        vm.revertTo(snapshot); 
        if (shouldRevert) vm.expectRevert();
        vm.prank(user);
        eTST.deposit(amount, user);

        vm.revertTo(snapshot); 
        if (shouldRevert) vm.expectRevert();
        vm.prank(user);
        eTST.mint(amount, user);

        vm.revertTo(snapshot); 
        if (shouldRevert) vm.expectRevert();
        vm.prank(user);
        eTST.wind(amount, user);
    }

    function test_SupplyCap_WhenAt_IncreasingActions(uint16 supplyCap, uint256 amount) public {
        setUpCollateral();
        setUpAtSupplyCap(supplyCap);
        amount = bound(amount, 1, MAX_SANE_AMOUNT);
        uint256 snapshot = vm.snapshot();
        
        vm.revertTo(snapshot); 
        vm.expectRevert();
        vm.prank(user);
        eTST.deposit(amount, user);

        vm.revertTo(snapshot); 
        vm.expectRevert();
        vm.prank(user);
        eTST.mint(amount, user);

        vm.revertTo(snapshot); 
        vm.expectRevert();
        vm.prank(user);
        eTST.wind(amount, user);
    }

    function test_SupplyCap_WhenOver_IncreasingActions(uint16 supplyCapOrig, uint16 supplyCapNow, uint256 amount) public {
        setUpCollateral();
        setUpOverSupplyCap(supplyCapOrig, supplyCapNow);
        amount = bound(amount, 1, MAX_SANE_AMOUNT);
        uint256 snapshot = vm.snapshot();
        
        vm.revertTo(snapshot); 
        vm.expectRevert();
        vm.prank(user);
        eTST.deposit(amount, user);

        vm.revertTo(snapshot); 
        vm.expectRevert();
        vm.prank(user);
        eTST.mint(amount, user);

        vm.revertTo(snapshot); 
        vm.expectRevert();
        vm.prank(user);
        eTST.wind(amount, user);
    }

    function test_SupplyCap_WhenUnder_DecreasingActions(uint16 supplyCap, uint256 initAmount, uint256 amount) public {
        setUpCollateral();
        uint256 remaining = setUpUnderSupplyCap(supplyCap, initAmount);
        amount = bound(amount, 1, AmountCap.wrap(supplyCap).toUint() - remaining);
        uint256 snapshot = vm.snapshot();

        vm.revertTo(snapshot); 
        vm.prank(user);
        eTST.withdraw(amount, user, user);

        vm.revertTo(snapshot); 
        vm.prank(user);
        eTST.redeem(amount, user, user);

        vm.revertTo(snapshot); 
        vm.prank(user);
        eTST.unwind(amount, user);
    }

    function test_SupplyCap_WhenAt_DecreasingActions(uint16 supplyCap, uint256 amount) public {
        setUpCollateral();
        setUpAtSupplyCap(supplyCap);
        amount = bound(amount, 1, AmountCap.wrap(supplyCap).toUint());
        uint256 snapshot = vm.snapshot();

        vm.revertTo(snapshot); 
        vm.prank(user);
        eTST.withdraw(amount, user, user);

        vm.revertTo(snapshot); 
        vm.prank(user);
        eTST.redeem(amount, user, user);

        vm.revertTo(snapshot); 
        vm.prank(user);
        eTST.unwind(amount, user);
    }

    function test_SupplyCap_WhenOver_DecreasingActions(uint16 supplyCapOrig, uint16 supplyCapNow, uint256 amount) public {
        setUpCollateral();
        setUpOverSupplyCap(supplyCapOrig, supplyCapNow);
        amount = bound(amount, 1, AmountCap.wrap(supplyCapNow).toUint());
        uint256 snapshot = vm.snapshot();

        vm.revertTo(snapshot); 
        vm.prank(user);
        eTST.withdraw(amount, user, user);

        vm.revertTo(snapshot); 
        vm.prank(user);
        eTST.redeem(amount, user, user);

        vm.revertTo(snapshot); 
        vm.prank(user);
        eTST.unwind(amount, user);
    }

    function test_BorrowCap_UnlimitedByDefault() public {
        setUpCollateral();
        vm.prank(user);
        eTST.deposit(MAX_SANE_AMOUNT, user);

        (,, uint16 borrowCap) = eTST.marketPolicy();
        assertEq(borrowCap, 0);

        vm.prank(user);
        eTST.borrow(MAX_SANE_AMOUNT, user);

        vm.expectRevert();
        vm.prank(user);
        eTST.borrow(1, user);
    }

    function test_BorrowCap_CanBeZero() public {
        setUpCollateral();
        vm.prank(user);
        eTST.deposit(MAX_SANE_AMOUNT, user);

        eTST.setMarketPolicy(0, 0, 1);

        vm.expectRevert();
        vm.prank(user);
        eTST.deposit(1, user);
    }

    function test_BorrowCap_WhenUnder_IncreasingActions(uint16 borrowCap, uint256 initAmount, uint256 amount) public {
        uint256 remaining = setUpUnderBorrowCap(borrowCap, initAmount);
        amount = bound(amount, 1, remaining);
        bool shouldRevert = amount > remaining;
        uint256 snapshot = vm.snapshot();
        
        vm.revertTo(snapshot); 
        if (shouldRevert) vm.expectRevert();
        vm.prank(user);
        eTST.borrow(amount, user);

        vm.revertTo(snapshot); 
        uint256 maxDeposit = MAX_SANE_AMOUNT - eTST.totalSupply();
        uint256 maxWind = maxDeposit < remaining ? maxDeposit : remaining;
        amount = bound(amount, 1, maxWind);
        if (shouldRevert) vm.expectRevert();
        vm.prank(user);
        eTST.wind(amount, user);
    }

    function test_BorrowCap_WhenAt_IncreasingActions(uint16 borrowCap, uint256 amount) public {
        setUpAtBorrowCap(borrowCap);
        amount = bound(amount, 1, MAX_SANE_AMOUNT);
        uint256 snapshot = vm.snapshot();
        
        vm.revertTo(snapshot); 
        vm.expectRevert();
        vm.prank(user);
        eTST.borrow(amount, user);
        
        vm.revertTo(snapshot); 
        vm.expectRevert();
        vm.prank(user);
        eTST.wind(amount, user);
    }

    function test_BorrowCap_WhenOver_IncreasingActions(uint16 borrowCapOrig, uint16 borrowCapNow, uint256 amount) public {
        setUpOverBorrowCap(borrowCapOrig, borrowCapNow);
        amount = bound(amount, 1, MAX_SANE_AMOUNT);
        uint256 snapshot = vm.snapshot();
        
        vm.revertTo(snapshot); 
        vm.expectRevert();
        vm.prank(user);
        eTST.borrow(amount, user);
        
        vm.revertTo(snapshot); 
        vm.expectRevert();
        vm.prank(user);
        eTST.wind(amount, user);
    }

    function test_BorrowCap_WhenUnder_DecreasingActions(uint16 borrowCap, uint256 initAmount, uint256 amount) public {
        uint256 remaining = setUpUnderBorrowCap(borrowCap, initAmount);
        amount = bound(amount, 0, AmountCap.wrap(borrowCap).toUint() - remaining);
        uint256 snapshot = vm.snapshot();
        
        vm.revertTo(snapshot); 
        vm.prank(user);
        eTST.repay(amount, user);
        
        vm.revertTo(snapshot); 
        vm.prank(user);
        eTST.unwind(amount, user);
    }

    function test_BorrowCap_WhenAt_DecreasingActions(uint16 borrowCap, uint256 amount) public {
        setUpAtBorrowCap(borrowCap);
        amount = bound(amount, 1, AmountCap.wrap(borrowCap).toUint());
        uint256 snapshot = vm.snapshot();
        
        vm.revertTo(snapshot); 
        vm.prank(user);
        eTST.repay(amount, user);
        
        vm.revertTo(snapshot); 
        vm.prank(user);
        eTST.unwind(amount, user);
    }

    function test_BorrowCap_WhenOver_DecreasingActions(uint16 borrowCapOrig, uint16 borrowCapNow, uint256 amount) public {
        setUpOverBorrowCap(borrowCapOrig, borrowCapNow);
        amount = bound(amount, 1, AmountCap.wrap(borrowCapOrig).toUint());
        uint256 snapshot = vm.snapshot();
        
        vm.revertTo(snapshot); 
        vm.prank(user);
        eTST.repay(amount, user);
        
        vm.revertTo(snapshot); 
        vm.prank(user);
        eTST.unwind(amount, user);
    }

    function setUpUnderSupplyCap(uint16 supplyCap, uint256 initAmount) internal returns (uint256) {
        uint256 supplyCapAmount = AmountCap.wrap(supplyCap).toUint();
        vm.assume(supplyCapAmount > 1 && supplyCapAmount < MAX_SANE_AMOUNT);
        eTST.setMarketPolicy(0, supplyCap, 0);

        initAmount = bound(initAmount, 1, supplyCapAmount - 1);

        vm.prank(user);
        eTST.deposit(initAmount, user);

        return supplyCapAmount - initAmount;
    }

    function setUpAtSupplyCap(uint16 supplyCap) internal {
        uint256 supplyCapAmount = AmountCap.wrap(supplyCap).toUint();
        vm.assume(supplyCapAmount != 0 && supplyCapAmount <= MAX_SANE_AMOUNT);

        eTST.setMarketPolicy(0, supplyCap, 0);
        vm.prank(user);
        eTST.deposit(supplyCapAmount, user);
    }

    function setUpOverSupplyCap(uint16 supplyCapOrig, uint16 supplyCapNow) internal {
        uint256 supplyCapOrigAmount = AmountCap.wrap(supplyCapOrig).toUint();
        uint256 supplyCapNowAmount = AmountCap.wrap(supplyCapNow).toUint();
        vm.assume(supplyCapOrigAmount > 1 && supplyCapOrigAmount <= MAX_SANE_AMOUNT);
        vm.assume(supplyCapNowAmount != 0 && supplyCapNowAmount < supplyCapOrigAmount);

        eTST.setMarketPolicy(0, supplyCapOrig, 0);
        vm.prank(user);
        eTST.deposit(supplyCapOrigAmount, user);
        eTST.setMarketPolicy(0, supplyCapNow, 0);
    }

    function setUpUnderBorrowCap(uint16 borrowCap, uint256 initAmount) internal returns (uint256) {
        setUpCollateral();

        uint256 borrowCapAmount = AmountCap.wrap(borrowCap).toUint();
        vm.assume(borrowCapAmount > 1 && borrowCapAmount < MAX_SANE_AMOUNT);
        eTST.setMarketPolicy(0, 0, borrowCap);

        initAmount = bound(initAmount, 0, borrowCapAmount - 1);

        vm.prank(user);
        eTST.deposit(borrowCapAmount, user);
        vm.prank(user);
        eTST.borrow(initAmount, user);

        return borrowCapAmount - initAmount;
    }

    function setUpAtBorrowCap(uint16 borrowCap) internal {
        setUpCollateral();

        uint256 borrowCapAmount = AmountCap.wrap(borrowCap).toUint();
        vm.assume(borrowCapAmount != 0 && borrowCapAmount < MAX_SANE_AMOUNT);
        eTST.setMarketPolicy(0, 0, borrowCap);

        vm.prank(user);
        eTST.deposit(borrowCapAmount, user);
        vm.prank(user);
        eTST.borrow(borrowCapAmount, user);
    }

    function setUpOverBorrowCap(uint16 borrowCapOrig, uint16 borrowCapNow) internal {
        uint256 borrowCapOrigAmount = AmountCap.wrap(borrowCapOrig).toUint();
        uint256 borrowCapNowAmount = AmountCap.wrap(borrowCapNow).toUint();
        vm.assume(borrowCapOrigAmount > 1 && borrowCapOrigAmount <= MAX_SANE_AMOUNT);
        vm.assume(borrowCapNowAmount != 0 && borrowCapNowAmount < borrowCapOrigAmount);

        setUpCollateral();

        eTST.setMarketPolicy(0, 0, borrowCapOrig);
        vm.prank(user);
        eTST.deposit(borrowCapOrigAmount, user);
        vm.prank(user);
        eTST.borrow(borrowCapOrigAmount, user);
        eTST.setMarketPolicy(0, 0, borrowCapNow);
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
