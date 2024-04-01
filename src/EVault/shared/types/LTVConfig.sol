// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ConfigAmount} from "./Types.sol";

/// @title LTVType
/// @notice Enum of LTV types
enum LTVType {
    BORROWING,
    LIQUIDATION
}

/// @title LTVConfig
/// @notice This packed struct is used to store LTV configuration of a collateral
struct LTVConfig {
    // Packed slot: 6 + 2 + 4 + 2 + 1 = 15
    // The timestamp when the new liquidation LTV ramping is finished
    uint48 targetTimestamp;
    // The value of fully converged LTV value
    ConfigAmount targetLTV;
    // The time it takes the liquidation LTV to converge with borrowing LTV
    uint32 rampDuration;
    // The previous liquidation LTV value, from which the ramping begun
    ConfigAmount originalLTV;
    // A flag indicating the configuration was initialized for the collateral
    bool initialized;
}

/// @title LTVConfigLib
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Library for getting and setting the LTV configurations
library LTVConfigLib {
    // Is the collateral considered safe to liquidate
    function isRecognizedCollateral(LTVConfig memory self) internal pure returns (bool) {
        return self.targetTimestamp != 0;
    }

    // Get current LTV of a collateral. When liquidation LTV is lowered, it is ramped down to target value over a period of time.
    function getLTV(LTVConfig memory self, LTVType ltvType) internal view returns (ConfigAmount) {
        if (
            ltvType == LTVType.BORROWING || block.timestamp >= self.targetTimestamp || self.targetLTV > self.originalLTV
        ) {
            return self.targetLTV;
        }

        uint256 ltv = self.originalLTV.toUint16();

        unchecked {
            uint256 timeElapsed = self.rampDuration - (self.targetTimestamp - block.timestamp);

            // targetLTV < originalLTV and timeElapsed < rampDuration
            ltv = ltv - ((ltv - self.targetLTV.toUint16()) * timeElapsed / self.rampDuration);
        }
        // because ramping happens only when LTV decreases, it's safe to down-cast the new value
        return ConfigAmount.wrap(uint16(ltv));
    }

    function setLTV(LTVConfig memory self, ConfigAmount targetLTV, uint32 rampDuration)
        internal
        view
        returns (LTVConfig memory newLTV)
    {
        newLTV.targetTimestamp = uint48(block.timestamp + rampDuration);
        newLTV.targetLTV = targetLTV;
        newLTV.rampDuration = rampDuration;
        newLTV.originalLTV = self.getLTV(LTVType.LIQUIDATION);
        newLTV.initialized = true;
    }

    // When LTV is cleared, the collateral can't be liquidated, as it's deemed unsafe
    function clear(LTVConfig storage self) internal {
        self.targetTimestamp = 0;
        self.targetLTV = ConfigAmount.wrap(0);
        self.rampDuration = 0;
        self.originalLTV = ConfigAmount.wrap(0);
    }
}

using LTVConfigLib for LTVConfig global;
