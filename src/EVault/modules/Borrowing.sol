// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BaseModule} from "../shared/BaseModule.sol";
import {IBorrowing} from "../IEVault.sol";

abstract contract BorrowingModule is BaseModule, IBorrowing {

}

contract Borrowing is BorrowingModule {
    constructor(address factory, address cvc) BaseModule(factory, cvc) {}
}