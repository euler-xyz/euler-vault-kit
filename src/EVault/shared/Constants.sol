// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

// TODO merge with IRM updates
uint256 constant SECONDS_PER_YEAR = 365.2425 * 86400; // Gregorian calendar
uint256 constant MAX_ALLOWED_INTEREST_RATE = 291867236321699131285; // 1,000,000% APY: ln(1 + (1000000 / 100)) * 1e27 / (365.2425 * 86400)

// Implementation internals

// asset amounts are shifted left by this number of bits for increased precision of debt tracking.
uint256 constant INTERNAL_DEBT_PRECISION = 31;
// max amount for Assets and Shares custom types based on a uint112.
uint256 constant MAX_SANE_AMOUNT = type(uint112).max; 
// max debt amount fits in uint144 (112 + 31 bits). Last 31 bits are zeros to enusure max debt rounded up equals max sane amount.
uint256 constant MAX_SANE_DEBT_AMOUNT = uint256(MAX_SANE_AMOUNT) << INTERNAL_DEBT_PRECISION;
// proxy trailing calldata length in bytes. Three addresses, 20 bytes each: vault underlying asset, oracle and unit of account.
uint256 constant PROXY_METADATA_LENGTH = 60;

// Account status checks special values

// no account status checks should be scheduled
address constant ACCOUNTCHECK_NONE = address(0);
// account status check should be scheduled for the authenticated account
address constant ACCOUNTCHECK_CALLER = address(1); 

// Operations

uint32 constant OP_DEPOSIT = 1 << 0;
uint32 constant OP_MINT = 1 << 1;
uint32 constant OP_WITHDRAW = 1 << 2;
uint32 constant OP_REDEEM = 1 << 3;
uint32 constant OP_TRANSFER = 1 << 4;
uint32 constant OP_SKIM = 1 << 5;
uint32 constant OP_BORROW = 1 << 6;
uint32 constant OP_REPAY = 1 << 7;
uint32 constant OP_LOOP = 1 << 8;
uint32 constant OP_DELOOP = 1 << 9;
uint32 constant OP_PULL_DEBT = 1 << 10;
uint32 constant OP_CONVERT_FEES = 1 << 11;
uint32 constant OP_LIQUIDATE = 1 << 12;
uint32 constant OP_FLASHLOAN = 1 << 13;
uint32 constant OP_TOUCH = 1 << 14;
uint32 constant OP_ACCRUE_INTEREST = 1 << 15;
uint32 constant OP_SOCIALIZE_DEBT = 1 << 16;
uint32 constant OP_VALIDATE_ASSET_RECEIVER = 1 << 17;
