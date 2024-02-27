// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

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

        uint256 timeElapsed = block.timestamp - self.targetTimestamp - self.rampDuration;
        uint256 ltv = self.originalLTV;

        if (self.targetLTV > self.originalLTV) {
            ltv += (self.targetLTV - self.originalLTV);
        } else {
            ltv -= (self.originalLTV - self.targetLTV);
        }

        return uint16(ltv * timeElapsed / self.rampDuration);
    }

    function setLTV(LTVConfig memory self, uint16 targetLTV, uint24 rampDuration) internal view returns (LTVConfig memory newLTV) {
        newLTV.targetTimestamp = uint40(block.timestamp + rampDuration);
        newLTV.targetLTV = targetLTV;
        newLTV.rampDuration = rampDuration;
        newLTV.originalLTV = self.getLTV();
    }
}

using LTVConfigLib for LTVConfig global;
