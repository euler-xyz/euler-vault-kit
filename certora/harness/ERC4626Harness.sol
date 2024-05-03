// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;
// import {IERC20} from "../../lib/ethereum-vault-connector/lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../../certora/harness/AbstractBaseHarness.sol";
import "../../src/EVault/modules/Vault.sol";
import "../../src/EVault/modules/Token.sol";

contract ERC4626Harness is VaultModule, TokenModule, AbstractBaseHarness {
    constructor(Integrations memory integrations) Base(integrations) {}

    // Linked against DummyERC20A in verification config
    IERC20 underlying_asset;

    function userAssets(address user) public view returns (uint256) { // harnessed
        return IERC20(asset()).balanceOf(user);
    }

    // VaultStorage Accessors:
    function storage_lastInterestAccumulatorUpdate() public view returns (uint48) {
        return vaultStorage.lastInterestAccumulatorUpdate;
    }
    function storage_cash() public view returns (Assets) {
        return vaultStorage.cash;
    }
    function storage_supplyCap() public view returns (AmountCap) {
        return vaultStorage.supplyCap;
    }
    function storage_borrowCap() public view returns (AmountCap) {
        return vaultStorage.borrowCap;
    }
    // reentrancyLocked seems not direclty used in loadVault
    function storage_hookedOps() public view returns (Flags) {
        return vaultStorage.hookedOps;
    }
    function storage_snapshotInitialized() public view returns (bool) {
        return vaultStorage.snapshotInitialized;
    }
    function storage_totalShares() public view returns (Shares) {
        return vaultStorage.totalShares;
    }
    function storage_totalBorrows() public view returns (Owed) {
        return vaultStorage.totalBorrows;
    }
    function storage_accumulatedFees() public view returns (Shares) {
        return vaultStorage.accumulatedFees;
    }
    function storage_interestAccumulator() public view returns (uint256) {
        return vaultStorage.interestAccumulator;
    }
    function storage_configFlags() public view returns (Flags) {
        return vaultStorage.configFlags;
    }
}
