// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {MarketStorage} from "./MarketStorage.sol";
import "./types/Types.sol";

abstract contract LTVUtils is MarketStorage {
    function getLTV(address collateral, LTVType ltvType) internal view virtual returns (ConfigAmount) {
        return marketStorage().ltvLookup[collateral].getLTV(ltvType);
    }

    function isRecognizedCollateral(address collateral) internal view virtual returns (bool) {
        return marketStorage().ltvLookup[collateral].isRecognizedCollateral();
    }
}
