// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVault} from "../EVault/EVault.sol";
import {InitializeModule} from "../EVault/modules/Initialize.sol";
import {VaultModule} from "../EVault/modules/Vault.sol";
import {GovernanceModule} from "../EVault/modules/Governance.sol";
import {IERC20} from "../EVault/IEVault.sol";
import {ProxyUtils} from "../EVault/shared/lib/ProxyUtils.sol";
import {Operations} from "../EVault/shared/types/Types.sol";
import "../EVault/shared/Constants.sol";
import "../EVault/shared/types/Types.sol";

contract ESVault is EVault {
    using TypesLib for uint16;
    constructor(Integrations memory integrations, DeployedModules memory modules) EVault(integrations, modules) {}

    uint32 public constant SYNTH_VAULT_DISABLED_OPS = OP_MINT | OP_REDEEM | OP_SKIM | OP_LOOP | OP_DELOOP;
    uint16 internal constant INTEREST_FEE = 1e4;

    // ----------------- Initialize ----------------

    /// @inheritdoc IInitialize
    function initialize(address proxyCreator) public override virtual reentrantOK {
        InitializeModule.initialize(proxyCreator);

        // disable not supported operations
        uint32 newDisabledOps = SYNTH_VAULT_DISABLED_OPS | Operations.unwrap(marketStorage.disabledOps);
        marketStorage.disabledOps = Operations.wrap(newDisabledOps);
        emit GovSetDisabledOps(newDisabledOps);

        // set default interst fee to 100%
        uint16 newInterestFee = INTEREST_FEE;
        marketStorage.interestFee = newInterestFee.toConfigAmount();
        emit GovSetInterestFee(newInterestFee);
    }

    // ----------------- Governance ----------------

    /// @inheritdoc IGovernance
    function setDisabledOps(uint32 newDisabledOps) public override virtual reentrantOK {
        // Enforce that ops that are not supported by the synth vault are not enabled.
        uint32 filteredOps = newDisabledOps | SYNTH_VAULT_DISABLED_OPS;
        GovernanceModule.setDisabledOps(filteredOps);
    }

    /// @notice Disabled for synthetic asset vaults
    function setInterestFee(uint16) public override virtual reentrantOK {
        revert E_OperationDisabled();
    }

    // ----------------- Vault ----------------
    
    /// @dev This function can only be called by the synth contract to deposit assets into the vault.
    /// @param amount The amount of assets to deposit.
    /// @param receiver The address to receive the assets.
    function deposit(uint256 amount, address receiver) public override virtual callThroughEVC returns (uint256) {
        // only the synth contract can call this function.
        address account = EVCAuthenticate();
        (IERC20 synth,,) = ProxyUtils.metadata();

        if (account != address(synth)) revert E_Unauthorized();

        return VaultModule.deposit(amount, receiver);
    }
}
