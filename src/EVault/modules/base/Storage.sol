// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

abstract contract Storage {

    // ---------- singleton storage struct ----------

    MarketStorage marketStorage;

    // ----------------------------------------------

    struct UserAsset {
        uint112 balance;
        uint144 owed;

        uint interestAccumulator;
    }

    struct MarketSnapshot {
        uint8 performedOperations;
        uint112 poolSize;
        uint112 totalBalances;
        uint112 totalBorrows;
        uint144 interestAccumulator;
    }

    struct MarketStorage {
        // Packed slot 5 + 12 + 12 + 2 + 1 = 32
        uint40 lastInterestAccumulatorUpdate;
        uint96 feesBalance;
        int96 interestRate;
        uint16 interestFee;
        uint8 reentrancyLock;

        uint112 totalBalances;
        uint144 totalBorrows;

        uint interestAccumulator;

        MarketSnapshot marketSnapshot;

        mapping(address account => UserAsset) users;

        mapping(address owner => mapping(address spender => uint allowance)) eVaultAllowance;
    }
}
