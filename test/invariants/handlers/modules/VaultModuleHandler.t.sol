// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Test Contracts
import {Actor} from "../../utils/Actor.sol";
import {BaseHandler} from "../../base/BaseHandler.t.sol";

// Interfaces
import {IERC4626} from "src/EVault/IEVault.sol";

/// @title VaultModuleHandler
/// @notice Handler test contract for the generic ERC4626 vault actions
contract VaultModuleHandler is BaseHandler {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      STATE VARIABLES                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           ACTIONS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function deposit(uint256 assets, address receiver) external setup {
        bool success;
        bytes memory returnData;

        address target = address(eTST);

        uint256 previewedShares = eTST.previewDeposit(assets);

        _approve(address(eTST.asset()), actor, target, assets);

        _before();
        (success, returnData) =
            actor.proxy(target, abi.encodeWithSelector(IERC4626.deposit.selector, assets, receiver));

        if (success) {
            _after();

            uint256 shares = abi.decode(returnData, (uint256));

            _increaseGhostAssets(target, assets, address(receiver));
            _increaseGhostShares(target, shares, address(receiver));

            assertLe(previewedShares, shares, "ERC4626_deposit_invariantB");
        }
    }

    function depositToActor(uint256 assets, uint256 i) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address receiver = _getRandomActor(i);

        address target = address(eTST);

        uint256 previewedShares = eTST.previewDeposit(assets);

        _before();
        (success, returnData) =
            actor.proxy(target, abi.encodeWithSelector(IERC4626.deposit.selector, assets, receiver));

        if (success) {
            _after();

            uint256 shares = abi.decode(returnData, (uint256));

            _increaseGhostAssets(target, assets, address(receiver));
            _increaseGhostShares(target, shares, address(receiver));

            assertLe(previewedShares, shares, "ERC4626_deposit_invariantB: ");
        }
    }

    function mint(uint256 shares, address receiver) external setup {
        bool success;
        bytes memory returnData;

        address target = address(eTST);

        uint256 previewedAssets = eTST.previewMint(shares);

        _before();
        (success, returnData) =
            actor.proxy(target, abi.encodeWithSelector(IERC4626.mint.selector, shares, receiver));

        if (success) {
            _after();

            uint256 assets = abi.decode(returnData, (uint256));

            _increaseGhostAssets(target, assets, address(receiver));
            _increaseGhostShares(target, shares, address(receiver));

            assertGe(previewedAssets, assets, "ERC4626_mint_invariantB");
        }
    }

    function mintToActor(uint256 shares, uint256 i) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address receiver = _getRandomActor(i);

        address target = address(eTST);

        uint256 previewedAssets = eTST.previewMint(shares);

        _before();
        (success, returnData) =
            actor.proxy(target, abi.encodeWithSelector(IERC4626.mint.selector, shares, receiver));

        if (success) {
            _after();

            uint256 assets = abi.decode(returnData, (uint256));

            _increaseGhostAssets(target, assets, address(receiver));
            _increaseGhostShares(target, shares, address(receiver));

            assertGe(previewedAssets, assets, "ERC4626_mint_invariantB");
        }
    }

    function withdraw(uint256 assets, address receiver) external setup {
        bool success;
        bytes memory returnData;

        address target = address(eTST);

        uint256 previewedShares = eTST.previewWithdraw(assets);

        _before();
        (success, returnData) = actor.proxy(
            target, abi.encodeWithSelector(IERC4626.withdraw.selector, assets, receiver, address(actor))
        );

        if (success) {
            _after();

            uint256 shares = abi.decode(returnData, (uint256));

            _decreaseGhostAssets(target, assets, address(actor));
            _decreaseGhostShares(target, shares, address(actor));

            assertGe(previewedShares, shares, "ERC4626_withdraw_invariantB");
        }
    }

    function redeem(uint256 shares, address receiver) external setup {
        bool success;
        bytes memory returnData;

        address target = address(eTST);

        uint256 previewedAssets = eTST.previewRedeem(shares);

        _before();
        (success, returnData) = actor.proxy(
            target, abi.encodeWithSelector(IERC4626.redeem.selector, shares, receiver, address(actor))
        );

        if (success) {
            _after();

            uint256 assets = abi.decode(returnData, (uint256));

            _decreaseGhostAssets(target, assets, address(actor));
            _decreaseGhostShares(target, shares, address(actor));

            assertLe(previewedAssets, assets, "ERC4626_redeem_invariantB");
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                     ROUNDTRIP PROPERTIES                                  //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function assert_ERC4626_roundtrip_invariantA(uint256 _assets) external {
        _mintAndApprove(address(eTST.asset()), address(this), address(eTST), _assets);

        uint256 shares = eTST.deposit(_assets, address(this));

        uint256 redeemedAssets = eTST.redeem(shares, address(this), address(this));

        assertLe(redeemedAssets, _assets, "ERC4626_roundtrip_invariantA");
    }

    function assert_ERC4626_roundtrip_invariantB(uint256 _assets) external {
        _mintAndApprove(address(eTST.asset()), address(this), address(eTST), _assets);

        uint256 shares = eTST.deposit(_assets, address(this));

        uint256 withdrawnShares = eTST.withdraw(_assets, address(this), address(this));

        assertGe(withdrawnShares, shares, "ERC4626_roundtrip_invariantB");
    }

    function assert_ERC4626_roundtrip_invariantC(uint256 _shares) external {
        _mintApproveAndMint(address(eTST), address(this), _shares);

        uint256 redeemedAssets = eTST.redeem(_shares, address(this), address(this));

        uint256 mintedShares = eTST.deposit(redeemedAssets, address(this));

        /// @dev restore original state to not break invariants
        eTST.redeem(mintedShares, address(this), address(this));

        assertLe(mintedShares, _shares, "ERC4626_roundtrip_invariantC");
    }

    function assert_ERC4626_roundtrip_invariantD(uint256 _shares) external {
        _mintApproveAndMint(address(eTST), address(this), _shares);

        uint256 redeemedAssets = eTST.redeem(_shares, address(this), address(this));

        uint256 depositedAssets = eTST.mint(_shares, address(this));

        /// @dev restore original state to not break invariants
        eTST.withdraw(depositedAssets, address(this), address(this));

        assertGe(
            depositedAssets, redeemedAssets, "ERC4626_roundtrip_invariantD"
        );
    }

    function assert_ERC4626_roundtrip_invariantE(uint256 _shares) external {
        _mintAndApprove(address(eTST.asset()), address(this), address(eTST), eTST.convertToAssets(_shares));

        uint256 depositedAssets = eTST.mint(_shares, address(this));

        uint256 withdrawnShares = eTST.withdraw(depositedAssets, address(this), address(this));

        assertGe(withdrawnShares, _shares, "ERC4626_roundtrip_invariantE");
    }

    function assert_ERC4626_roundtrip_invariantF(uint256 _shares) external {
        _mintAndApprove(address(eTST.asset()), address(this), address(eTST), eTST.convertToAssets(_shares));

        uint256 depositedAssets = eTST.mint(_shares, address(this));

        uint256 redeemedAssets = eTST.redeem(_shares, address(this), address(this));

        assertLe(
            redeemedAssets, depositedAssets, "ERC4626_roundtrip_invariantF"
        );
    }

    function assert_ERC4626_roundtrip_invariantG(uint256 _assets) external {
        _mintApproveAndDeposit(address(eTST), address(this), _assets);

        uint256 redeemedShares = eTST.withdraw(_assets, address(this), address(this));

        uint256 depositedAssets = eTST.mint(redeemedShares, address(this));

        /// @dev restore original state to not break invariants
        eTST.withdraw(depositedAssets, address(this), address(this));

        assertGe(depositedAssets, _assets, "ERC4626_roundtrip_invariantG");
    }

    function assert_ERC4626_roundtrip_invariantH(uint256 _assets) external {
        _mintApproveAndDeposit(address(eTST), address(this), _assets);

        uint256 redeemedShares = eTST.withdraw(_assets, address(this), address(this));

        uint256 mintedShares = eTST.deposit(_assets, address(this));

        /// @dev restore original state to not break invariants
        eTST.redeem(mintedShares, address(this), address(this));

        assertLe(mintedShares, redeemedShares, "ERC4626_assets_invariantH");
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         OWNER ACTIONS                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

/*     function setSupplyCap(uint256 newSupplyCap) external {TODO: change this for the current implementation
        // Since the owner is the deployer of the vault, we dont need to use a a proxy
        _before();
        eTST.setSupplyCap(newSupplyCap);
        _after();

        assert(true);
    } */

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    //  GHOSTS UPDATES
    function _increaseGhostAssets(address vaultAddress, uint256 assets, address receiver) internal {
        ghost_sumBalances[vaultAddress] += assets;
        ghost_sumBalancesPerUser[vaultAddress][receiver] += assets;
    }

    function _decreaseGhostAssets(address vaultAddress, uint256 assets, address owner) internal {
        ghost_sumBalances[vaultAddress] -= assets;
        ghost_sumBalancesPerUser[vaultAddress][owner] -= assets;
    }

    function _increaseGhostShares(address vaultAddress, uint256 shares, address receiver) internal {
        ghost_sumSharesBalances[vaultAddress] += shares;
        ghost_sumSharesBalancesPerUser[vaultAddress][receiver] += shares;
    }

    function _decreaseGhostShares(address vaultAddress, uint256 shares, address owner) internal {
        ghost_sumSharesBalances[vaultAddress] -= shares;
        ghost_sumSharesBalancesPerUser[vaultAddress][owner] -= shares;
    }
}
