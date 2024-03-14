// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "./IIRM.sol";
import "../interfaces/IPriceOracle.sol";

contract IRMSynth is IIRM {
    uint256 public constant BPS_SCALE = 10000;
    uint256 public constant TARGET_QUOTE = 1e18;
    uint256 constant SECONDS_PER_YEAR = 365.2425 * 86400; // Gregorian calendar
    uint256 public constant MAX_RATE = 1e27 * 0.15 / SECONDS_PER_YEAR; // 15% APR
    uint256 public constant BASE_RATE = 1e27 * 0.005 / SECONDS_PER_YEAR; // 0.5% APR
    uint256 public constant ADJUST_AMOUNT = 0.1e18; // 10% adjust of last rate per interval
    uint256 public constant ADJUST_AMOUNT_SCALE = 1e18;
    uint256 public constant ADJUST_INTERVAL = 1 hours;

    address public immutable synth;
    address public immutable referenceAsset;
    IPriceOracle public immutable oracle;

    struct IRMData {
        uint40 lastUpdated;
        uint216 lastRate;
    }

    IRMData public irmStorage;

    constructor(address synth_, address referenceAsset_, address oracle_) {
        synth = synth_;
        referenceAsset = referenceAsset_;
        oracle = IPriceOracle(oracle_);

        irmStorage = IRMData({
            lastUpdated: uint40(block.timestamp),
            lastRate: uint216(BASE_RATE
        )});
    }

    function computeInterestRate(address, uint256, uint256) external override returns (uint256) {
        IRMData memory irmCache = irmStorage;

        // If not time to update yet, return the last rate
        if (block.timestamp < irmCache.lastUpdated + ADJUST_INTERVAL) {
            return irmCache.lastRate;
        }

        uint256 quote = oracle.getQuote(1e18, synth, referenceAsset);

        // If the quote is 0, return the last rate
        if (quote == 0) {
            return irmCache.lastRate;
        }

        if (quote < TARGET_QUOTE) {
            // If the quote is less than the target, increase the rate
            irmCache.lastRate = uint216(irmCache.lastRate + (irmCache.lastRate * ADJUST_AMOUNT / ADJUST_AMOUNT_SCALE));
        } else {
            // If the quote is greater than the target, decrease the rate
            irmCache.lastRate = uint216(irmCache.lastRate - (irmCache.lastRate * ADJUST_AMOUNT / ADJUST_AMOUNT_SCALE));
        }

        // Apply the min and max rates
        if (irmCache.lastRate < BASE_RATE) {
            irmCache.lastRate = uint216(BASE_RATE);
        } else if (irmCache.lastRate > MAX_RATE) {
            irmCache.lastRate = uint216(MAX_RATE);
        }

        // Update the last updated timestamp
        irmCache.lastUpdated = uint40(block.timestamp);
        // Write cache to storage
        irmStorage = irmCache;

        return irmCache.lastRate;
    }

    function getIRMData() external view returns (IRMData memory) {
        return irmStorage;
    }
}