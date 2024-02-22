// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "./types/MarketStorage.sol";

abstract contract Storage {
    bool initialized;

    MarketStorage marketStorage;

    // keep it outside of MarketStorage awaiting for transient keyword
    Assets snapshotPoolSize;
    Assets snapshotTotalBorrows;

    mapping(address collateral => LTVConfig) internal ltvLookup;
    address[] internal ltvList;
}
