// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IERC20} from "../../IEVault.sol";

import "./Types.sol";

// FIXME: figure out better location for this
struct Snapshot {
    uint256 poolSize;
    uint256 totalBorrows;
}

// FIXME: kill this, or figure out better location
struct Liability {
    address market;
    address asset;
    uint256 owed;
}

struct MarketCache {
    IERC20 asset;
    Shares totalShares;
    Owed totalBorrows;
    uint40 lastInterestAccumulatorUpdate;
    Assets poolSize;
    Fees feesBalance;
    uint256 interestAccumulator;
}
