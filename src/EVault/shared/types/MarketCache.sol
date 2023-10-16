// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IERC20} from "../../IEVault.sol";
import {IRiskManager} from "../../../IRiskManager.sol";

import "./Types.sol";

struct MarketCache {
    IERC20 asset;
    IRiskManager riskManager;

    Shares totalBalances;
    Owed totalBorrows;

    Fees feesBalance;

    uint interestAccumulator;

    uint40 lastInterestAccumulatorUpdate;
    int96 interestRate;
    uint16 interestFee;

    Assets poolSize; // result of calling balanceOf on asset (in external units)
}
