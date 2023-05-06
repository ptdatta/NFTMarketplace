// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract BasicNFT is ERC721 {

    string public constant TOKEN_URI="https://ipfs.io/ipfs/QmYonBWLi3yG7JamYcMoWtwkSdy2REFzRgVW79qSZuiZu5?filename=Avatar.json";
    uint256 private s_tokenCounter;

    constructor() ERC721("Robo Cat","RCAT"){
        s_tokenCounter = 0;
    }

    function mint() public{
        _safeMint(msg.sender,s_tokenCounter);
        s_tokenCounter+=1;
    }

    function tokenURI(uint256 tokenId) public view override returns(string memory){
        return TOKEN_URI;
    }

    function getCount() public view returns(uint256){
        return s_tokenCounter;
    }


} 