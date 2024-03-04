// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Errors} from "../Errors.sol";
import "../Constants.sol";

struct LTVConfig {
    uint40 targetTimestamp;
    uint16 targetLTV;
    uint24 rampDuration;
    uint16 originalLTV;
}

library LTVConfigLib {
    function initialised(LTVConfig memory self) internal pure returns (bool) {
        return self.targetTimestamp != 0;
    }

    function getLTV(LTVConfig memory self) internal pure returns (uint16) {
        return self.targetLTV;
    }

    function getRampedLTV(LTVConfig memory self) internal view returns (uint16) {
        if (block.timestamp >= self.targetTimestamp) return self.targetLTV;

        uint256 ltv = self.originalLTV;

        unchecked {
            uint256 timeElapsed = self.rampDuration - (self.targetTimestamp - block.timestamp);

            if (self.targetLTV > self.originalLTV) {
                ltv += ((self.targetLTV - self.originalLTV) * timeElapsed / self.rampDuration);
            } else {
                ltv -= ((self.originalLTV - self.targetLTV) * timeElapsed / self.rampDuration);
            }
        }

        return uint16(ltv);
    }

    function setLTV(LTVConfig memory self, uint16 targetLTV, uint24 rampDuration) internal view returns (LTVConfig memory newLTV) {
        if (targetLTV > CONFIG_SCALE) revert Errors.E_InvalidLTV();

        newLTV.targetTimestamp = uint40(block.timestamp + rampDuration);
        newLTV.targetLTV = targetLTV;
        newLTV.rampDuration = rampDuration;
        newLTV.originalLTV = self.getRampedLTV();
    }

    function clear(LTVConfig storage self) internal {
        self.targetTimestamp = 0;
        self.targetLTV = 0;
        self.rampDuration = 0;
        self.originalLTV = 0;
    }
}

using LTVConfigLib for LTVConfig global;
