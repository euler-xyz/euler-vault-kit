// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;
import "../../../src/interfaces/IPriceOracle.sol";
// import {ERC20} from "../../../lib/ethereum-vault-connector/lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../../../certora/harness/AbstractBaseHarness.sol";
import "../../../src/EVault/modules/RiskManager.sol";
import "../../../src/EVault/modules/Borrowing.sol";

// To prove the Health Status rule we need to include the RiskManager module
// which implemeants the status check
contract BorrowingHSHarness is BorrowingModule, RiskManagerModule, 
    AbstractBaseHarness {
    constructor(Integrations memory integrations) Base(integrations) {}

    // This mirrors LiquidityUtils.checkLiquidity except that it returns
    // a bool rather than reverting.
    // Try importing LiquidityUtils into BaseHarness or AbstractBaseHarness
    // and moving this function there.
    // function checkLiquidityReturning(address account, address[] memory collaterals) public returns (bool) {
    //     VaultCache memory vaultCache = loadVault();
    //     
    //     Owed owed = vaultStorage.users[account].getOwed();
    //     if (owed.isZero()) return true;

    //     uint256 liabilityValue = getLiabilityValue(vaultCache, account, owed, false);

    //     uint256 collateralValue;
    //     for (uint256 i; i < collaterals.length; ++i) {
    //         collateralValue += getCollateralValue(vaultCache, account, collaterals[i], false);
    //         if (collateralValue > liabilityValue) return true;
    //     }

    //     return false;
    // }
}