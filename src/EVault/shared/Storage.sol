// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {MarketStorage, Snapshot} from "./types/Types.sol";

abstract contract Storage {
    bool initialized;

    MarketStorage marketStorage;

    // Transient data
    Snapshot snapshot;
}
