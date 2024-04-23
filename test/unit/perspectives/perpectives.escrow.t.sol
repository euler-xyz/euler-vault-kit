// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EscrowPerspective} from "src/Perspectives/EscrowPerspective.sol";
import {PerspectiveErrors} from "src/Perspectives/PerspectiveErrors.sol";
import "src/ProductLines/Escrow.sol";
import "../evault/EVaultTestBase.t.sol";

contract Perspective_Escrow is EVaultTestBase, PerspectiveErrors {
    event PerspectiveVerified(address indexed vault);

    uint32 constant ESCROW_DISABLED_OPS =
        OP_BORROW | OP_REPAY | OP_LOOP | OP_DELOOP | OP_PULL_DEBT | OP_CONVERT_FEES | OP_LIQUIDATE | OP_TOUCH;

    EscrowPerspective perspective;

    function setUp() public override {
        super.setUp();
        perspective = new EscrowPerspective(address(factory));
    }

    function test_Perspective_Escrow() public {
        address vault = escrowProductLine.createVault(address(assetTST));

        vm.expectEmit(true, false, false, false, address(perspective));
        emit PerspectiveVerified(vault);
        assertTrue(perspective.perspectiveVerify(vault, true));
        assertTrue(perspective.isVerified(vault));
        assertEq(perspective.verifiedArray()[0], vault);
        assertEq(perspective.assetLookup(address(assetTST)), vault);
    }

    function test_Revert_Perspective_Escrow() public {
        address vault1 = factory.createProxy(false, abi.encodePacked(address(assetTST), address(0), address(0)));
        address vault2 = factory.createProxy(false, abi.encodePacked(address(assetTST), address(0), address(0)));
        address vault3 = factory.createProxy(true, abi.encodePacked(address(assetTST), address(1), address(2)));

        IEVault(vault1).setName("Escrow vault: Test Token");
        IEVault(vault1).setSymbol("eTST");
        IEVault(vault1).setHookConfig(address(0), ESCROW_DISABLED_OPS);
        IEVault(vault1).setGovernorAdmin(address(0));

        // this vault will violate the singleton rules
        IEVault(vault2).setName("Escrow vault: Test Token");
        IEVault(vault2).setSymbol("eTST");
        IEVault(vault2).setHookConfig(address(0), ESCROW_DISABLED_OPS);
        IEVault(vault2).setGovernorAdmin(address(0));

        // this vault will violate the singleton rules but also other ones
        IEVault(vault3).setName("Escxrow vault: Test Token");
        IEVault(vault3).setSymbol("eTSTx");
        IEVault(vault3).setLTV(address(0), 0, 0);

        // verification of the first vault is successful
        vm.expectEmit(true, false, false, false, address(perspective));
        emit PerspectiveVerified(vault1);
        assertTrue(perspective.perspectiveVerify(vault1, true));
        assertEq(perspective.assetLookup(address(assetTST)), vault1);

        // verification of the second vault will fail due to the singleton rule
        vm.expectRevert(
            abi.encodeWithSelector(PerspectiveError.selector, address(perspective), vault2, ERROR__NOT_SINGLETON)
        );
        perspective.perspectiveVerify(vault2, true);

        // verification of the third vault will fail right away due to the trailing data parameters
        vm.expectRevert(
            abi.encodeWithSelector(PerspectiveError.selector, address(perspective), vault3, ERROR__TRAILING_DATA)
        );
        perspective.perspectiveVerify(vault3, true);

        // if fail early not requested, the third vault verification will collect all the errors and fail at the end
        vm.expectRevert(
            abi.encodeWithSelector(
                PerspectiveError.selector,
                address(perspective),
                vault3,
                ERROR__TRAILING_DATA | ERROR__UPGRADABILITY | ERROR__NOT_SINGLETON | ERROR__ORACLE
                    | ERROR__UNIT_OF_ACCOUNT | ERROR__GOVERNOR | ERROR__HOOKED_OPS | ERROR__NAME | ERROR__SYMBOL
                    | ERROR__LTV_LENGTH
            )
        );
        perspective.perspectiveVerify(vault3, false);

        // if fail early not requested, the third vault verification will collect all the errors and fail at the end
        vm.expectRevert(
            abi.encodeWithSelector(PerspectiveError.selector, address(perspective), vault2, ERROR__NOT_SINGLETON)
        );
        perspective.perspectiveVerify(vault2, false);
    }
}
