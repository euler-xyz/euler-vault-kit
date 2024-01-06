// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

interface IRiskManager {
    struct MarketAssets {
        address market;
        uint256 assets;
        bool assetsSet;
    }

    struct Snapshot {
        uint256 totalBalances;
        uint256 totalBorrows;
    }

    function onMarketActivation(address creator, address market, address asset, bytes calldata riskManagerConfig)
        external
        returns (bool success);
    function calculateLiquidation(
        address liquidator,
        address violator,
        address collateral,
        MarketAssets[] calldata collaterals,
        MarketAssets calldata liability,
        uint256 desiredRepayAssets
    )
        external
        view
        returns (uint256 repayAssets, uint256 yieldBalance, uint256 feeAssets, bytes memory accountSnapshot);
    function verifyLiquidation(
        address liquidator,
        address violator,
        address collateral,
        uint256 yieldBalance,
        uint256 repayAssets,
        MarketAssets[] calldata collaterals,
        MarketAssets calldata liability,
        bytes memory accountSnapshot
    ) external view returns (bool isValid);

    function checkAccountStatus(address account, MarketAssets[] calldata collaterals, MarketAssets calldata liability)
        external;
    function checkMarketStatus(uint8 performedOperations, Snapshot memory oldSnapshot, Snapshot memory currentSnapshot)
        external;

    function computeInterestParams(address asset, uint32 utilisation)
        external
        returns (int96 interestRate, uint16 interestFee);
}
