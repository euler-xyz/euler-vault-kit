// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Assets} from "./Types.sol";

struct Snapshot {
    // Packed slot: 1 + 14 + 14 = 29
    uint8 _stamp;
    Assets cash;
    Assets borrows;
}

library SnapshotLib {
    uint8 constant STAMP = 1;  // non zero initial value of the snapshot slot to save gas on SSTORE

    function set(Snapshot storage self, Assets cash, Assets borrows) internal {
        self._stamp = STAMP;
        self.cash = cash;
        self.borrows = borrows;
    }

    function reset(Snapshot storage self) internal {
        self.set(Assets.wrap(0), Assets.wrap(0));
    }
}

using SnapshotLib for Snapshot global;
