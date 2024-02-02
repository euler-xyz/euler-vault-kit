// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

interface IRiskManager {
    struct Snapshot {
        uint256 poolSize;
        uint256 totalBorrows;
    }

    struct Liability {
        address market;
        address asset;
        uint256 owed;
    }

    function activateMarket(address creator) external;

    function calculateLiquidation(
        address liquidator,
        address violator,
        address collateral,
        Liability calldata liability,
        uint256 desiredRepayAssets
    ) external view returns (uint256 repayAssets, uint256 yieldBalance, bytes memory accountSnapshot);
    function verifyLiquidation(
        address liquidator,
        address violator,
        address collateral,
        uint256 yieldBalance,
        uint256 repayAssets,
        Liability calldata liability,
        bytes memory accountSnapshot
    ) external view;

    function checkAccountStatus(address account, address[] calldata collaterals, Liability calldata liability)
        external
        view;
    function checkMarketStatus(
        address market,
        uint32 performedOperations,
        Snapshot memory oldSnapshot,
        Snapshot memory currentSnapshot
    ) external view;

    function computeInterestParams(address asset, uint32 utilisation)
        external
        returns (uint256 interestRate, uint16 interestFee);

    function marketName(address market) external view returns (string memory);
    function marketSymbol(address market) external view returns (string memory);

    function isPausedOperation(address market, uint32 operations) external view returns (bool);
    function maxDeposit(address account, address market) external view returns (uint256);
    function collateralBalanceLocked(address collateral, address account, Liability calldata liability)
        external
        view
        returns (uint256 lockedBalance);

    function feeReceiver() external view returns (address);
}
