// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;
import {ERC20} from "../../../lib/ethereum-vault-connector/lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../../../certora/harness/AbstractBaseHarness.sol";
import "../../../src/EVault/modules/Borrowing.sol";

contract BorrowingHarness is Borrowing, AbstractBaseHarness {
    constructor(Integrations memory integrations) Borrowing (integrations) {}
}