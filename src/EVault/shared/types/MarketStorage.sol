// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Assets, Shares, Owed, AmountCap, ConfigAmount, Flags} from "./Types.sol";
import {LTVConfig} from "./LTVConfig.sol";
import {UserStorage} from "./UserStorage.sol";

struct MarketStorage {
    // Packed slot 6 + 14 + 2 + 2 + 4 + 1 + 1 = 30
    uint48 lastInterestAccumulatorUpdate;
    Assets cash;
    AmountCap supplyCap;
    AmountCap borrowCap;
    Flags disabledOps;
    bool reentrancyLocked;
    bool snapshotInitialized;

    // Packed slot 14 + 18 = 32
    Shares totalShares;
    Owed totalBorrows;

    // Packed slot 14 + 4 = 18
    Shares accumulatedFees;
    Flags configFlags;

    uint256 interestAccumulator;

    // Packed slot 20 + 2 + 9 = 31
    address interestRateModel; // 0% interest, if zero address
    ConfigAmount interestFee;
    uint72 interestRate;

    string name;
    string symbol;

    address creator;

    address governorAdmin;
    address pauseGuardian;
    Flags lockedOps;
    address feeReceiver;

    mapping(address account => UserStorage) users;

    mapping(address collateral => LTVConfig) ltvLookup;
    address[] ltvList;
}
