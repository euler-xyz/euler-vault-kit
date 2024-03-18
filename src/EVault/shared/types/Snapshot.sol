// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Assets} from "./Types.sol";

struct Snapshot {
    // Packed slot: 14 + 14 + 4 = 32
    Assets cash;
    Assets borrows;
    uint32 _stamp;
}

library SnapshotLib {
    uint32 constant STAMP = 1 << 31;  // non zero initial value of the snapshot slot to save gas on SSTORE

    function set(Snapshot storage self, Assets cash, Assets borrows) internal {
        self.cash = cash;
        self.borrows = borrows;
        self._stamp = STAMP;
    }

    function reset(Snapshot storage self) internal {
        self.set(Assets.wrap(0), Assets.wrap(0));
    }
}

using SnapshotLib for Snapshot global;
