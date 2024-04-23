// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;
// import {IERC20} from "../../lib/ethereum-vault-connector/lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../../certora/harness/AbstractBaseHarness.sol";
import "../../src/EVault/modules/Vault.sol";
import "../../src/EVault/modules/Token.sol";

contract ERC4626Harness is VaultModule, TokenModule, AbstractBaseHarness {
    constructor(Integrations memory integrations) Base(integrations) {}

    // Linked against DummyERC20A in verification config
    IERC20 underlying_asset;

    function totalAssets() public view override returns (uint256) {
        return underlying_asset.balanceOf(address(this));
    }

    function userAssets(address user) public view returns (uint256) { // harnessed
        return IERC20(asset()).balanceOf(user);
    }

    function asset() public view override virtual returns (address) {
        return address(underlying_asset);
    }
}
