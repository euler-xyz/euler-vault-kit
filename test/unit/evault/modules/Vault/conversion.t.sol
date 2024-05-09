// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "../../EVaultTestBase.t.sol";
import {EVault} from "src/EVault/EVault.sol";

import "src/EVault/shared/types/Types.sol";

contract EVaultHarness is EVault {
    using TypesLib for uint256;

    constructor(Integrations memory integrations, DeployedModules memory modules) EVault(integrations, modules) {}

    function setCash_(uint256 value) public {
        vaultStorage.cash = Assets.wrap(uint112(value));
    }

    function setTotalBorrow_(uint256 value) public {
        vaultStorage.totalBorrows = Owed.wrap(uint144(value));
    }

    function setTotalShares_(uint256 value) public {
        vaultStorage.totalShares = Shares.wrap(uint112(value));
    }
}

contract VaultTest_Conversion is EVaultTestBase {
    address user1;

    EVaultHarness public eTST0;

    function setUp() public override {
        super.setUp();

        user1 = makeAddr("user1");

        address evaultImpl = address(new EVaultHarness(integrations, modules));
        vm.prank(admin);
        factory.setImplementation(evaultImpl);

        eTST0 = EVaultHarness(coreProductLine.createVault(address(assetTST), address(oracle), unitOfAccount));
        eTST0.setInterestRateModel(address(new IRMTestDefault()));
    }

    function test_maxDeposit_checkFreeTotalShares() public {
        assertEq(eTST0.cash(), 0);
        assertEq(eTST0.totalSupply(), 0);

        uint256 maxAssets = eTST0.maxDeposit(user1);
        assertEq(maxAssets, MAX_SANE_AMOUNT);

        eTST0.setCash_(1e18);
        eTST0.setTotalShares_(MAX_SANE_AMOUNT - 1000e18);

        assertEq(eTST0.cash(), 1e18);
        assertEq(eTST0.totalSupply(), MAX_SANE_AMOUNT - 1000e18);

        uint256 remainingCash = MAX_SANE_AMOUNT - eTST0.cash();
        vm.expectRevert(Errors.E_AmountTooLargeToEncode.selector);
        eTST0.convertToShares(remainingCash);

        uint256 remainingShares = MAX_SANE_AMOUNT - eTST0.totalSupply();
        maxAssets = eTST0.maxDeposit(user1);
        assertEq(maxAssets, eTST0.convertToAssets(remainingShares));

        startHoax(user1);
        assetTST.mint(user1, maxAssets);
        assetTST.approve(address(eTST0), type(uint256).max);
        eTST0.deposit(maxAssets, user1);
        assertEq(assetTST.balanceOf(user1), 0);

        maxAssets = eTST0.maxDeposit(user1);
        assertEq(maxAssets, 0);
        assertGt(eTST0.convertToShares(1), MAX_SANE_AMOUNT - eTST0.totalSupply());

        assetTST.mint(user1, 1);
        vm.expectRevert(Errors.E_AmountTooLargeToEncode.selector);
        eTST0.deposit(1, user1);
    }

    function test_maxMint_checkFreeTotalShares() public {
        assertEq(eTST0.cash(), 0);
        assertEq(eTST0.totalSupply(), 0);

        uint256 maxShares = eTST0.maxMint(user1);
        assertEq(maxShares, MAX_SANE_AMOUNT);

        eTST0.setCash_(1e18);
        eTST0.setTotalShares_(MAX_SANE_AMOUNT - 1000e18);

        assertEq(eTST0.cash(), 1e18);
        assertEq(eTST0.totalSupply(), MAX_SANE_AMOUNT - 1000e18);

        uint256 remainingCash = MAX_SANE_AMOUNT - eTST0.cash();
        vm.expectRevert(Errors.E_AmountTooLargeToEncode.selector);
        eTST0.convertToShares(remainingCash);

        uint256 remainingShares = MAX_SANE_AMOUNT - eTST0.totalSupply();
        maxShares = eTST0.maxMint(user1);
        assertEq(maxShares, remainingShares);

        startHoax(user1);
        assetTST.mint(user1, maxShares);
        assetTST.approve(address(eTST0), type(uint256).max);
        eTST0.mint(maxShares, user1);
        assertEq(eTST0.balanceOf(user1), maxShares);

        maxShares = eTST0.maxMint(user1);
        assertEq(maxShares, 0);
        assertGt(eTST0.totalSupply(), 0);

        assetTST.mint(user1, 1);
        vm.expectRevert(Errors.E_AmountTooLargeToEncode.selector);
        eTST0.mint(1, user1);
    }
}
