// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Snapshot} from "./types/Snapshot.sol";

abstract contract SnapshotStorage {
    // keccak256(abi.encode(uint256(keccak256("euler.evault.storage.Snapshot")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant SNAPSHOT_STORAGE = 0x8de38e95fe92fb64c3c6fa79a422833a72fa1e96f015d453352825a959c71e00;

    /// @dev Vault snapshot storage, implemented on a custom ERC-7201 namespace.
    /// SnaphotStorageStruct is wrapping Snapshot under the same slot for ERC7201 annotation.
    /// @custom:storage-location erc7201:euler.evault.storage.Snapshot
    struct SnaphotStorageStruct {
        Snapshot snapshot;
    }

    function snapshotStorage() internal pure virtual returns (Snapshot storage data) {
        assembly {
            data.slot := SNAPSHOT_STORAGE
        }
    }

    function resetSnapshot() internal virtual {
        snapshotStorage().reset();
    }
}
