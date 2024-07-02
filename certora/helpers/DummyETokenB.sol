// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.0;

import "certora/harness/TokenHarness.sol";

contract DummyETokenB is TokenHarness {
    constructor(Integrations memory integrations) TokenHarness(integrations) {}
}