// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ESVaultTestBase, ESVault} from "./ESVaultTestBase.t.sol";


contract ESVaultDisabledTest is ESVaultTestBase {
    function test_disabled_loop() public {
        vm.expectRevert(ESVault.NOT_SUPPORTTED.selector);
        eTST.loop(1e18, address(this));
    }

    function test_disabled_deloop() public {
        vm.expectRevert(ESVault.NOT_SUPPORTTED.selector);
        eTST.deloop(1e18, address(this));
    }

    function test_disabled_deposit() public {
        vm.expectRevert(ESVault.NOT_SUPPORTTED.selector);
        eTST.deposit(1e18, address(this));
    }

    function test_disabled_mint() public {
        vm.expectRevert(ESVault.NOT_SUPPORTTED.selector);
        eTST.mint(1e18, address(this));
    }

    function test_disabled_withdraw() public {
        vm.expectRevert(ESVault.NOT_SUPPORTTED.selector);
        eTST.withdraw(1e18, address(this), address(this));
    }

    function test_disabled_redeem() public {
        vm.expectRevert(ESVault.NOT_SUPPORTTED.selector);
        eTST.redeem(1e18, address(this), address(this));
    }

    function test_disabled_skim() public {
        vm.expectRevert(ESVault.NOT_SUPPORTTED.selector);
        eTST.skim(1e18, address(this));
    }
}