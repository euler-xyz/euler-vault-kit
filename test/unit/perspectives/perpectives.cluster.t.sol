// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ClusterPerspective} from "src/Perspectives/ClusterPerspective.sol";
import {EscrowPerspective} from "src/Perspectives/EscrowPerspective.sol";
import {PerspectiveErrors} from "src/Perspectives/PerspectiveErrors.sol";
import "src/ProductLines/Escrow.sol";
import "../evault/EVaultTestBase.t.sol";

contract Perspective_Cluster is EVaultTestBase, PerspectiveErrors {
    event PerspectiveVerified(address indexed vault);

    EscrowPerspective escrowPerspective;
    ClusterPerspective clusterPerspective1;
    ClusterPerspective clusterPerspective2;
    ClusterPerspective clusterPerspective3;

    address vaultEscrow;
    address vaultCluster1;
    address vaultCluster2;
    address vaultCluster3;

    function setUp() public override {
        super.setUp();
        escrowPerspective = new EscrowPerspective(address(factory));
        clusterPerspective1 = new ClusterPerspective(address(factory), new address[](0), true);

        address[] memory recognizedCollateralPerspectives = new address[](1);
        recognizedCollateralPerspectives[0] = address(escrowPerspective);
        clusterPerspective2 = new ClusterPerspective(address(factory), recognizedCollateralPerspectives, false);

        recognizedCollateralPerspectives = new address[](2);
        recognizedCollateralPerspectives[0] = address(escrowPerspective);
        recognizedCollateralPerspectives[1] = address(clusterPerspective1);
        clusterPerspective3 = new ClusterPerspective(address(factory), recognizedCollateralPerspectives, false);

        vaultEscrow = escrowProductLine.createVault(address(assetTST));
        vaultCluster1 = factory.createProxy(false, abi.encodePacked(address(assetTST), address(1), address(2)));
        vaultCluster2 = factory.createProxy(false, abi.encodePacked(address(assetTST2), address(1), address(2)));
        vaultCluster3 = factory.createProxy(false, abi.encodePacked(address(assetTST2), address(1), address(2)));

        IEVault(vaultCluster1).setName("Cluster vault: Test Token");
        IEVault(vaultCluster1).setSymbol("eTST");
        IEVault(vaultCluster1).setLTV(vaultCluster2, 0, 0);
        IEVault(vaultCluster1).setGovernorAdmin(address(0));

        IEVault(vaultCluster2).setName("Cluster vault: Test Token 2");
        IEVault(vaultCluster2).setSymbol("eTST2");
        IEVault(vaultCluster2).setLTV(vaultCluster1, 0, 0);
        IEVault(vaultCluster2).setGovernorAdmin(address(0));

        IEVault(vaultCluster3).setName("Cluster vault: Test Token 2");
        IEVault(vaultCluster3).setSymbol("eTST2");
        IEVault(vaultCluster3).setLTV(vaultEscrow, 0, 0);
        IEVault(vaultCluster3).setGovernorAdmin(address(0));

        vm.label(address(escrowPerspective), "escrowPerspective");
        vm.label(address(clusterPerspective1), "clusterPerspective1");
        vm.label(address(clusterPerspective2), "clusterPerspective2");
        vm.label(address(clusterPerspective3), "clusterPerspective3");
        vm.label(vaultEscrow, "vaultEscrow");
        vm.label(vaultCluster1, "vaultCluster1");
        vm.label(vaultCluster2, "vaultCluster2");
        vm.label(vaultCluster3, "vaultCluster3");
    }

    function test_Perspective_Cluster() public {
        uint256 snapshot = vm.snapshot();

        // verifies that the vault cluster 1 belongs to the cluster perspective 1.
        // while verifying the vault cluster 1, the cluster perspective 1 will also verify the vault cluster 2 as they reference each other
        vm.expectEmit(true, false, false, false, address(clusterPerspective1));
        emit PerspectiveVerified(vaultCluster2);
        vm.expectEmit(true, false, false, false, address(clusterPerspective1));
        emit PerspectiveVerified(vaultCluster1);
        clusterPerspective1.perspectiveVerify(vaultCluster1, true);
        clusterPerspective1.perspectiveVerify(vaultCluster2, true);
        assertTrue(clusterPerspective1.isVerified(vaultCluster1));
        assertTrue(clusterPerspective1.isVerified(vaultCluster2));
        assertEq(clusterPerspective1.verifiedArray()[0], vaultCluster2);
        assertEq(clusterPerspective1.verifiedArray()[1], vaultCluster1);

        // verification of the escrow vault will fail right away if verified by the cluster perspective 1
        vm.expectRevert(
            abi.encodeWithSelector(PerspectiveError.selector, address(clusterPerspective1), vaultEscrow, ERROR__ORACLE)
        );
        clusterPerspective1.perspectiveVerify(vaultEscrow, true);

        // verifies that the vault cluster 3 belongs to the cluster perspective 2.
        // while verifying the vault cluster 3, the escrow perspective will also verify the vault escrow
        vm.expectEmit(true, false, false, false, address(escrowPerspective));
        emit PerspectiveVerified(vaultEscrow);
        vm.expectEmit(true, false, false, false, address(clusterPerspective2));
        emit PerspectiveVerified(vaultCluster3);
        clusterPerspective2.perspectiveVerify(vaultCluster3, true);
        assertTrue(escrowPerspective.isVerified(vaultEscrow));
        assertTrue(clusterPerspective2.isVerified(vaultCluster3));
        assertEq(escrowPerspective.verifiedArray()[0], vaultEscrow);
        assertEq(clusterPerspective2.verifiedArray()[0], vaultCluster3);
        assertEq(escrowPerspective.assetLookup(address(assetTST)), vaultEscrow);

        // verification of the vault cluster 3 will fail right away if verified by the escrow perspective
        vm.expectRevert(
            abi.encodeWithSelector(
                PerspectiveError.selector, address(escrowPerspective), vaultCluster3, ERROR__TRAILING_DATA
            )
        );
        escrowPerspective.perspectiveVerify(vaultCluster3, true);

        // verifies that the vaults cluster 1, 2 and 3 belong to the cluster perspective 3.
        clusterPerspective3.perspectiveVerify(vaultCluster1, true);
        clusterPerspective3.perspectiveVerify(vaultCluster2, true);
        clusterPerspective3.perspectiveVerify(vaultCluster3, true);

        // revert to the initial state
        vm.revertTo(snapshot);

        // impersonate the governor to modify vault cluster 3
        vm.prank(address(0));
        IEVault(vaultCluster3).setLTV(vaultCluster2, 0, 0);

        // verifies that the vault cluster 3 still belongs to the cluster perspective 3, even with an additional collateral
        clusterPerspective3.perspectiveVerify(vaultCluster3, true);

        // meanwhile, other vaults got verified too
        assertTrue(clusterPerspective3.isVerified(vaultCluster3));
        assertTrue(escrowPerspective.isVerified(vaultEscrow));
        assertTrue(clusterPerspective1.isVerified(vaultCluster1));
        assertTrue(clusterPerspective1.isVerified(vaultCluster2));
    }
}
