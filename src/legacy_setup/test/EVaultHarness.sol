// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVault} from "../../EVault/EVault.sol";
import "../../EVault/shared/types/Types.sol";
// import "../EVault/shared/Constants.sol";

import "hardhat/console.sol";

contract EVaultHarness is EVault {
    using TypesLib for uint256;

    constructor(Integrations memory integrations, DeployedModules memory modules)
        EVault(integrations, modules)
    {}

    function harness_setZeroInterestFee() external {
        vaultStorage.interestFee = ConfigAmount.wrap(0);
    }

    function harness_setInterestFee(uint16 fee) external {
        vaultStorage.interestFee = ConfigAmount.wrap(fee);
    }

    function test_maxOwedAndAssetsConversions() external pure {
        require(MAX_SANE_DEBT_AMOUNT.toOwed().toAssetsUp().toUint() == MAX_SANE_AMOUNT, "owed to assets up");
        require(MAX_SANE_AMOUNT.toAssets().toOwed().toUint() == MAX_SANE_DEBT_AMOUNT, "assets to owed");
    }
}
