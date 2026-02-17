// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {EVaultTestBase} from "../../EVaultTestBase.t.sol";

import "../../../../../src/EVault/IEVault.sol";
import {TestERC20} from "../../../../mocks/TestERC20.sol";
import {IRMTestZero} from "../../../../mocks/IRMTestZero.sol";

/// @notice Minimal oracle mock that reverts when no route/price is configured.
/// @dev Kept inline so the repro is copy/pasteable as a single file into a clean `euler-vault-kit` checkout.
contract RevertingPriceOracle {
    error PO_NoPath();

    struct Quote {
        bool set;
        uint256 price; // 1e18 quote units per 1 base unit (after resolving vault shares to assets)
    }

    mapping(address base => mapping(address quote => Quote)) internal quotes;

    function name() external pure returns (string memory) {
        return "RevertingPriceOracle";
    }

    function setPrice(address base, address quote, uint256 newPrice) external {
        quotes[resolveUnderlying(base)][quote] = Quote({set: true, price: newPrice});
    }

    function getQuote(uint256 amount, address base, address quote) public view returns (uint256 out) {
        Quote memory q = quotes[resolveUnderlying(base)][quote];
        if (!q.set) revert PO_NoPath();
        return calculateQuote(base, amount, q.price);
    }

    function getQuotes(uint256 amount, address base, address quote)
        external
        view
        returns (uint256 bidOut, uint256 askOut)
    {
        uint256 out = getQuote(amount, base, quote);
        return (out, out);
    }

    function calculateQuote(address base, uint256 amount, uint256 p) internal view returns (uint256) {
        // If base is a vault (implements asset()), then call convertToAssets() to price shares,
        // similar to how EulerRouter resolves ERC4626 shares.
        while (base.code.length > 0) {
            (bool success, bytes memory data) = base.staticcall(abi.encodeCall(IERC4626.asset, ()));
            if (!success) break;

            address asset = abi.decode(data, (address));
            amount = IEVault(base).convertToAssets(amount);
            base = asset;
        }

        return amount * p / 1e18;
    }

    function resolveUnderlying(address asset) internal view returns (address) {
        if (asset.code.length > 0) {
            (bool success, bytes memory data) = asset.staticcall(abi.encodeCall(IERC4626.asset, ()));
            if (success) return abi.decode(data, (address));
        }

        return asset;
    }
}

