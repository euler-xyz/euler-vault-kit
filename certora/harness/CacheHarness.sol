// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "../../src/EVault/shared/Cache.sol";

contract CacheHarness is Cache {
    using TypesLib for uint256;
    function updateVaultExt() external virtual returns (VaultCache memory vaultCache) {
        updateVault();
    }
    function initVaultCacheExt(VaultCache memory vaultCache) external view returns (bool dirty) {
        return initVaultCache(vaultCache);
    }
    function getlastInterestAccumulatorUpdate() external view returns (uint256) {
        return vaultStorage.lastInterestAccumulatorUpdate;
    }
    function getTotalBorrows() external view returns (Owed) {
        return vaultStorage.totalBorrows;
    }
    function getInterestAcc() external view returns (uint256) {
        return vaultStorage.interestAccumulator;
    }
    function getAccumulatedFees() external view returns (Shares) {
        return vaultStorage.accumulatedFees;
    }
    function getTotalShares() external view returns (Shares) {
        return vaultStorage.totalShares;
    }
    function hasDebtSocialization() external returns (bool) {
        VaultCache memory vaultCache = loadVault();
        return vaultCache.configFlags.isNotSet(CFG_DONT_SOCIALIZE_DEBT);
    }
    // mock Vault.convertToAssets() to simplify verification of exchange rate
    // monotonicity rule for  update vault. This way we do not need to
    // bring the vault contract into the scene. This code is verbatim copied
    // from Vault.sol
    function convertToAssets(uint256 shares) public view virtual returns (uint256) {
        VaultCache memory vaultCache = loadVault();
        return shares.toShares().toAssetsDown(vaultCache).toUint();
    }
    
}