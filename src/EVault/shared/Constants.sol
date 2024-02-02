// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IVault} from "ethereum-vault-connector/interfaces/IVault.sol";

// Protocol parameters

uint256 constant MAX_PROTOCOL_FEE_SHARE = 0.5 * 1e18;
uint256 constant INTEREST_FEE_SCALE = 60_000; // must fit into a uint16
uint256 constant INITIAL_INTEREST_ACCUMULATOR = 1e27;
uint256 constant SECONDS_PER_YEAR = 365.2425 * 86400; // Gregorian calendar
uint72 constant MAX_ALLOWED_INTEREST_RATE = uint72(uint256(5 * 1e27) / SECONDS_PER_YEAR); // 500% APR

// Implementation internals

uint256 constant INTERNAL_DEBT_PRECISION = 31;
uint256 constant MAX_SANE_AMOUNT = type(uint112).max;
// Max debt amount fits in uint144 (112 + 31 bits). Last 31 bits are zeros to enusure max debt rounded up equals max sane amount.
uint256 constant MAX_SANE_DEBT_AMOUNT = uint256(MAX_SANE_AMOUNT) << INTERNAL_DEBT_PRECISION;
uint256 constant MAX_SANE_SMALL_AMOUNT = type(uint96).max;

uint8 constant REENTRANCYLOCK__UNLOCKED = 1;
uint8 constant REENTRANCYLOCK__LOCKED = 2;

uint256 constant PROXY_METADATA_LENGTH = 20; // 1 address: asset

address constant ACCOUNTCHECK_NONE = address(0);
address constant ACCOUNTCHECK_CALLER = address(1);

bytes4 constant ACCOUNT_STATUS_CHECK_RETURN_VALUE = IVault.checkAccountStatus.selector;
bytes4 constant VAULT_STATUS_CHECK_RETURN_VALUE = IVault.checkVaultStatus.selector;

uint256 constant VIRTUAL_DEPOSIT_AMOUNT = 1e6;

// Config

uint256 constant CONFIG_SCALE = 60_000; // must fit into a uint16
uint16 constant DEFAULT_BORROW_FACTOR = uint16(0.28 * 60_000); // FIXME: kill this
uint16 constant DEFAULT_INTEREST_FEE = uint16(0.23 * 60_000);
// Maximum liquidation discount that can be awarded under any conditions.
uint256 constant MAXIMUM_LIQUIDATION_DISCOUNT = 0.2 * 1e18; // FIXME: move to liq module, make accessor (ie, public)

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
