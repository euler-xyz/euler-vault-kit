// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {VaultData} from "./types/VaultData.sol";

abstract contract VaultStorage {
    // keccak256(abi.encode(uint256(keccak256("euler.evault.storage.Vault")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant VAULT_STORAGE = 0x384a0d382726f2699c0e311ad26726263e47df8cb46f208c4690e77e78465e00;

    /// @dev Storage for main vault data, shared by most modules, implemented on a custom ERC-7201 namespace.
    /// VaultStorageStruct is wrapping VaultData under the same slot for ERC7201 annotation.
    /// @custom:storage-location erc7201:euler.evault.storage.Vault
    struct VaultStorageStruct {
        VaultData market;
    }

    function vaultStorage() internal pure returns (VaultData storage data) {
        assembly {
            data.slot := VAULT_STORAGE
        }
    }
}
