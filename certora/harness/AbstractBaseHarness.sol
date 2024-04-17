// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "../../src/EVault/shared/Base.sol";

// This mainly exists so that Base.LTVConfig and other type declarations 
// are available in CVL and can be used across specs for different modules.
// It also exports some functions common across the modules.

abstract contract AbstractBaseHarness is Base {
    function getCollateralsExt(address account) public view returns (address[] memory) {
        return getCollaterals(account);
    }

    // function getLTVConfig(address collateral) external view returns (LTVConfig memory) {
    //     return vaultStorage.ltvLookup[collateral];
    // }
}