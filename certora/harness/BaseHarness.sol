// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "../../src/EVault/shared/Base.sol";
import "../../certora/harness/AbstractBaseHarness.sol";

// This exists so that Base.LTVConfig and other type declarations 
// are available in CVL and can be used across specs for different modules.
// We need to split this into a concrete contract and an Abstract contract
// so that we can refer to Base.LTVConfig as a type in shared CVL functions
// while also making function definitions sharable among harnesses via
// AbstractBase.
contract BaseHarness is Base, AbstractBaseHarness {
    constructor(Integrations memory integrations) Base(integrations) {}
}