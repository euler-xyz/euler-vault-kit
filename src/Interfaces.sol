// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;


interface IERC20 {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);
}

interface IERC4626 is IERC20 {
    event Deposit(address indexed sender, address indexed owner, uint assets, uint shares);
    event Withdraw(
        address indexed sender,
        address indexed receiver,
        address indexed owner,
        uint assets,
        uint shares
    );

    function asset() external view returns (address);
    function totalAssets() external view returns (uint);
    function convertToShares(uint assets) external view returns (uint);
    function convertToAssets(uint shares) external view returns (uint);
    function maxDeposit(address receiver) external view returns (uint);
    function previewDeposit(uint assets) external view returns (uint);
    function deposit(uint assets, address receiver) external returns (uint);
    function maxMint(address receiver) external view returns (uint);
    function previewMint(uint shares) external view returns (uint);
    function mint(uint shares, address receiver) external returns (uint);
    function maxWithdraw(address owner) external view returns (uint);
    function previewWithdraw(uint assets) external view returns (uint);
    function withdraw(uint assets, address receiver, address owner) external returns (uint);
    function maxRedeem(address owner) external view returns (uint);
    function previewRedeem(uint shares) external view returns (uint);
    function redeem(uint shares, address receiver, address owner) external returns (uint);
}

interface IERC20Permit {
    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;
    function permit(address holder, address spender, uint nonce, uint expiry, bool allowed, uint8 v, bytes32 r, bytes32 s) external;
    function permit(address owner, address spender, uint value, uint deadline, bytes calldata signature) external;
}

interface IERC3156FlashBorrower {
    function onFlashLoan(address initiator, address token, uint amount, uint fee, bytes calldata data) external returns (bytes32);
}

interface IERC3156FlashLender {
    function maxFlashLoan(address token) external view returns (uint);
    function flashFee(address token, uint amount) external view returns (uint);
    function flashLoan(IERC3156FlashBorrower receiver, address token, uint amount, bytes calldata data) external returns (bool);
}
