// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "./Types.sol";

struct MarketStorage {
    // Packed slot 4 + 5 + 14 + 2 + 2 = 27
    BitField bitField;
    uint40 lastInterestAccumulatorUpdate;
    Assets poolSize;
    AmountCap supplyCap;
    AmountCap borrowCap;

    // Packed slot 14 + 18 = 32
    Shares totalShares;
    Owed totalBorrows;

    // Packed slot 12 + 20 = 32
    Fees feesBalance;
    address oracle;

    uint256 interestAccumulator;
    
    address unitOfAccount;

    // Packed slot 20 + 2 + 9 = 31
    address interestRateModel; // 0% interest, if zero address
    uint16 interestFee;
    uint72 interestRate;

    string name;
    string symbol;

    address governorAdmin;
    address feeReceiver;

    mapping(address account => UserStorage) users;
    mapping(address owner => mapping(address spender => uint256 allowance)) eVaultAllowance;
}
