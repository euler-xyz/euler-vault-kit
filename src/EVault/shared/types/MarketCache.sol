// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IERC20} from "../../IEVault.sol";
import {IPriceOracle} from "../../../IPriceOracle.sol";

import "./Types.sol";

struct MarketCache {
    IERC20 asset;
    IPriceOracle oracle;
    address unitOfAccount;

    uint40 lastInterestAccumulatorUpdate;
    Assets poolSize; // alcueca: If changing in MarketStorage, then change here as well.
    Owed totalBorrows;
    Shares totalShares;
    Shares feesBalance; // alcueca: If changing to feeShares in MarketStorage, then change here as well.
    uint256 interestAccumulator;

    uint256 supplyCap;
    uint256 borrowCap;
    DisabledOps disabledOps;
    bool snapshotInitialized;
}
