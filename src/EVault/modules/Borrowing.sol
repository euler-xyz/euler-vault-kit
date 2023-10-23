// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IBorrowing} from "../IEVault.sol";
import {Base} from "../shared/Base.sol";
import {BorrowUtils} from "../shared/BorrowUtils.sol";

import "../shared/types/Types.sol";

abstract contract BorrowingModule is IBorrowing, Base, BorrowUtils {
    using TypesLib for uint;

    /// @inheritdoc IBorrowing
    function totalBorrows() external view virtual returns (uint) {
        MarketCache memory marketCache = loadMarketNonReentrant();

        return marketCache.totalBorrows.toUintAssetsDown();
    }

    /// @inheritdoc IBorrowing
    function totalBorrowsExact() external view virtual returns (uint) {
        return loadMarketNonReentrant().totalBorrows.toUint();
    }

    /// @inheritdoc IBorrowing
    function debtOf(address account) external view virtual returns (uint) {
        MarketCache memory marketCache = loadMarketNonReentrant();

        return getCurrentOwed(marketCache, account).toUintAssetsUp();
    }

    /// @inheritdoc IBorrowing
    function checkVaultStatus() external virtual reentrantOK returns (bool, bytes memory) {
        if (msg.sender != address(cvc)) return (false, "e/invalid-caller");
        return (true, "");
    }
}

contract Borrowing is BorrowingModule {
    constructor(address factory, address cvc) Base(factory, cvc) {}
}