// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVault} from "src/EVault/EVault.sol";
import {EVaultDeployerDefault} from "test/common/EVaultDeployerDefault.sol";
import "forge-std/console2.sol";

contract EVaultHandler is EVaultDeployerDefault {
    uint256 public constant DEAL_AMOUNT = 100 ether;
    uint256 public ghost_numCalls;
    uint256 public ghost_assetTST1Balance;
    uint256 public ghost_eTST1Balance;

    function setUp() public override {
        console2.log("setup start");
        EVaultDeployerDefault.setUp();
        assetTST1.mint(address(this), DEAL_AMOUNT);
        assetTST1.approve(address(eTST1), type(uint256).max);
    }

    function deposit(uint256 amount) public {
        amount = bound(amount, 0, assetTST1.balanceOf(address(this)));
        uint256 sharesReceived = eTST1.deposit(amount, address(this));
        console2.log("sharesReceived: ", sharesReceived);
        // ----------- ghost updates -----------
        ghost_numCalls++;
        ghost_assetTST1Balance -= amount;
        ghost_eTST1Balance += sharesReceived;
    }

    function redeem(uint256 amount) public {
        amount = bound(amount, 0, ghost_eTST1Balance);
        uint256 assetsReceived = eTST1.redeem(amount, address(this), address(this));
        console2.log("assetsReceived: ", assetsReceived);
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
