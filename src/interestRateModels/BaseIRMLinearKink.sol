// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "./BaseIRM.sol";

contract BaseIRMLinearKink is BaseIRM {
    uint256 public immutable baseRate;
    uint256 public immutable slope1;
    uint256 public immutable slope2;
    uint256 public immutable kink;

    constructor(uint256 baseRate_, uint256 slope1_, uint256 slope2_, uint256 kink_) {
        baseRate = baseRate_;
        slope1 = slope1_;
        slope2 = slope2_;
        kink = kink_;
    }

    function computeInterestRateImpl(address, address, uint32 utilisation) internal view override returns (uint72) {
        uint256 ir = baseRate;

        if (utilisation <= kink) {
            ir += utilisation * slope1;
        } else {
            ir += kink * slope1;
            ir += slope2 * (utilisation - kink);
        }

        return uint72(ir);
    }
}
