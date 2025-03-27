// SPDX-License-Identifier: No License
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";

abstract contract ItemNFT is ERC721, Ownable {
    uint256 private _nextTokenId;
    
    string private _baseTokenURI;

    constructor(string memory baseURI) ERC721("Cap", "Cap") {
        _baseTokenURI = baseURI;
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        _baseTokenURI = baseURI;
    }

    function _mintItemNFT(address to) internal {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
    }

    function tokenURI(uint256 tokenId) override public view returns (string memory) {
        return string(
        abi.encodePacked(
            _baseURI(),
            Strings.toString(0),
            ".json"
        )
        );
    }
}
