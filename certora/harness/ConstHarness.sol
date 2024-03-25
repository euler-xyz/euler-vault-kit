// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;
import "../../src/EVault/shared/Constants.sol";

// An empty contract to verify constant properties independently
contract ConstHarness {
    // Constants undeclared. Circular dependency if dropped.
    uint32 public constant OP_DEPOSIT_ = OP_DEPOSIT;
    uint32 public constant OP_MINT_ = OP_MINT;
}