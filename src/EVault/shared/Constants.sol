// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IVault as IEVCVault} from "ethereum-vault-connector/interfaces/IVault.sol";

// Protocol parameters

uint256 constant MAX_PROTOCOL_FEE_SHARE = 0.5 * 1e18;
uint256 constant INITIAL_INTEREST_ACCUMULATOR = 1e27;
uint256 constant SECONDS_PER_YEAR = 365.2425 * 86400; // Gregorian calendar
uint256 constant MAX_ALLOWED_INTEREST_RATE = uint256(5 * 1e27) / SECONDS_PER_YEAR; // 500% APR

// Implementation internals

uint256 constant INTERNAL_DEBT_PRECISION = 31;
uint256 constant MAX_SANE_AMOUNT = type(uint112).max;
// Max debt amount fits in uint144 (112 + 31 bits). Last 31 bits are zeros to enusure max debt rounded up equals max sane amount.
uint256 constant MAX_SANE_DEBT_AMOUNT = uint256(MAX_SANE_AMOUNT) << INTERNAL_DEBT_PRECISION;

uint256 constant PROXY_METADATA_LENGTH = 60; // 3 addresses: asset, oracle, unit of account

address constant ACCOUNTCHECK_NONE = address(0);
address constant ACCOUNTCHECK_CALLER = address(1);

bytes4 constant ACCOUNT_STATUS_CHECK_RETURN_VALUE = IEVCVault.checkAccountStatus.selector;
bytes4 constant VAULT_STATUS_CHECK_RETURN_VALUE = IEVCVault.checkVaultStatus.selector;

uint256 constant VIRTUAL_DEPOSIT_AMOUNT = 1e6;
uint256 constant CONFIG_SCALE = 60_000; // used to scale values in ConfigAmount, must fit into a uint16

// Config

uint16 constant DEFAULT_INTEREST_FEE = uint16(CONFIG_SCALE * 23 / 100); // 23%
// Maximum liquidation discount that can be awarded under any conditions.
uint256 constant MAXIMUM_LIQUIDATION_DISCOUNT = 0.2 * 1e18;

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
uint32 constant OP_VALIDATE_ASSET_RECEIVER = 1 << 15;
