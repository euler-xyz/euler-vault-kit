// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {VaultStorage, Snapshot} from "./types/Types.sol";

abstract contract Storage {
    bool initialized;

    VaultStorage vaultStorage;

    // Transient data
    Snapshot snapshot;
}
