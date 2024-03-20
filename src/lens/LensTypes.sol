// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

struct UserInfo {
    EVCUserInfo evcUserInfo;
    VaultUserInfo vaultUserInfo;
    RewardUserInfo rewardUserInfo;
}

struct EVCUserInfo {
    uint256 timestamp;
    uint256 blockNumber;
    address evc;
    address account;
    bytes19 addressPrefix;
    address owner;
    bool isLockdownMode;
    bool isPermitDisabledMode;
    address[] enabledControllers;
    address[] enabledCollaterals;
}

struct VaultUserInfo {
    uint256 timestamp;
    uint256 blockNumber;
    address account;
    address vault;
    address asset;
    uint256 shares;
    uint256 assets;
    uint256 borrowed;
    uint256 liabilityValueTarget;
    uint256 collateralValueTarget;
    uint256 liabilityValueLiquidation;
    uint256 collateralValueLiquidation;
    uint256 maxDeposit;
    uint256 maxMint;
    uint256 maxWithdraw;
    uint256 maxRedeem;
    uint256 assetAllowanceVault;
    uint256 assetAllowanceVaultPermit2;
    uint256 assetAllowanceExpirationVaultPermit2;
    uint256 assetAllowancePermit2;
    bool balanceForwarderEnabled;
    bool isController;
    bool isCollateral;
}

struct VaultInfo {
    uint256 timestamp;
    uint256 blockNumber;
    address vault;
    string vaultName;
    string vaultSymbol;
    uint256 vaultDecimals;
    address asset;
    string assetName;
    string assetSymbol;
    uint256 assetDecimals;
    uint256 totalShares;
    uint256 totalCash;
    uint256 totalBorrowed;
    uint256 totalAssets;
    uint256 accumulatedFeesShares;
    uint256 accumulatedFeesAssets;
    address governorFeeReceiver;
    address protocolFeeReceiver;
    uint256 protocolFeeShare;
    uint256 interestFee;
    uint256 borrowInterestRateSPY;
    uint256 borrowInterestRateAPY;
    uint256 supplyInterestRateSPY;
    uint256 supplyInterestRateAPY;
    uint256 disabledOperations;
    uint256 supplyCap;
    uint256 borrowCap;
    address dToken;
    address unitOfAccount;
    address oracle;
    address interestRateModel;
    address evc;
    address protocolConfig;
    address balanceTracker;
    address permit2;
    address creator;
    address governorAdmin;
    address pauseGuardian;
    LTVInfo[] ltvs;
}

struct LTVInfo {
    address collateral;
    uint256 originalLTV;
    uint256 targetLTV;
    uint256 targetTimestamp;
    uint256 rampDuration;
    uint256 liquidationLTV;
}

struct RewardUserInfo {
    uint256 timestamp;
    uint256 blockNumber;
    address account;
    address vault;
    address balanceTracker;
    bool balanceForwarderEnabled;
    uint256 balance;
    EnabledRewardInfo[] enabledRewardsInfo;
}

struct EnabledRewardInfo {
    address reward;
    uint256 earnedReward;
    uint256 earnedRewardRecentForfeited;
}

struct RewardInfo {
    uint256 timestamp;
    uint256 blockNumber;
    address vault;
    address reward;
    address balanceTracker;
    uint256 epochDuration;
    uint256 currentEpoch;
    uint256 totalRewardEligible;
    uint256 totalRewardRegistered;
    uint256 totalRewardClaimed;
    RewardAmountInfo[] epochInfoPrevious;
    RewardAmountInfo[] epochInfoUpcoming;
}

struct RewardAmountInfo {
    uint256 epoch;
    uint256 epochStart;
    uint256 epochEnd;
    uint256 rewardAmount;
}
