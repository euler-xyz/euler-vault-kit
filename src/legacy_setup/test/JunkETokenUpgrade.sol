// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "../../EVault/EVault.sol";

contract JunkEVaultUpgrade is EVault {
    constructor()
        EVault(
            Integrations(address(0), address(0), address(0), address(0)),
            DeployedModules(
                address(0),
                address(0),
                address(0),
                address(0),
                address(0),
                address(0),
                address(0),
                address(0)
            )
        )
    {}

    function newName() external pure returns (string memory) {
        return "JUNK_UPGRADE_NAME";
    }
}
