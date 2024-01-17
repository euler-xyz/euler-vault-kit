// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "./types/Types.sol";

abstract contract Storage {
    bool initialized;
    address factory;

    MarketStorage marketStorage;

    struct UserAsset {
        // Packed slot 14 + 18 = 32
        Shares balance;
        Owed owed;

        uint256 interestAccumulator;
    }

    struct MarketSnapshot {
        // Packed slot 14 + 14 + 4 = 32
        Assets poolSize;
        Assets totalBorrows;
        uint32 performedOperations;
    }

    struct MarketStorage {
        // Packed slot 1 + 5 + 14 + 12 = 32
        uint8 reentrancyLock;
        uint40 lastInterestAccumulatorUpdate;
        Assets poolSize;
        Fees feesBalance;

        // Packed slot 14 + 18 = 32
        Shares totalBalances;
        Owed totalBorrows;

        uint256 interestAccumulator;

        MarketSnapshot marketSnapshot;

        // Packed slot 12 + 2
        // Read on first item in a block (interest accrual). Read and written to in vault status check (interest rate update).
        // Not touched on other batch items.
        int96 interestRate;
        uint16 interestFee;

        address protocolFeesHolder;

        mapping(address account => UserAsset) users;
        mapping(address owner => mapping(address spender => uint256 allowance)) eVaultAllowance;
    }
}
