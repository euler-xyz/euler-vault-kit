// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "./BaseIRMLinearKink.sol";

contract IRMClassStable is BaseIRMLinearKink {
    constructor()
        BaseIRMLinearKink(
            // Base=0% APY,  Kink(80%)=4% APY  Max=100% APY
            0,
            361718388,
            24123704987,
            3435973836
        )
    {}
}
