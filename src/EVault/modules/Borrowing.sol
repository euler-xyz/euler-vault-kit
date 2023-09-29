// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import { IBorrowing } from "../IEVault.sol";

abstract contract BorrowingModule is IBorrowing {

}

contract Borrowing is BorrowingModule {}