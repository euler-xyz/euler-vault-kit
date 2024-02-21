// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "./types/Types.sol";

abstract contract Storage {
    bool initialized;

    address internal governorAdminAddress;
    address internal feeReceiverAddress;

    MarketStorage marketStorage;
    MarketConfig marketConfig;

    mapping(address collateral => LTVConfig) internal ltvLookup;
    address[] internal ltvList;


    struct UserStorage {
        PackedUserSlot data;

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
        Shares totalShares;
        Owed totalBorrows;

        uint256 interestAccumulator;

        MarketSnapshot marketSnapshot;

        // Read in the first batch item in a block. Written to during health checks.
        uint72 interestRate;

        mapping(address account => UserStorage) users;
        mapping(address owner => mapping(address spender => uint256 allowance)) eVaultAllowance;
    }

    struct MarketConfig {
        // Packed slot 4 + 2 + 2 + 2 + 20 + 1 = 31
        uint32 pauseBitmask;
        AmountCap supplyCap;
        AmountCap borrowCap;
        address oracle;
        bool debtSocialization;

        // Packed slot 20 + 2 = 22
        address interestRateModel; // 0% interest, if zero address
        uint16 interestFee;

        address unitOfAccount;

        string name;
        string symbol;
    }
}
