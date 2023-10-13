// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

// Protocol parameters

// Must fit into uin112 and account for 1 virtual asset or share. See https://docs.openzeppelin.com/contracts/4.x/erc4626#inflation-attack
uint constant MAX_SANE_AMOUNT = type(uint112).max - 1; 
uint constant MAX_SANE_DEBT_AMOUNT = type(uint144).max;
uint constant MAX_SANE_SMALL_AMOUNT = type(uint96).max;
uint constant INTERNAL_DEBT_PRECISION = 1e9;
uint constant INTEREST_FEE_SCALE = 60_000; // must fit into a uint16

uint constant PROTOCOL_FEE_SHARE = 0.2 * 1e18;

uint constant INITIAL_INTEREST_ACCUMULATOR = 1e27;


// Implementation internals

uint8 constant REENTRANCYLOCK__UNLOCKED = 1;
uint8 constant REENTRANCYLOCK__LOCKED = 2;


// Pause bitmask

uint8 constant PAUSETYPE__NONE     = 1 << 0;
uint8 constant PAUSETYPE__DEPOSIT  = 1 << 1;
uint8 constant PAUSETYPE__WITHDRAW = 1 << 2;
uint8 constant PAUSETYPE__BORROW   = 1 << 3;
uint8 constant PAUSETYPE__REPAY    = 1 << 4;
uint8 constant PAUSETYPE__WIND     = 1 << 5;
uint8 constant PAUSETYPE__UNWIND   = 1 << 6;

