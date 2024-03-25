// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "../../InterestRateModels/IRMLinearKink.sol";

contract IRMDefault is IRMLinearKink {
    constructor()
        IRMLinearKink(
            // Base=0% APY,  Kink(50%)=10% APY  Max=300% APY
            0,
            1406417851,
            19050045013,
            2147483648
        )
    {}
}
