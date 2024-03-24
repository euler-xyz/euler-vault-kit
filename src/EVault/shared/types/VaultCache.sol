// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IERC20} from "../../IEVault.sol";
import {IPriceOracle} from "../../../interfaces/IPriceOracle.sol";

import {Assets, Owed, Shares, Flags} from "./Types.sol";

struct VaultCache {
    IERC20 asset;
    IPriceOracle oracle;
    address unitOfAccount;

    uint48 lastInterestAccumulatorUpdate;
    Assets cash;
    Owed totalBorrows;
    Shares totalShares;
    Shares accumulatedFees;
    uint256 interestAccumulator;

    uint256 supplyCap;
    uint256 borrowCap;
    Flags disabledOps;
    Flags configFlags;
    bool snapshotInitialized;
}
