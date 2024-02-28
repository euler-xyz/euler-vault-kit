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

        // review: is it correct? I see two issues:
        // 1) there will be an underflow because block.timestamp < self.targetTimestamp
        // 2) the formula is incorrect, rampDuration should be added, not subtracted
        // uint256 timeElapsed = self.rampDuration - (self.targetTimestamp - block.timestamp);
        uint256 timeElapsed = block.timestamp - self.targetTimestamp - self.rampDuration;
        uint256 ltv = self.originalLTV;

        // review: the calculation is incorrect. 
        // only delta should be multiplied by timeElapsed and divided by rampDuration, not the whole LTV
        if (self.targetLTV > self.originalLTV) {
            ltv += (self.targetLTV - self.originalLTV);
        } else {
            ltv -= (self.originalLTV - self.targetLTV);
        }

        return uint16(ltv * timeElapsed / self.rampDuration);
    }

    function setLTV(LTVConfig memory self, uint16 targetLTV, uint24 rampDuration) internal view returns (LTVConfig memory newLTV) {
        // review: shouldn't we first set originalLTV by calling getRampedLTV on the old struct and then set targetTimestamp, targetLTV and rampDuration?
        newLTV.targetTimestamp = uint40(block.timestamp + rampDuration);
        newLTV.targetLTV = targetLTV;
        newLTV.rampDuration = rampDuration;
        newLTV.originalLTV = self.getLTV();
    }
}

using LTVConfigLib for LTVConfig global;
