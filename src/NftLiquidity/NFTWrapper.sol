// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../Synths/ESynth.sol";

contract NFTWrapper {

    IERC721 public nft;
    ESynth public synth;

    constructor(address _nft, address _synth) {
        nft = IERC721(nft);
        synth = ESynth(synth);
    }

    function wrap(uint256 tokenId, address to) public {
        nft.transferFrom(msg.sender, address(this), tokenId);
        synth.mint(to, 1e18);
    }

    function unwrap(uint256 tokenId, address to) public {
        synth.burn(msg.sender, 1e18);
        nft.transferFrom(address(this), to, tokenId);
    }


}