/// @dev Reproducer for a debt-socialization deadlock:
/// A recognized collateral with 0 LTV and no oracle route can keep `checkNoCollateral()` false via a dust balance,
/// blocking debt socialization after an otherwise-valid liquidation. This keeps bad debt on the books and can
/// overprice shares, creating a first-redeemer advantage.
///
/// NOTE: These tests are expected to FAIL on current master to demonstrate the issue.
contract UnpriceableZeroLTVBlocksDebtSocialization_MispricesShares_Test is EVaultTestBase {
    RevertingPriceOracle internal rOracle;

    TestERC20 internal debtAsset;
    TestERC20 internal goodAsset;
    TestERC20 internal badAsset;

    IEVault internal debtVaultBlocked;
    IEVault internal debtVaultNormal;
    IEVault internal goodCollateralVault;
    IEVault internal badCollateralVault;

    address internal attackerBlocked;
    address internal victimBlocked;
    address internal borrowerBlocked;
    address internal liquidatorBlocked;

    address internal attackerNormal;
    address internal victimNormal;
    address internal borrowerNormal;
    address internal liquidatorNormal;

    function setUp() public override {
        super.setUp();

        attackerBlocked = makeAddr("attackerBlocked");
        victimBlocked = makeAddr("victimBlocked");
        borrowerBlocked = makeAddr("borrowerBlocked");
        liquidatorBlocked = makeAddr("liquidatorBlocked");

        attackerNormal = makeAddr("attackerNormal");
        victimNormal = makeAddr("victimNormal");
        borrowerNormal = makeAddr("borrowerNormal");
        liquidatorNormal = makeAddr("liquidatorNormal");

        rOracle = new RevertingPriceOracle();

        debtAsset = new TestERC20("Debt Asset", "DEBT", 18, false);
        goodAsset = new TestERC20("Good Asset", "GOOD", 18, false);
        badAsset = new TestERC20("Bad Asset", "BAD", 18, false);

        debtVaultBlocked = IEVault(
            factory.createProxy(address(0), true, abi.encodePacked(address(debtAsset), address(rOracle), unitOfAccount))
        );
        debtVaultBlocked.setHookConfig(address(0), 0);
        debtVaultBlocked.setInterestRateModel(address(new IRMTestZero()));
        debtVaultBlocked.setMaxLiquidationDiscount(0.2e4);

        debtVaultNormal = IEVault(
            factory.createProxy(address(0), true, abi.encodePacked(address(debtAsset), address(rOracle), unitOfAccount))
        );
        debtVaultNormal.setHookConfig(address(0), 0);
        debtVaultNormal.setInterestRateModel(address(new IRMTestZero()));
        debtVaultNormal.setMaxLiquidationDiscount(0.2e4);

        goodCollateralVault = IEVault(
            factory.createProxy(address(0), true, abi.encodePacked(address(goodAsset), address(rOracle), unitOfAccount))
        );
        goodCollateralVault.setHookConfig(address(0), 0);
        goodCollateralVault.setInterestRateModel(address(new IRMTestZero()));

        badCollateralVault = IEVault(
            factory.createProxy(address(0), true, abi.encodePacked(address(badAsset), address(rOracle), unitOfAccount))
        );
        badCollateralVault.setHookConfig(address(0), 0);
        badCollateralVault.setInterestRateModel(address(new IRMTestZero()));

        debtVaultBlocked.setLTV(address(goodCollateralVault), 0.9e4, 0.9e4, 0);
        debtVaultNormal.setLTV(address(goodCollateralVault), 0.9e4, 0.9e4, 0);

        // BAD collateral is recognized but has 0 LTV, and is intentionally left unpriceable (oracle will revert).
        debtVaultBlocked.setLTV(address(badCollateralVault), 0, 0, 0);

        rOracle.setPrice(address(debtAsset), unitOfAccount, 1e18);
        rOracle.setPrice(address(goodAsset), unitOfAccount, 1e18);

        // Seed deposits (2 depositors per vault, equal size).
        _depositTo(debtVaultBlocked, attackerBlocked, 1_000e18);
        _depositTo(debtVaultBlocked, victimBlocked, 1_000e18);
        _depositTo(debtVaultNormal, attackerNormal, 1_000e18);
        _depositTo(debtVaultNormal, victimNormal, 1_000e18);

        // Borrowers: deposit GOOD collateral, enable controller, then borrow.
        _setupBorrower(debtVaultBlocked, borrowerBlocked, true);
        _setupBorrower(debtVaultNormal, borrowerNormal, false);

        // Record a successful status check (required by liquidation cool-off guard).
        evc.requireAccountStatusCheck(borrowerBlocked);
        evc.requireAccountStatusCheck(borrowerNormal);

        // Make borrowers unhealthy by crashing GOOD price.
        rOracle.setPrice(address(goodAsset), unitOfAccount, 0.01e18);

        // Liquidators: provide collateral and enable controller to absorb transferred debt during liquidation.
        _setupLiquidator(debtVaultBlocked, liquidatorBlocked);
        _setupLiquidator(debtVaultNormal, liquidatorNormal);
    }

    function test_invariant_badDebt_should_be_socialized_even_if_zeroLTV_dust_exists() public {
        startHoax(liquidatorBlocked);
        debtVaultBlocked.liquidate(borrowerBlocked, address(goodCollateralVault), type(uint256).max, 0);

        startHoax(liquidatorNormal);
        debtVaultNormal.liquidate(borrowerNormal, address(goodCollateralVault), type(uint256).max, 0);

        uint256 remainingDebtBlocked = debtVaultBlocked.debtOf(borrowerBlocked);
        uint256 remainingDebtNormal = debtVaultNormal.debtOf(borrowerNormal);

        // Expected behavior: if a borrower is left with no effective collateral, remaining bad debt should be realized
        // via socialization. A recognized 0-LTV dust balance should not permanently block this.
        assertEq(remainingDebtNormal, 0, "sanity: normal case should socialize remaining debt");
        assertEq(remainingDebtBlocked, 0, "expected blocked case to also socialize remaining debt");
    }

    function test_invariant_earlyRedeemer_should_not_be_able_to_drain_all_cash() public {
        uint256 blockedCashBefore = debtAsset.balanceOf(address(debtVaultBlocked));

        startHoax(liquidatorBlocked);
        debtVaultBlocked.liquidate(borrowerBlocked, address(goodCollateralVault), type(uint256).max, 0);

        uint256 maxRedeemBlocked = debtVaultBlocked.maxRedeem(attackerBlocked);

        startHoax(attackerBlocked);
        debtVaultBlocked.redeem(maxRedeemBlocked, attackerBlocked, attackerBlocked);

        // Expected behavior: a single redeemer should not be able to drain all remaining cash in a way that prevents
        // other LPs from withdrawing any amount.
        assertGt(debtAsset.balanceOf(address(debtVaultBlocked)), 0, "vault cash should not be fully drainable");
        assertGt(debtVaultBlocked.maxWithdraw(victimBlocked), 0, "other LP should still have withdrawable cash");
        assertLe(debtAsset.balanceOf(address(debtVaultBlocked)), blockedCashBefore, "sanity");
    }

    function _depositTo(IEVault vault, address depositor, uint256 assets) internal {
        startHoax(depositor);
        debtAsset.mint(depositor, assets);
        debtAsset.approve(address(vault), type(uint256).max);
        vault.deposit(assets, depositor);
    }

    function _setupBorrower(IEVault debtVault, address borrower, bool withBadCollateral) internal {
        startHoax(borrower);

        goodAsset.mint(borrower, 2_000e18);
        goodAsset.approve(address(goodCollateralVault), type(uint256).max);
        goodCollateralVault.deposit(2_000e18, borrower);
        evc.enableCollateral(borrower, address(goodCollateralVault));

        if (withBadCollateral) {
            badAsset.mint(borrower, 1e18);
            badAsset.approve(address(badCollateralVault), type(uint256).max);
            badCollateralVault.deposit(1e18, borrower);
            evc.enableCollateral(borrower, address(badCollateralVault));
        }

        evc.enableController(borrower, address(debtVault));
        debtVault.borrow(1_500e18, borrower);
    }

    function _setupLiquidator(IEVault debtVault, address liquidator) internal {
        startHoax(liquidator);

        goodAsset.mint(liquidator, 1_000_000e18);
        goodAsset.approve(address(goodCollateralVault), type(uint256).max);
        goodCollateralVault.deposit(500_000e18, liquidator);

        evc.enableCollateral(liquidator, address(goodCollateralVault));
        evc.enableController(liquidator, address(debtVault));
    }
}

