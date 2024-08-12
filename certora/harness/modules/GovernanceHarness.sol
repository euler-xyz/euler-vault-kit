// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;
import {ERC20} from "../../../lib/ethereum-vault-connector/lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../../../certora/harness/AbstractBaseHarness.sol";
import "../../../src/EVault/modules/RiskManager.sol";
import "../../../src/EVault/modules/Governance.sol";

contract GovernanceHarness is Governance, AbstractBaseHarness, RiskManagerModule{
    constructor(Integrations memory integrations) Governance (integrations) {}

    function getAccountBalance(address account) external view returns (Shares balance){
        UserStorage storage user = vaultStorage.users[account];
        (balance, ) = user.getBalanceAndBalanceForwarder();
    }

    function getGovernorReceiver() external view returns (address governorReceiver){
        governorReceiver = vaultStorage.feeReceiver;
    }

    function getProtocolFeeConfig(address vault) external view returns (address protocolReceiver, uint16 protocolFee){
        (protocolReceiver, protocolFee) = protocolConfig.protocolFeeConfig(address(this));
    }

    function getTotalShares() external view returns (Shares){
        return vaultStorage.totalShares;
    }

    function getAccumulatedFees() external view returns (Shares){
        VaultCache memory vaultCache;
        initVaultCache(vaultCache);
        return vaultCache.accumulatedFees;
    }

    function getLastAccumulated() external view returns (uint256){
        return uint256(vaultStorage.lastInterestAccumulatorUpdate);
    }

    function getLTVHarness(address collateral, bool liquidation) public view virtual returns (ConfigAmount) {
        return getLTV(collateral, liquidation);
    }

}