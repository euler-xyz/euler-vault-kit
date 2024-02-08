// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVaultTestBase} from "test/unit/evault/EVaultTestBase.t.sol";
import {Errors} from "src/EVault/shared/Errors.sol";
import {GovernanceModule} from "src/EVault/modules/Governance.sol";
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
        uint32 pauseBitmask, 
        uint16 supplyCap, 
        uint16 borrowCap
    ) public {
        uint256 supplyCapAmount = AmountCap.wrap(supplyCap).toAmount();
        uint256 borrowCapAmount = AmountCap.wrap(borrowCap).toAmount();
        vm.assume(supplyCapAmount <= MAX_SANE_AMOUNT && borrowCapAmount <= MAX_SANE_AMOUNT);

        vm.expectEmit();
        emit GovernanceModule.GovSetMarketPolicy(pauseBitmask, supplyCap, borrowCap);

        eTST.setMarketPolicy(pauseBitmask, supplyCap, borrowCap);

        (uint32 pauseBitmask_, uint16 supplyCap_, uint16 borrowCap_) = eTST.getMarketPolicy();
        assertEq(pauseBitmask_, pauseBitmask);
        assertEq(supplyCap_, supplyCap);
        assertEq(borrowCap_, borrowCap);
    }

    function test_SetMarketPolicy_SupplyCapMaxMethods(uint16 supplyCap, address userA) public {
        uint256 supplyCapAmount = AmountCap.wrap(supplyCap).toAmount();
        vm.assume(supplyCapAmount <= MAX_SANE_AMOUNT);

        eTST.setMarketPolicy(0, supplyCap, 0);

        assertEq(eTST.maxDeposit(userA), supplyCapAmount);
        assertEq(eTST.maxMint(userA), supplyCapAmount);
    }

    function test_SetMarketPolicy_RevertsWhen_AmountTooLarge(
        uint32 pauseBitmask, 
        uint16 supplyCap, 
        uint16 borrowCap
    ) public {
        vm.assume(
            AmountCap.wrap(supplyCap).toAmount() > MAX_SANE_AMOUNT || 
            AmountCap.wrap(borrowCap).toAmount() > MAX_SANE_AMOUNT
        );

        vm.expectRevert(Errors.RM_InvalidAmountCap.selector);
        eTST.setMarketPolicy(pauseBitmask, supplyCap, borrowCap);
    }

    function test_SetMarketPolicy_AccessControl(address caller) public {
        vm.assume(caller != eTST.getGovernorAdmin());
        vm.expectRevert(Errors.RM_Unauthorized.selector);
        vm.prank(caller);
        eTST.setMarketPolicy(0, 0, 0);
    }

    function test_SupplyCap_UnlimitedByDefault() public {
        (, uint16 supplyCap,) = eTST.getMarketPolicy();
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

    function test_SupplyCap_AllowDepositUnder(uint16 supplyCap, uint256 initAmount, uint256 amount) public {
        uint256 remaining = setUpUnderSupplyCap(supplyCap, initAmount);
        amount = bound(amount, 1, remaining);

        vm.prank(user);
        eTST.deposit(amount, user);
    }

    function test_SupplyCap_BlockDepositOver(uint16 supplyCap, uint256 initAmount, uint256 amount) public {
        uint256 remaining = setUpUnderSupplyCap(supplyCap, initAmount);
        amount = bound(amount, remaining + 1, MAX_SANE_AMOUNT);

        vm.expectRevert();
        vm.prank(user);
        eTST.deposit(amount, user);
    }

    function test_SupplyCap_AllowMintUnder(uint16 supplyCap, uint256 initAmount, uint256 amount) public {
        uint256 remaining = setUpUnderSupplyCap(supplyCap, initAmount);
        amount = bound(amount, 1, remaining);

        vm.prank(user);
        eTST.mint(amount, user);
    }

    function test_SupplyCap_BlockMintOver(uint16 supplyCap, uint256 initAmount, uint256 amount) public {
        uint256 remaining = setUpUnderSupplyCap(supplyCap, initAmount);
        amount = bound(amount, remaining + 1, MAX_SANE_AMOUNT);

        vm.expectRevert();
        vm.prank(user);
        eTST.mint(amount, user);
    }

    function test_SupplyCap_AllowWindUnder(uint16 supplyCap, uint256 initAmount, uint256 amount) public {
        setUpBorrow();
        uint256 remaining = setUpUnderSupplyCap(supplyCap, initAmount);
        amount = bound(amount, 1, remaining);

        vm.prank(user);
        eTST.wind(amount, user);
    }

    function test_SupplyCap_BlockWindOver(uint16 supplyCap, uint256 initAmount, uint256 amount) public {
        setUpBorrow();
        uint256 remaining = setUpUnderSupplyCap(supplyCap, initAmount);
        amount = bound(amount, remaining + 1, MAX_SANE_AMOUNT);

        vm.expectRevert();
        vm.prank(user);
        eTST.wind(amount, user);
    }

    function test_SupplyCap_AllowWithdraw(uint16 supplyCap, uint256 amount) public {
        uint256 supplyCapAmount = setUpAtSupplyCap(supplyCap);
        amount = bound(amount, 1, supplyCapAmount);

        vm.prank(user);
        eTST.withdraw(amount, user, user);
    }

    function test_SupplyCap_AllowWithdraw_OverCap(uint16 supplyCapOrig, uint16 supplyCapNow, uint256 amount) public {
        uint256 supplyCapNowAmount = setUpOverSupplyCap(supplyCapOrig, supplyCapNow);
        amount = bound(amount, 1, supplyCapNowAmount);

        vm.prank(user);
        eTST.withdraw(amount, user, user);
    }

    function setUpUnderSupplyCap(uint16 supplyCap, uint256 initAmount) internal returns (uint256) {
        uint256 supplyCapAmount = AmountCap.wrap(supplyCap).toAmount();
        vm.assume(supplyCapAmount != 0 && supplyCapAmount < MAX_SANE_AMOUNT);
        eTST.setMarketPolicy(0, supplyCap, 0);

        uint256 initAmount = bound(initAmount, 0, supplyCapAmount - 1);

        vm.prank(user);
        eTST.deposit(initAmount, user);

        return supplyCapAmount - initAmount;
    }

    function setUpAtSupplyCap(uint16 supplyCap) internal returns (uint256) {
        uint256 supplyCapAmount = AmountCap.wrap(supplyCap).toAmount();
        vm.assume(supplyCapAmount != 0 && supplyCapAmount <= MAX_SANE_AMOUNT);

        eTST.setMarketPolicy(0, supplyCap, 0);
        vm.prank(user);
        eTST.deposit(supplyCapAmount, user);
        return supplyCapAmount;
    }

    function setUpOverSupplyCap(uint16 supplyCapOrig, uint16 supplyCapNow) internal returns (uint256) {
        uint256 supplyCapOrigAmount = AmountCap.wrap(supplyCapOrig).toAmount();
        uint256 supplyCapNowAmount = AmountCap.wrap(supplyCapNow).toAmount();
        vm.assume(supplyCapOrigAmount > 1 && supplyCapOrigAmount <= MAX_SANE_AMOUNT);
        vm.assume(supplyCapNowAmount != 0 && supplyCapNowAmount < supplyCapOrigAmount);

        eTST.setMarketPolicy(0, supplyCapOrig, 0);
        vm.prank(user);
        eTST.deposit(supplyCapOrigAmount, user);
        eTST.setMarketPolicy(0, supplyCapNow, 0);
        return supplyCapNowAmount;
    }

    function setUpBorrow() internal {
        eTST.setLTV(address(eTST2), uint16(CONFIG_SCALE), 0);

        vm.startPrank(user);
        assetTST2.mint(user, type(uint256).max);
        assetTST2.approve(address(eTST2), type(uint256).max);
        eTST2.deposit(MAX_SANE_AMOUNT, user);

        evc.enableController(user, address(eTST));
        evc.enableCollateral(user, address(eTST2));

        oracle.setPrice(address(assetTST), unitOfAccount, 1 ether);
        oracle.setPrice(address(eTST2), unitOfAccount, 1 ether);
        vm.stopPrank();
    }
}
