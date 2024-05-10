// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ConfigAmount} from "./Types.sol";

/// @title LTVConfig
/// @notice This packed struct is used to store LTV configuration of a collateral
struct LTVConfig {
    // Packed slot: 6 + 2 + 2 + 4 + 2 + 1 = 17
    // The timestamp when the new liquidation LTV ramping is finished
    uint48 targetTimestamp;
    // The value of fully converged liquidation LTV value
    ConfigAmount targetLiquidationLTV;
    // The previous liquidation LTV value, from which the ramping begun
    ConfigAmount originalLiquidationLTV;
    // The time it takes the liquidation LTV to converge with borrowing LTV
    uint32 rampDuration;
    // The value of LTV for borrow purposes
    ConfigAmount borrowLTV;
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
    function getLTV(LTVConfig memory self, bool liquidation) internal view returns (ConfigAmount) {
        if (!liquidation) {
            return self.borrowLTV;
        }

        if (block.timestamp >= self.targetTimestamp || self.targetLiquidationLTV >= self.originalLiquidationLTV) {
            return self.targetLiquidationLTV;
        }

        uint256 currentLTV = self.originalLiquidationLTV.toUint16();

        unchecked {
            uint256 targetLTV = self.targetLiquidationLTV.toUint16();
            uint256 timeRemaining = self.targetTimestamp - block.timestamp;

            // targetLTV < originalLTV and timeRemaining < rampDuration
            currentLTV = targetLTV + (currentLTV - targetLTV) * timeRemaining / self.rampDuration;
        }
        // because ramping happens only when LTV decreases, it's safe to down-cast the new value
        return ConfigAmount.wrap(uint16(currentLTV));
    }

    function setLTV(
        LTVConfig memory self,
        ConfigAmount targetLiquidationLTV,
        uint32 rampDuration,
        ConfigAmount borrowLTV
    ) internal view returns (LTVConfig memory newLTV) {
        newLTV.targetTimestamp = uint48(block.timestamp + rampDuration);
        newLTV.targetLiquidationLTV = targetLiquidationLTV;
        newLTV.originalLiquidationLTV = self.getLTV(true);
        newLTV.rampDuration = rampDuration;
        newLTV.borrowLTV = borrowLTV;
        newLTV.initialized = true;
    }

    // When LTV is cleared, the collateral can't be liquidated, as it's deemed unsafe
    function clear(LTVConfig storage self) internal {
        self.targetTimestamp = 0;
        self.targetLiquidationLTV = ConfigAmount.wrap(0);
        self.originalLiquidationLTV = ConfigAmount.wrap(0);
        self.rampDuration = 0;
        self.borrowLTV = ConfigAmount.wrap(0);
    }
}

using LTVConfigLib for LTVConfig global;
