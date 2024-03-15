// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {EthereumVaultConnector as EVC} from "ethereum-vault-connector/EthereumVaultConnector.sol";
import {ESR} from "../../../../src/ESR/ESR.sol";
import {MockToken} from "./MockToken.sol";

// TODO test when 0 deposits for edge cases

contract ESRTest is Test {
    EVC public evc;
    ESR public esr;
    MockToken public asset;

    address public distributor = makeAddr("distributor");
    address public user = makeAddr("user");

    string public constant NAME = "Euler Savings Rate";
    string public constant SYMBOL = "ESR";

    function setUp() public {
        asset = new MockToken();
        evc = new EVC();
        esr = new ESR(evc, address(asset), NAME, SYMBOL);

        // Set a non zero timestamp
        vm.warp(420);
    }

    // utils
    function doDeposit(address from, uint256 amount) public {
        asset.mint(from, amount);

        vm.startPrank(from);
        asset.approve(address(esr), amount);
        esr.deposit(amount, from);
        vm.stopPrank();
    }
}