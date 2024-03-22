// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Market} from "./types/Market.sol";

abstract contract MarketStorage {
    // keccak256(abi.encode(uint256(keccak256("euler.evault.storage.Market")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant MARKET_STORAGE = 0xb3678cae26b5810bd240885d3ce17f7b160cb73b8a97793d1d2235fc34b89500;

    /// @dev Storage for main vault data, shared by most modules, implemented on a custom ERC-7201 namespace.
    /// MarketStorageStruct is wrapping Market under the same slot only to apply ERC7201 annotation.
    /// @custom:storage-location erc7201:euler.evault.storage.Market
    struct MarketStorageStruct {
        Market market;
    }

    function marketStorage() internal pure returns (Market storage data) {
        assembly {
            data.slot := MARKET_STORAGE
        }
    }
}
