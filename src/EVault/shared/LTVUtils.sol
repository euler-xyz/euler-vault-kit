// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {VaultStorage} from "./VaultStorage.sol";
import "./types/Types.sol";

abstract contract LTVUtils is VaultStorage {
    function getLTV(address collateral, LTVType ltvType) internal view virtual returns (ConfigAmount) {
        return vaultStorage().ltvLookup[collateral].getLTV(ltvType);
    }

    function isRecognizedCollateral(address collateral) internal view virtual returns (bool) {
        return vaultStorage().ltvLookup[collateral].isRecognizedCollateral();
    }
}
