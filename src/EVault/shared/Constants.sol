// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IVault} from "ethereum-vault-connector/interfaces/IVault.sol";

// Protocol parameters

uint256 constant MAX_SANE_AMOUNT = type(uint112).max;
uint256 constant MAX_SANE_DEBT_AMOUNT = type(uint144).max ^ type(uint32).max;
uint256 constant MAX_SANE_SMALL_AMOUNT = type(uint96).max;
uint256 constant INTERNAL_DEBT_PRECISION = 32; // internally debt amount is tracked by shifting asset amount left 32 bits
uint256 constant MIN_REPRESENTABLE_INTERNAL_DEBT_AMOUNT = 1 << INTERNAL_DEBT_PRECISION;
uint256 constant INTEREST_FEE_SCALE = 60_000; // must fit into a uint16

uint256 constant PROTOCOL_FEE_SHARE = 0.1 * 1e18;
uint256 constant MIN_INTEREST_FEE = 0.01 * 60_000; // TODO

uint256 constant INITIAL_INTEREST_ACCUMULATOR = 1e27;

uint256 constant SECONDS_PER_YEAR = 365.2425 * 86400; // Gregorian calendar
int96 constant MIN_ALLOWED_INTEREST_RATE = 0;
int96 constant MAX_ALLOWED_INTEREST_RATE = int96(int256(uint256(5 * 1e27) / SECONDS_PER_YEAR)); // 500% APR

// Implementation internals

uint8 constant REENTRANCYLOCK__UNLOCKED = 1;
uint8 constant REENTRANCYLOCK__LOCKED = 2;

uint256 constant PROXY_METADATA_LENGTH = 40; // to optimize gas cost, `useView` modifier assumes 40 bytes without referencing the constant.

address constant ACCOUNT_CHECK_NONE = address(0);
address constant ACCOUNT_CHECK_CALLER = address(1);

bytes4 constant ACCOUNT_STATUS_CHECK_RETURN_VALUE = IVault.checkAccountStatus.selector;
bytes4 constant VAULT_STATUS_CHECK_RETURN_VALUE = IVault.checkVaultStatus.selector;

// Operations

uint32 constant OP_DEPOSIT = 1 << 0;
uint32 constant OP_MINT = 1 << 1;
uint32 constant OP_WITHDRAW = 1 << 2;
uint32 constant OP_REDEEM = 1 << 3;
uint32 constant OP_TRANSFER = 1 << 4;
uint32 constant OP_BORROW = 1 << 5;
uint32 constant OP_REPAY = 1 << 6;
uint32 constant OP_WIND = 1 << 7;
uint32 constant OP_UNWIND = 1 << 8;
uint32 constant OP_PULL_DEBT = 1 << 9;
uint32 constant OP_CONVERT_FEES = 1 << 10;
uint32 constant OP_LIQUIDATE = 1 << 11;
uint32 constant OP_TOUCH = 1 << 12;
