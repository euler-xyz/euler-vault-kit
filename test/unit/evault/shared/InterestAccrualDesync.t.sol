// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.13;

import {EVaultTestBase} from "test/unit/evault/EVaultTestBase.t.sol";
import {IRMMax} from "test/mocks/IRMMax.sol";
import "src/EVault/shared/Constants.sol";

/// @dev Reproducer for a non-atomic interest accrual path in `Cache.initVaultCache()`:
/// `interestAccumulator` can update while `totalBorrows` stays stale if the 256-bit intermediate multiplication
/// `newTotalBorrows * newInterestAccumulator` overflows. This breaks invariants and affects share pricing and caps.
///
/// NOTE: These tests are expected to FAIL on current master to demonstrate the issue.
contract VaultTest_InterestAccrualDesync_Invariants is EVaultTestBase {
    uint256 internal constant VIRTUAL_DEPOSIT_AMOUNT = 1e6;

    address depositor;
    address borrower;
    address attacker;

    function _encodeAmountCap(uint256 cap) internal pure returns (uint16 raw) {
        // AmountCap is a 16-bit decimal floating point:
        // exponent = low 6 bits, mantissa = high 10 bits, scaled by 100.
        // resolve(raw) = 10**exp * mantissa / 100
        if (cap == type(uint256).max) return 0;
        require(cap > 0, "cap=0 unsupported; use raw=0 for unlimited");

        for (uint256 exp = 0; exp <= 63; ++exp) {
            uint256 denom = 10 ** exp;
            uint256 mantissa = (cap * 100 + denom - 1) / denom; // ceil
            if (mantissa == 0) continue;
            if (mantissa <= 1023) {
                raw = uint16((mantissa << 6) | exp);
                return raw;
            }
        }

        revert("cap too large to encode");
    }

    function setUp() public override {
        super.setUp();

        depositor = makeAddr("depositor");
        borrower = makeAddr("borrower");
        attacker = makeAddr("attacker");

        oracle.setPrice(address(assetTST), unitOfAccount, 1e18);
        oracle.setPrice(address(eTST2), unitOfAccount, 2e18);

        startHoax(address(this));
        eTST.setLTV(address(eTST2), 0.9e4, 0.9e4, 0);
        eTST.setInterestRateModel(address(new IRMMax()));

        // Large, but within MAX_SANE_AMOUNT.
        uint256 seedCash = 2e30;
        uint256 seedCollateral = 3e30;

        startHoax(depositor);
        assetTST.mint(depositor, seedCash);
        assetTST.approve(address(eTST), type(uint256).max);
        eTST.deposit(seedCash, depositor);

        startHoax(borrower);
        assetTST2.mint(borrower, seedCollateral);
        assetTST2.approve(address(eTST2), type(uint256).max);
        eTST2.deposit(seedCollateral, borrower);
        evc.enableCollateral(borrower, address(eTST2));
        evc.enableController(borrower, address(eTST));

        // Chosen to keep debt encodable for a few years at MAX interest while allowing
        // `totalBorrows * interestAccumulator` to approach 2^256.
        eTST.borrow(1e25, borrower);

        // Prime interestRate to MAX in storage.
        eTST.touch();
    }

    function _reachMismatchState() internal {
        for (uint256 yearCount = 1; yearCount <= 6; ++yearCount) {
            skip(SECONDS_PER_YEAR);
            eTST.touch();

            // 1-second accrual step where the intermediate multiplication is most likely to overflow
            // (large `totalBorrows` and `interestAccumulator`, but multiplier close to 1e27).
            skip(1);
            eTST.touch();

            if (eTST.debtOfExact(borrower) > eTST.totalBorrowsExact()) return;
        }

        revert("did not reach mismatch state within 6 years");
    }

    function test_invariant_totalBorrowsExact_should_not_lag_debtOfExact() public {
        _reachMismatchState();

        // Expected invariant: global total borrows should be >= any single account's exact debt.
        // Demonstration: currently violated once the mismatch state is reached.
        assertGe(eTST.totalBorrowsExact(), eTST.debtOfExact(borrower));
    }

    function test_invariant_deposit_should_not_mint_more_than_honest_totalDebt() public {
        _reachMismatchState();

        uint256 reportedBorrows = eTST.totalBorrows();
        uint256 trueDebt = eTST.debtOf(borrower);
        uint256 cash = eTST.cash();
        uint256 totalShares = eTST.totalSupply();

        assertGt(trueDebt, reportedBorrows);

        uint256 depositAssets = 1e24;
        uint256 conversionShares = totalShares + VIRTUAL_DEPOSIT_AMOUNT;
        uint256 expectedSharesIfHonest =
            depositAssets * conversionShares / (cash + trueDebt + VIRTUAL_DEPOSIT_AMOUNT);

        startHoax(attacker);
        assetTST.mint(attacker, depositAssets);
        assetTST.approve(address(eTST), type(uint256).max);
        uint256 mintedShares = eTST.deposit(depositAssets, attacker);

        // Expected invariant: deposit minting should not be more generous than using honest total debt.
        assertLe(mintedShares, expectedSharesIfHonest);
    }

    function test_invariant_borrowCap_should_prevent_borrow_at_cap() public {
        _reachMismatchState();

        uint256 reportedBorrows = eTST.totalBorrows();
        uint256 honestBorrowsVictim = eTST.debtOf(borrower);
        assertGt(honestBorrowsVictim, reportedBorrows);

        uint256 capAssets = honestBorrowsVictim;
        uint256 gap = honestBorrowsVictim - reportedBorrows;

        startHoax(address(this));
        eTST.setCaps(0, _encodeAmountCap(capAssets));

        address attackerBorrower = makeAddr("attackerBorrower");
        startHoax(attackerBorrower);
        assetTST2.mint(attackerBorrower, 3e30);
        assetTST2.approve(address(eTST2), type(uint256).max);
        eTST2.deposit(3e30, attackerBorrower);
        evc.enableCollateral(attackerBorrower, address(eTST2));
        evc.enableController(attackerBorrower, address(eTST));

        uint256 cashBefore = eTST.cash();
        eTST.borrow(gap, attackerBorrower);
        uint256 cashAfter = eTST.cash();

        // Expected invariant: borrowing exactly at the cap should be blocked (no cash should leave the vault).
        assertEq(cashAfter, cashBefore);
    }
}

