// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IBorrowing} from "../IEVault.sol";
import {Base} from "../shared/Base.sol";
import {BorrowUtils} from "../shared/BorrowUtils.sol";

import "../shared/types/Types.sol";

abstract contract BorrowingModule is IBorrowing, Base, BorrowUtils {
    using TypesLib for uint256;

    /// @inheritdoc IBorrowing
    function totalBorrows() external view virtual nonReentrantView returns (uint256) {
        MarketCache memory marketCache = loadMarket();

        return marketCache.totalBorrows.toUintAssetsDown();
    }

    /// @inheritdoc IBorrowing
    function totalBorrowsExact() external view virtual nonReentrantView returns (uint256) {
        return loadMarket().totalBorrows.toUint();
    }

    /// @inheritdoc IBorrowing
    function debtOf(address account) external view virtual nonReentrantView returns (uint256) {
        MarketCache memory marketCache = loadMarket();

        return getCurrentOwed(marketCache, account).toUintAssetsUp();
    }

    /// @inheritdoc IBorrowing
    function disableController() external virtual nonReentrant {
        // TODO disableController()
    }

    /// @inheritdoc IBorrowing
    function checkAccountStatus(address account, address[] calldata collaterals)
        public
        virtual
        reentrantOK
        onlyEVCChecks
        returns (bytes4 magicValue)
    {
        // TODO checkAccountStatus()
        magicValue = ACCOUNT_STATUS_CHECK_RETURN_VALUE;
    }

    /// @inheritdoc IBorrowing
    function checkVaultStatus() public virtual reentrantOK onlyEVCChecks returns (bytes4 magicValue) {
        // TODO checkVaultStatus()
        magicValue = VAULT_STATUS_CHECK_RETURN_VALUE;
    }
}

contract Borrowing is BorrowingModule {
    constructor(address evc) Base(evc) {}
}
