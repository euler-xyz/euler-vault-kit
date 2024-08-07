// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;
// import {IERC20} from "../../lib/ethereum-vault-connector/lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../../certora/harness/AbstractBaseHarness.sol";
import "../../src/EVault/modules/Vault.sol";
import "../../src/EVault/modules/Token.sol";
// import "../../src/EVault/shared/types/Types.sol";

contract ERC4626Harness is VaultModule, TokenModule, AbstractBaseHarness {
    constructor(Integrations memory integrations) Base(integrations) {}

    // Linked against DummyERC20A in verification config
    IERC20 underlying_asset;

    function userAssets(address user) public view returns (uint256) { // harnessed
        // The assets in the underlying asset contract (not in the vault)
        return IERC20(asset()).balanceOf(user); 
        // The assets stored in the vault for a user.
        // return vaultStorage.users[user].getBalance().toAssetsDown(loadVault()).toUint();
    }

    function toSharesExt(uint256 amount) external view returns (uint256) {
        require(amount < MAX_SANE_AMOUNT, "Assets are really uint112");
        VaultCache memory vaultCache = loadVault();
        return Assets.wrap(uint112(amount)).toSharesDownUint(vaultCache);
    }

    function cache_cash() public view returns (Assets) {
        return loadVault().cash;
    }

}
