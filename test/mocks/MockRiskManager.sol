// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

interface IRiskManager {
    struct MarketAssets {
        address market;
        uint assets;
        bool assetsSet;
    }

    struct Snapshot {
        uint112 totalBalances;
        uint112 totalBorrows;
    }
}

contract MockRiskManager is IRiskManager {
    constructor() {
    }

    function onMarketActivation(address, address, address, bytes calldata) external pure returns (bool success) {
        success = true;
    }

    function checkLiquidity(address /*account*/, MarketAssets[] calldata /*collaterals*/, MarketAssets calldata /*liability*/) external pure returns (bool healthy) {
		return true;
	}

	function checkMarketStatus(uint8 /*performedOperations*/, Snapshot memory /*oldSnapshot*/, Snapshot memory /*currentSnapshot*/) external pure returns (bool healthy, bytes memory notHealthyReason) {
		return (true, "");
	}

	function computeInterestParams(address /*asset*/, uint32 /*utilisation*/) external pure returns (int96 interestRate, uint16 interestFee) {
		return (0, 0);
	}
}

contract MockRiskManagerFail {
    constructor() {
    }

    function onMarketActivation(address, address, address, bytes calldata) external pure returns (bool success) {
        success = false;
    }
}
