// SPDX-License-Identifier: GPL-2.0-or-later


pragma solidity ^0.8.0;

import "../../src/EVault/modules/ModuleDispatch.sol";

contract ModuleDispatchHarness is ModuleDispatch {
    constructor(Integrations memory integrations) Base(integrations) {}
}
