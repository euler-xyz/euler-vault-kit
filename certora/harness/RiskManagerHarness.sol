// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;
import "../../src/EVault/modules/RiskManager.sol";
import "../../src/EVault/shared/types/Types.sol";
import "../../src/interfaces/IPriceOracle.sol";
import {IERC20} from "../../src/EVault/IEVault.sol";
import {ERC20} from "../../lib/ethereum-vault-connector/lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../../certora/harness/AbstractBaseHarness.sol";

contract RiskManagerHarness is RiskManager, AbstractBaseHarness {
    constructor(Integrations memory integrations) RiskManager(integrations) {}

}