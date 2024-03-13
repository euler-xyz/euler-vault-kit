// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {console2} from "forge-std/Test.sol";
import {EVaultTestBase} from "../../EVaultTestBase.t.sol";


import "src/EVault/shared/types/Types.sol";

contract ERC4626Test_Skim is EVaultTestBase {
    using TypesLib for uint256;

    address user;

    function setUp() public override {
        super.setUp();

        user = makeAddr("user");

        assetTST.mint(user, type(uint256).max);
        hoax(user);
        assetTST.approve(address(eTST), type(uint256).max);
    }

    function test_simpleSkim() public {
        uint amount = 20e18;
        vm.startPrank(user);
        assetTST.transfer(address(eTST), amount);
        
        uint value = 1e7;

        assertEq(eTST.balanceOf(user), 0);

        uint shares = eTST.skim(value, user);

        assertEq(eTST.balanceOf(user), value);

        //assertEq(eTST.cash(), value);
    }

    function test_RevertIfInsufficientAssets() public {
        uint amount = 20e18;
        vm.startPrank(user);
        assetTST.transfer(address(eTST), amount);

        uint balance;
        uint value1 = 22e18;

        assertEq(eTST.balanceOf(user), 0);

        vm.expectRevert(Errors.E_InsufficientAssets.selector);
        eTST.skim(value1, user);

        uint vaultBalance = assetTST.balanceOf(address(eTST));
        console2.log(vaultBalance);

        uint value2 = 1e18;

        eTST.skim(value2, user);

        balance = eTST.balanceOf(user);
        console2.log(value2, balance);

        assertEq(eTST.balanceOf(user), value2); //real: 1000000000000000000 (1e18)
        
        eTST.skim(value2, user);

        uint balance1 = eTST.balanceOf(user);
        console2.log(value2, balance1);

        assertEq(eTST.balanceOf(user), value2*2); // real: 1000000000002000000000000000000
    }

    function test_zeroAmount() public {
        uint amount = 20e18;
        vm.startPrank(user);
        assetTST.transfer(address(eTST), amount);

        uint value = 0; 

        assertEq(eTST.balanceOf(user), 0);

        uint result = eTST.skim(value, user);

        assertEq(result, value);
        assertEq(eTST.balanceOf(user), value);
    }

    function test_maxAmount() public {
        uint amount = 20e18;
        vm.startPrank(user);
        assetTST.transfer(address(eTST), amount);

        uint value = type(uint256).max;

        assertEq(eTST.balanceOf(user), 0);

        uint result = eTST.skim(value, user);

        assertEq(result, amount);
        assertEq(eTST.balanceOf(user), amount);
    }

    function test_maxSaneAmount() public {
        uint amount = MAX_SANE_AMOUNT;
        vm.startPrank(user);
        assetTST.transfer(address(eTST), amount);

        uint value = MAX_SANE_AMOUNT;

        assertEq(eTST.balanceOf(user), 0);

        vm.expectRevert(Errors.E_AmountTooLargeToEncode.selector);
        eTST.skim(value + 1, user);

        uint result = eTST.skim(value, user);
        
        assertEq(result, value);
        assertEq(eTST.balanceOf(user), value);

        vm.expectRevert(Errors.E_AmountTooLargeToEncode.selector);
        eTST.skim(1, user);
    }

    function test_zeroAddressReceiver() public {
        uint amount = 20e18;
        vm.startPrank(user);
        assetTST.transfer(address(eTST), amount);

        uint value = 1e18;

        eTST.skim(value, address(0));

        assertEq(eTST.balanceOf(user), value);
    }
    
}
