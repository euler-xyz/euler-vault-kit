// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "../../src/EVault/shared/Cache.sol";

contract CacheHarness is Cache {
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
    
}