// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "./Owed.sol";

/// @title UserBorrowCache
/// @notice Holds computed user borrow state in memory
struct UserBorrowCache {
    address account;
    Owed prevOwed;           // Original stored owed
    Owed newOwed;            // Final owed after base interest + premium
    Owed premiumInterest;    // Premium interest portion (for fee calculation)
    uint256 premiumAccumulator;
}
