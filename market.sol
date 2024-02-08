// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract NFTMarketplace is Ownable {
    using EnumerableSet for EnumerableSet.UintSet;

    struct Listing {
        address owner;
        uint256 tokenId;
        uint256 price;
        bool active;
    }

    mapping(uint256 => Listing) public listings;
    mapping(address => EnumerableSet.UintSet) private userOwnedTokens;

    IERC721 public nftContract;

    event NFTListed(uint256 indexed tokenId, address indexed owner, uint256 price);
    event NFTUnlisted(uint256 indexed tokenId);
    event NFTSold(uint256 indexed tokenId, address indexed seller, address indexed buyer, uint256 price);

    constructor(address _nftContract) {
        nftContract = IERC721(_nftContract);
    }

    function listNFT(uint256 _tokenId, uint256 _price) external {
        require(nftContract.ownerOf(_tokenId) == msg.sender, "Not the owner of NFT");
        require(nftContract.getApproved(_tokenId) == address(this), "Marketplace not approved to transfer NFT");
        require(_price > 0, "Price must be greater than zero");

        listings[_tokenId] = Listing({
            owner: msg.sender,
            tokenId: _tokenId,
            price: _price,
            active: true
        });

        userOwnedTokens[msg.sender].add(_tokenId);

        emit NFTListed(_tokenId, msg.sender, _price);
    }

    function unlistNFT(uint256 _tokenId) external {
        require(listings[_tokenId].owner == msg.sender, "Not the owner of the listing");
        delete listings[_tokenId];
        userOwnedTokens[msg.sender].remove(_tokenId);
        emit NFTUnlisted(_tokenId);
    }

    function buyNFT(uint256 _tokenId) external payable {
        Listing memory listing = listings[_tokenId];
        require(listing.active, "Listing not active");
        require(msg.value >= listing.price, "Insufficient funds");

        address seller = listing.owner;
        address buyer = msg.sender;

        listings[_tokenId].active = false;
        userOwnedTokens[seller].remove(_tokenId);
        nftContract.safeTransferFrom(seller, buyer, _tokenId);

        payable(seller).transfer(msg.value);

        emit NFTSold(_tokenId, seller, buyer, msg.value);
    }

    function getUserListedTokens(address _user) external view returns (uint256[] memory) {
        uint256[] memory tokens = new uint256[](userOwnedTokens[_user].length());
        for (uint256 i = 0; i < userOwnedTokens[_user].length(); i++) {
            tokens[i] = userOwnedTokens[_user].at(i);
        }
        return tokens;
    }
}
