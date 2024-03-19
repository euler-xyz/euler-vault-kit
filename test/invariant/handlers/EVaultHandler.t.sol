// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVault} from "src/EVault/EVault.sol";
import {EVaultDeployerDefault} from "test/common/EVaultDeployerDefault.sol";
import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import "forge-std/console2.sol";

contract EVaultHandler is EVaultDeployerDefault {
    uint256 public constant DEAL_AMOUNT = 100 ether;
    uint256 public constant MAX_SANE_AMOUNT = type(uint112).max;
    uint256 public ghost_numCalls;
    uint256 public ghost_assetTST1Balance;
    uint256 public ghost_eTST1Balance;

    constructor() {
        deployEVaultWithFactory();
        assetTST1.mint(address(this), DEAL_AMOUNT);
        ghost_assetTST1Balance = assetTST1.balanceOf(address(this));
        assetTST1.approve(address(eTST1), type(uint256).max);
    }

    function deposit(uint256 amount) public {
        uint256 balanceOfAssetTST1 = assetTST1.balanceOf(address(this));
        uint256 maxPossibleAmount = Math.min(balanceOfAssetTST1, MAX_SANE_AMOUNT);
        amount = bound(amount, 0, maxPossibleAmount);

        uint256 sharesReceived = eTST1.deposit(amount, address(this));
        // ----------- ghost updates -----------
        ghost_numCalls++;
        ghost_assetTST1Balance -= amount;
        ghost_eTST1Balance += sharesReceived;
    }

    function redeem(uint256 amount) public {
        uint256 maxPossibleAmount = Math.min(eTST1.balanceOf(address(this)), MAX_SANE_AMOUNT);
        amount = bound(amount, 0, maxPossibleAmount);
        uint256 assetsReceived = eTST1.redeem(amount, address(this), address(this));
        // ----------- ghost updates -----------
        ghost_numCalls++;
        ghost_assetTST1Balance += assetsReceived;
        ghost_eTST1Balance -= amount;
    }

    // function withdraw(uint256 amount) {
    //     uint256 eTST1Balance = eTST1.balanceOf(address(this));
    //     uint256 assetsAmount = eTST1.convertToAssets(eTST1Balance);
    //     amount = bound(amount, 0, assetsAmount);
    //     ghost_numCalls++;
    //     ghost_assetTST1Balance += amount;
    //     eTST1.withdraw(amount, receiver);
    // }
}
