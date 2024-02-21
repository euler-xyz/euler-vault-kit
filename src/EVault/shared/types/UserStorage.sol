// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "./Types.sol";

type PackedUserSlot is uint256;

struct UserStorage {
    PackedUserSlot data;

    uint256 interestAccumulator;
}

uint256 constant BALANCE_FORWARDER_MASK = 0x8000000000000000000000000000000000000000000000000000000000000000;
uint256 constant OWED_MASK = 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000000000000000000000000000;
uint256 constant SHARES_MASK = 0x000000000000000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFF;

library UserStorageLib {
    function getBalanceForwarderEnabled(UserStorage storage self) internal view returns (bool) {
        return unpackBalanceForwarder(self.data);
    }

    function getOwed(UserStorage storage self) internal view returns (Owed) {
        return Owed.wrap(uint144((PackedUserSlot.unwrap(self.data) & OWED_MASK) >> 112));
    }

    function getBalance(UserStorage storage self) internal view returns (Shares) {
        return unpackBalance(self.data);
    }

    function getBalanceAndBalanceForwarder(UserStorage storage self) internal view returns (Shares, bool) {
        PackedUserSlot data = self.data; // single SLOAD
        return (unpackBalance(data), unpackBalanceForwarder(data));
    }

    function setBalanceForwarder(UserStorage storage self, bool newValue) internal {
        self.data = newValue
            ? PackedUserSlot.wrap(PackedUserSlot.unwrap(self.data) | BALANCE_FORWARDER_MASK)
            : PackedUserSlot.wrap(PackedUserSlot.unwrap(self.data) & ~BALANCE_FORWARDER_MASK);
    }

    function setOwed(UserStorage storage self, Owed owed) internal {
        uint256 data = PackedUserSlot.unwrap(self.data);

        self.data = PackedUserSlot.wrap((owed.toUint() << 112) | (data & (BALANCE_FORWARDER_MASK | SHARES_MASK)));
    }

    function setBalance(UserStorage storage self, Shares balance) internal {
        uint256 data = PackedUserSlot.unwrap(self.data);

        self.data = PackedUserSlot.wrap(balance.toUint() | (data & (BALANCE_FORWARDER_MASK | OWED_MASK)));
    }

    function unpackBalance(PackedUserSlot data) private pure returns (Shares) {
        return Shares.wrap(uint112(PackedUserSlot.unwrap(data) & SHARES_MASK));
    }

    function unpackBalanceForwarder(PackedUserSlot data) private pure returns (bool) {
        return (PackedUserSlot.unwrap(data) & BALANCE_FORWARDER_MASK) > 0;
    }
}

using UserStorageLib for UserStorage global;