// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "./types/Types.sol";

abstract contract Storage {

    // ---------- singleton storage struct ----------

    MarketStorage marketStorage;

    // ----------------------------------------------

    struct UserAsset {
        Shares balance;
        Owed owed;

        uint interestAccumulator;
    }

    struct MarketSnapshot {
        uint8 performedOperations;
        Assets poolSize;
        Assets totalBalances;
        Assets totalBorrows;
        uint144 interestAccumulator;
    }

    struct MarketStorage {
        // Packed slot 5 + 12 + 12 + 2 + 1 = 32
        uint40 lastInterestAccumulatorUpdate;
        Fees feesBalance;
        int96 interestRate;
        uint16 interestFee;
        uint8 reentrancyLock;

        Shares totalBalances;
        Owed totalBorrows;

        uint interestAccumulator;

        MarketSnapshot marketSnapshot;

        mapping(address account => UserAsset) users;

        mapping(address owner => mapping(address spender => uint allowance)) eVaultAllowance;
    }
}
