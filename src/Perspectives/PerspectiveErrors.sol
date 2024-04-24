// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

abstract contract PerspectiveErrors {
    error PerspectiveError(address perspective, address vault, uint256 codes);

    uint256 internal constant ERROR__NOT_FROM_FACTORY = 1 << 0;
    uint256 internal constant ERROR__TRAILING_DATA = 1 << 1;
    uint256 internal constant ERROR__UPGRADABILITY = 1 << 2;
    uint256 internal constant ERROR__NOT_SINGLETON = 1 << 3;
    uint256 internal constant ERROR__NESTING = 1 << 4;
    uint256 internal constant ERROR__ORACLE = 1 << 5;
    uint256 internal constant ERROR__UNIT_OF_ACCOUNT = 1 << 6;
    uint256 internal constant ERROR__CREATOR = 1 << 7;
    uint256 internal constant ERROR__GOVERNOR = 1 << 8;
    uint256 internal constant ERROR__FEE_RECEIVER = 1 << 9;
    uint256 internal constant ERROR__INTEREST_RATE_MODEL = 1 << 10;
    uint256 internal constant ERROR__SUPPLY_CAP = 1 << 11;
    uint256 internal constant ERROR__BORROW_CAP = 1 << 12;
    uint256 internal constant ERROR__HOOK_TARGET = 1 << 13;
    uint256 internal constant ERROR__HOOKED_OPS = 1 << 14;
    uint256 internal constant ERROR__CONFIG_FLAGS = 1 << 15;
    uint256 internal constant ERROR__NAME = 1 << 16;
    uint256 internal constant ERROR__SYMBOL = 1 << 17;
    uint256 internal constant ERROR__LTV_LENGTH = 1 << 18;
    uint256 internal constant ERROR__LTV_BORROW_CONFIG = 1 << 19;
    uint256 internal constant ERROR__LTV_LIQUIDATION_CONFIG = 1 << 20;
    uint256 internal constant ERROR__LTV_COLLATERAL_NOT_RECOGNIZED = 1 << 21;
}
