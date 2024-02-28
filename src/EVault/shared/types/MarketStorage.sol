// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "./Types.sol";

struct MarketStorage {
    // Packed slot 5 + 14 + 2 + 2 + 4 + 1 = 28
    uint40 lastInterestAccumulatorUpdate;
    Assets poolSize;
    AmountCap supplyCap;
    AmountCap borrowCap;
    DisabledOps disabledOps;
    bool reentrancyLock;
    bool snapshotInitialized;
    bool debtSocialization;

    // Packed slot 14 + 18 = 32
    Shares totalShares;
    Owed totalBorrows;

    // review: let's put it in the same storage slot as i.e. the admin or feeReceiver?
    Shares feesBalance;

    uint256 interestAccumulator;

    // Packed slot 20 + 2 + 9 = 31
    address interestRateModel; // 0% interest, if zero address
    uint16 interestFee;
    uint72 interestRate;

    string name;
    string symbol;

    address governorAdmin;
    address feeReceiver;

    mapping(address account => UserStorage) users;

    // review: maybe it would be better to move the allowance to the UserStorage? OTOH, it would probably be more expensive gas-wise
    mapping(address owner => mapping(address spender => uint256 allowance)) eVaultAllowance;
}
