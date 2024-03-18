// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "./IIRM.sol";
import "../interfaces/IPriceOracle.sol";

contract IRMSynth is IIRM {
    uint256 public constant BPS_SCALE = 10000;
    uint256 public constant TARGET_QUOTE = 1e18;
    uint256 constant SECONDS_PER_YEAR = 365.2425 * 86400; // Gregorian calendar
    uint256 public constant MAX_RATE = 1e27 * 1.5 / SECONDS_PER_YEAR; // 150% APR
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
            lastRate: uint216(BASE_RATE)
        });
    }

    function computeInterestRate(address, uint256, uint256) external override returns (uint256) {
        IRMData memory irmCache = irmStorage;
        (uint216 rate, bool updated) = _computeRate(irmCache);

        if (updated) {
            irmStorage = IRMData({
                lastUpdated: uint40(block.timestamp),
                lastRate: rate
            });
        }

        return rate;
    }

    function computeInterestRateView(address, uint256, uint256) external view override returns (uint256) {
        (uint216 rate, ) = _computeRate(irmStorage);
        return rate;
    }

    function _computeRate(IRMData memory irmCache) internal view returns (uint216 rate, bool updated) {
        updated = false;

        // If not time to update yet, return the last rate
        if (block.timestamp < irmCache.lastUpdated + ADJUST_INTERVAL) {
            rate = irmCache.lastRate;
            return(rate, updated);
        }

        uint256 quote = oracle.getQuote(1e18, synth, referenceAsset);

        // If the quote is 0, return the last rate
        if (quote == 0) {
            rate = irmCache.lastRate;
            return(rate, updated);
        }

        if (quote < TARGET_QUOTE) {
            // If the quote is less than the target, increase the rate
            rate = uint216(irmCache.lastRate + (irmCache.lastRate * ADJUST_AMOUNT / ADJUST_AMOUNT_SCALE));
        } else {
            // If the quote is greater than the target, decrease the rate
            rate = uint216(irmCache.lastRate - (irmCache.lastRate * ADJUST_AMOUNT / ADJUST_AMOUNT_SCALE));
        }

        // Apply the min and max rates
        if (rate < BASE_RATE) {
            rate = uint216(BASE_RATE);
        } else if (rate > MAX_RATE) {
            rate = uint216(MAX_RATE);
        }

        rate = rate;
        updated = true;
        return(rate, updated);
    }

    function getIRMData() external view returns (IRMData memory) {
        return irmStorage;
    }
}