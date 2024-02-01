// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "./BaseIRMLinearKink.sol";

contract IRMClassMajor is BaseIRMLinearKink {
    constructor(bytes32 gitCommit_)
        BaseIRMLinearKink(
            gitCommit_,
            // Base=0% APY,  Kink(80%)=20% APY  Max=300% APY
            0,
            1681485479,
            44415215206,
            3435973836
        )
    {}
}
