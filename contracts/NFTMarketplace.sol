// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

error NFTMarketplace_PriceMustBeAboveZero();
error NFTMarketplace_NotApprovedForMarketplace();
error NFTMarketplace_AlreadyListed(address nftAddress, uint256 tokenId);
error NFTMarketplace_NotOwner();
error NFTMarketplace_NotListed(address nftAddress,uint256 tokenId);
error NFTMarketplace_PriceNotMet(address nftAddress,uint256 tokenId,uint256 price);
error NFTMarketplace_TransferFailed();
error NFTMarketplace_NoProceeds();

contract NFTMarketplace is ReentrancyGuard{
    
    struct Listing{
        uint256 price;
        address seller;
    }

    // NFT Contract address -> NFT TokenId -> Listing
    mapping(address => mapping(uint256=>Listing)) private s_listings;
    // Seller address -> Amount earned
    mapping(address => uint256) private s_proceeds;

    modifier notListed(address nftAddress, uint256 tokenId,address owner){
        Listing memory listing = s_listings[nftAddress][tokenId];
        if(listing.price > 0){
            revert NFTMarketplace_AlreadyListed(nftAddress, tokenId);
        }
        _;
    }

    modifier isOwner(address nftAddress,uint256 tokenId,address sender){
        IERC721 nft = IERC721(nftAddress);
        address owner = nft.ownerOf(tokenId);
        if(owner != msg.sender){
            revert NFTMarketplace_NotOwner();
        }
        _;
    }

    modifier isListed(address nftAddress,uint256 tokenId){
        Listing memory listing = s_listings[nftAddress][tokenId];
        if(listing.price <=0 ){
            revert NFTMarketplace_NotListed(nftAddress,tokenId);
        }
        _;
    }

    event ItemListed(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );
    event ItemBought(
        address indexed buyer,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );
    event ItemCancelled(
        address indexed sender,
        address indexed nftAddress,
        uint256 indexed tokenId
    );

    /*
    * @notice Mothod of listing your NFT to the marketplace
    * @param nftAddress: Address of the NFT
    * @param tokenId: The tokenId ofthe NFT
    * @param price: sale price of the listed NFT
    * @dev Technically, we could have the contract be the escrow for the 
    NFTs this way prople can still hold their NFTs when listed 
    */
    function listItem(
    address nftAddress,
    uint256 tokenId,
    uint256 price
    ) external notListed(nftAddress,tokenId,msg.sender)
    isOwner(nftAddress,tokenId,msg.sender){
        if(price<=0){
          revert NFTMarketplace_PriceMustBeAboveZero();
        }
        IERC721 nft = IERC721(nftAddress);
        if(nft.getApproved(tokenId) != address(this)){
          revert NFTMarketplace_NotApprovedForMarketplace();
        }
        s_listings[nftAddress][tokenId] = Listing(price,msg.sender);
        emit ItemListed(msg.sender,nftAddress,tokenId,price);
    }

    function buyItem(
     address nftAddress,
     uint256 tokenId) 
    external payable nonReentrant
    isListed(nftAddress,tokenId){
      Listing memory listedItem = s_listings[nftAddress][tokenId];
      if(msg.value <= listedItem.price){
          revert NFTMarketplace_PriceNotMet(nftAddress,tokenId,listedItem.price);
      }
      s_proceeds[listedItem.seller] += msg.value;
      delete(s_listings[nftAddress][tokenId]);
      IERC721(nftAddress).safeTransferFrom(listedItem.seller,msg.sender,tokenId);
      emit ItemBought(msg.sender,nftAddress,tokenId,listedItem.price);
    }

    function cancelListing(address nftAddress,uint256 tokenId)
    external
    isOwner(nftAddress,tokenId,msg.sender)
    isListed(nftAddress,tokenId){
        delete(s_listings[nftAddress][tokenId]);
        emit ItemCancelled(msg.sender,nftAddress,tokenId); 
    }

    function updateListing(address nftAddress,uint256 tokenId,uint256 newPrice)
    external
    isOwner(nftAddress,tokenId,msg.sender)
    isListed(nftAddress,tokenId){
        s_listings[nftAddress][tokenId].price = newPrice;
        emit ItemListed(msg.sender,nftAddress,tokenId,newPrice);
    }

    function withdrawProceeds() external {
        uint256 proceeds = s_proceeds[msg.sender];
        if(proceeds<=0){
            revert NFTMarketplace_NoProceeds();
        }
        s_proceeds[msg.sender] = 0;
        (bool success,) = payable(msg.sender).call{value: proceeds}("");
        if(!success){
            revert NFTMarketplace_TransferFailed();
        }
    }

    function getListing(address nftAddress,uint256 tokenId) external view returns(Listing memory){
        return s_listings[nftAddress][tokenId];
    }

    function getProceeds(address seller) external view returns(uint256){
        return s_proceeds[seller];
    }
}
contract Lock {
    uint public unlockTime;
    address payable public owner;

    event Withdrawal(uint amount, uint when);

    constructor(uint _unlockTime) payable {
        require(
            block.timestamp < _unlockTime,
            "Unlock time should be in the future"
        );

        unlockTime = _unlockTime;
        owner = payable(msg.sender);
    }

    function withdraw() public {
        // Uncomment this line, and the import of "hardhat/console.sol", to print a log in your terminal
        // console.log("Unlock time is %o and block timestamp is %o", unlockTime, block.timestamp);

        require(block.timestamp >= unlockTime, "You can't withdraw yet");
        require(msg.sender == owner, "You aren't the owner");

        emit Withdrawal(address(this).balance, block.timestamp);

        owner.transfer(address(this).balance);
    }
}
