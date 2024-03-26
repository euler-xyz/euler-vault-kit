// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./TestERC20.sol";
import "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";
import "./FixedPointMathLib.sol";
import {IERC20} from "../../EVault/IEVault.sol";

/**
 * @notice Vault behaviours can be set by calling configure()
 */
contract TestERC4626 is TestERC20 {
    using FixedPointMathLib for uint256;

    IEVC evc;
    IERC20 public asset;

    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);

    event Withdraw(
        address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
    );

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        bool secureMode_,
        address evc_,
        address asset_
    ) TestERC20(name_, symbol_, decimals_, secureMode_) {
        evc = IEVC(evc_);
        asset = IERC20(asset_);
    }

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/

    function deposit(uint256 assets, address receiver) public virtual returns (uint256 shares) {
        require((shares = previewDeposit(assets)) != 0, "ZERO_SHARES");
        address account = getAccount();

        IERC20(asset).transferFrom(account, address(this), assets);

        _mint(receiver, shares);

        emit Deposit(account, receiver, assets, shares);
    }

    function mint(uint256 shares, address receiver) public virtual returns (uint256 assets) {
        assets = previewMint(shares);
        address account = getAccount();

        IERC20(asset).transferFrom(account, address(this), assets);

        _mint(receiver, shares);

        emit Deposit(account, receiver, assets, shares);
    }

    function withdraw(uint256 assets, address receiver, address owner) public virtual returns (uint256 shares) {
        shares = previewWithdraw(assets);
        address account = getAccount();

        if (account != owner) {
            uint256 allowed = allowance[owner][account];

            if (allowed != type(uint256).max) allowance[owner][account] = allowed - shares;
        }

        _burn(owner, shares);

        emit Withdraw(account, receiver, owner, assets, shares);

        IERC20(asset).transfer(receiver, assets);

        evc.requireAccountStatusCheck(account);
    }

    function redeem(uint256 shares, address receiver, address owner) public virtual returns (uint256 assets) {
        address account = getAccount();
        if (account != owner) {
            uint256 allowed = allowance[owner][account];

            if (allowed != type(uint256).max) allowance[owner][account] = allowed - shares;
        }

        require((assets = previewRedeem(shares)) != 0, "ZERO_ASSETS");

        _burn(owner, shares);

        emit Withdraw(account, receiver, owner, assets, shares);

        IERC20(asset).transfer(receiver, assets);

        evc.requireAccountStatusCheck(account);
    }

    /*//////////////////////////////////////////////////////////////
                            TRANSFER OVERRIDES
    //////////////////////////////////////////////////////////////*/

    function transferFrom(address from, address to, uint256 amount) public override {
        super.transferFrom(from, to, amount);
        evc.requireAccountStatusCheck(from);
    }

    /*//////////////////////////////////////////////////////////////
                            ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    function convertToShares(uint256 assets) public view virtual returns (uint256) {
        return totalSupply == 0 ? assets : assets.mulDivDown(totalSupply, totalAssets());
    }

    function convertToAssets(uint256 shares) public view virtual returns (uint256) {
        return totalSupply == 0 ? shares : shares.mulDivDown(totalAssets(), totalSupply);
    }

    function previewDeposit(uint256 assets) public view virtual returns (uint256) {
        return convertToShares(assets);
    }

    function previewMint(uint256 shares) public view virtual returns (uint256) {
        return totalSupply == 0 ? shares : shares.mulDivUp(totalAssets(), totalSupply);
    }

    function previewWithdraw(uint256 assets) public view virtual returns (uint256) {
        return totalSupply == 0 ? assets : assets.mulDivUp(totalSupply, totalAssets());
    }

    function previewRedeem(uint256 shares) public view virtual returns (uint256) {
        return convertToAssets(shares);
    }

    /*//////////////////////////////////////////////////////////////
                     DEPOSIT/WITHDRAWAL LIMIT LOGIC
    //////////////////////////////////////////////////////////////*/

    function maxDeposit(address) public view virtual returns (uint256) {
        return type(uint256).max;
    }

    function maxMint(address) public view virtual returns (uint256) {
        return type(uint256).max;
    }

    function maxWithdraw(address owner) public view virtual returns (uint256) {
        return convertToAssets(balances[owner]);
    }

    function maxRedeem(address owner) public view virtual returns (uint256) {
        return balances[owner];
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(address to, uint256 amount) internal virtual {
        totalSupply += amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balances[to] += amount;
        }

        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal virtual {
        balances[from] -= amount;

        // Cannot underflow because a user's balance
        // will never be larger than the total supply.
        unchecked {
            totalSupply -= amount;
        }

        emit Transfer(from, address(0), amount);
    }

    function totalAssets() public view returns (uint256) {
        return asset.balanceOf(address(this));
    }

    /*//////////////////////////////////////////////////////////////
                        EVC and test helpers
    //////////////////////////////////////////////////////////////*/

    function getAccount() internal view override returns (address) {
        if (msg.sender == address(evc)) {
            (address onBehalfOfAccount,) = evc.getCurrentOnBehalfOfAccount(address(0));
            return onBehalfOfAccount;
        } else {
            return msg.sender;
        }
    }
}
