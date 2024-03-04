// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "./types/MarketStorage.sol";

abstract contract Storage {
    bool initialized;

    MarketStorage marketStorage;

    // Transient data
    // alcueca: If the snapshot can't be placed in marketStorage, it might look cleaner to put it in a struct
    Assets snapshotPoolSize;
    Assets snapshotTotalBorrows;

    mapping(address collateral => LTVConfig) internal ltvLookup;
    address[] internal ltvList;
}
