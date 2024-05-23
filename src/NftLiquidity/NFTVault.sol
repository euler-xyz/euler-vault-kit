// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IEVC, EVCUtil} from "ethereum-vault-connector/utils/EVCUtil.sol";

contract NFTVault is ERC721, EVCUtil {
    constructor(string memory name, string memory symbol, address evc) ERC721(name, symbol) EVCUtil(evc) {}

    function deposit(address to, uint256 tokenId) public {
        safeTransferFrom(_msgSender(), address(this), tokenId, "");
        _mint(to, tokenId);
    }

    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        address from = super._update(to, tokenId, auth);
        if (from != address(0)) {
            evc.requireAccountStatusCheck(from);
        }

        return from;
    }

    function _msgSender() internal view override(Context, EVCUtil) returns(address) {
        return EVCUtil._msgSender();
    }
}