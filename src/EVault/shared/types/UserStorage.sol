// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Shares, Owed} from "./Types.sol";

/// @dev Custom type for holding shares and debt balances of an account, packed with balance forwarder opt-in flag
type PackedUserSlot is uint256;

/// @title UserStorage
/// @notice This struct is used to store user account data
struct UserStorage {
    // Shares and debt balances, balance forwarder opt-in
    PackedUserSlot data;
    // Snapshot of the interest accumulator from the last change to account's liability
    uint256 interestAccumulator;
    // A mapping with allowances for the vault shares token (eToken)
    mapping(address spender => uint256 allowance) eTokenAllowance;
}

/// @title UserStorageLib
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Library for working with the UserStorage struct
library UserStorageLib {
    uint256 private constant BALANCE_FORWARDER_MASK = 0x8000000000000000000000000000000000000000000000000000000000000000;
    uint256 private constant STAMP_REMAINDER_MASK = 0x7FFF000000000000000000000000000000000000000000000000000000000000;
    uint256 private constant OWED_MASK = 0x0000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000000000000000000000000000;
    uint256 private constant SHARES_MASK = 0x000000000000000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFF;
    uint256 private constant OWED_OFFSET = 112;
    uint256 private constant STAMP_REMAINDER_OFFSET = 240;
    uint256 private constant STAMP_DIVISOR = 32768;

    function isBalanceForwarderEnabled(UserStorage storage self) internal view returns (bool) {
        return unpackBalanceForwarder(self.data);
    }

    function getOwed(UserStorage storage self) internal view returns (Owed) {
        return unpackOwed(self.data);
    }

    function getOwedAndLiqudiationAllowed(UserStorage storage self) internal view returns (Owed, bool) {
        PackedUserSlot data = self.data; // single SLOAD
        return (unpackOwed(data), unpackStampRemainder(data) != computeStampRemainder());
    }

    function getBalance(UserStorage storage self) internal view returns (Shares) {
        return unpackBalance(self.data);
    }

    function getBalanceAndBalanceForwarder(UserStorage storage self) internal view returns (Shares, bool) {
        PackedUserSlot data = self.data; // single SLOAD
        return (unpackBalance(data), unpackBalanceForwarder(data));
    }

    function setBalanceForwarder(UserStorage storage self, bool newValue) internal {
        uint256 data = PackedUserSlot.unwrap(self.data);

        uint256 newFlag = newValue ? BALANCE_FORWARDER_MASK : 0;
        self.data = PackedUserSlot.wrap(newFlag | (data & ~BALANCE_FORWARDER_MASK));
    }

    function setOwedAndStampRemainder(UserStorage storage self, Owed owed) internal {
        PackedUserSlot data = self.data; // single SLOAD
        uint256 newData = PackedUserSlot.unwrap(data);

        if (owed > unpackOwed(data)) {
            newData = (computeStampRemainder() << STAMP_REMAINDER_OFFSET) | (newData & ~STAMP_REMAINDER_MASK);
        }

        newData = (owed.toUint() << OWED_OFFSET) | (newData & ~OWED_MASK);

        self.data = PackedUserSlot.wrap(newData);
    }

    function setBalance(UserStorage storage self, Shares balance) internal {
        uint256 data = PackedUserSlot.unwrap(self.data);

        self.data = PackedUserSlot.wrap(balance.toUint() | (data & ~SHARES_MASK));
    }

    function unpackBalance(PackedUserSlot data) private pure returns (Shares) {
        return Shares.wrap(uint112(PackedUserSlot.unwrap(data) & SHARES_MASK));
    }

    function unpackOwed(PackedUserSlot data) private pure returns (Owed) {
        return Owed.wrap(uint144((PackedUserSlot.unwrap(data) & OWED_MASK) >> OWED_OFFSET));
    }

    function unpackBalanceForwarder(PackedUserSlot data) private pure returns (bool) {
        return (PackedUserSlot.unwrap(data) & BALANCE_FORWARDER_MASK) > 0;
    }

    function unpackStampRemainder(PackedUserSlot data) private pure returns (uint256) {
        return (PackedUserSlot.unwrap(data) & STAMP_REMAINDER_MASK) >> STAMP_REMAINDER_OFFSET;
    }

    function computeStampRemainder() private view returns (uint256) {
        return uint256(blockhash(block.number - 1)) % STAMP_DIVISOR;
    }
}

using UserStorageLib for UserStorage global;
