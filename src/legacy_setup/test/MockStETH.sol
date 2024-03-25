// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MockStETH {
    bool shouldRevert = false;
    uint256 pooledEthByShares;
    uint256 sharesByPooledEth;

    function mockSetRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }

    function mockSetData(uint256 _pooledEthByShares, uint256 _sharesByPooledEth) external {
        pooledEthByShares = _pooledEthByShares;
        sharesByPooledEth = _sharesByPooledEth;
    }

    function getPooledEthByShares(uint256 _sharesAmount) external view returns (uint256) {
        if (shouldRevert) revert("");
        _sharesAmount = _sharesAmount;
        return pooledEthByShares;
    }

    function getSharesByPooledEth(uint256 _pooledEthAmount) external view returns (uint256) {
        if (shouldRevert) revert("");
        _pooledEthAmount = _pooledEthAmount;
        return sharesByPooledEth;
    }
}
