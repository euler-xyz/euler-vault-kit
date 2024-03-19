// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "../InterestRateModels/IIRM.sol";
import "../interfaces/IPriceOracle.sol";

contract IRMSynth is IIRM {
    uint256 public constant TARGET_QUOTE = 1e18;
    uint216 internal constant SECONDS_PER_YEAR = 365.2425 * 86400; // Gregorian calendar
    uint216 public constant MAX_RATE = 1e27 * 1.5 / SECONDS_PER_YEAR; // 150% APR
    uint216 public constant BASE_RATE = 1e27 * 0.005 / SECONDS_PER_YEAR; // 0.5% APR
    uint216 public constant ADJUST_FACTOR = 1.1e18; // 10% adjust of last rate per interval
    uint216 public constant ADJUST_ONE = 1.0e18;
    uint216 public constant ADJUST_INTERVAL = 1 hours;

    address public immutable synth;
    address public immutable referenceAsset;
    IPriceOracle public immutable oracle;

    struct IRMData {
        uint40 lastUpdated;
        uint216 lastRate;
    }

    IRMData internal irmStorage;

    constructor(address synth_, address referenceAsset_, address oracle_) {
        synth = synth_;
        referenceAsset = referenceAsset_;
        oracle = IPriceOracle(oracle_);

        irmStorage = IRMData({
            lastUpdated: uint40(block.timestamp),
            lastRate: BASE_RATE
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
        rate = irmCache.lastRate;

        // If not time to update yet, return the last rate
        if (block.timestamp < irmCache.lastUpdated + ADJUST_INTERVAL) {
            return(rate, updated);
        }

        uint256 quote = oracle.getQuote(1e18, synth, referenceAsset);

        // If the quote is 0, return the last rate
        if (quote == 0) {
            return(rate, updated);
        }

        updated = true;

        if (quote < TARGET_QUOTE) {
            // If the quote is less than the target, increase the rate
            rate = rate * ADJUST_FACTOR / ADJUST_ONE;
        } else {
            // If the quote is greater than the target, decrease the rate
            rate = rate * ADJUST_ONE / ADJUST_FACTOR;
        }

        // Apply the min and max rates
        if (rate < BASE_RATE) {
            rate = BASE_RATE;
        } else if (rate > MAX_RATE) {
            rate = MAX_RATE;
        }

        return(rate, updated);
    }

    function getIRMData() external view returns (IRMData memory) {
        return irmStorage;
    }
}