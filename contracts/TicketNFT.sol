// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./StorageTypes.sol";

/**
 * @title TicketNFT
 * @dev NFTの基本機能を提供するベースコントラクト
 */
abstract contract TicketNFT is ERC721, Ownable, Pausable, ReentrancyGuard {
    using StorageTypes for *;

    address public feeRecipient;
    uint256 public nextTokenId = 1;

    // ストレージマッピング
    mapping(uint256 => StorageTypes.Ticket) public tickets;
    mapping(uint256 => StorageTypes.Event) public events;
    mapping(address => StorageTypes.User) public users;

    event TicketMinted(
        uint256 indexed tokenId,
        address indexed owner,
        uint256 indexed eventId
    );

    constructor(
        string memory name,
        string memory symbol,
        address _feeRecipient
    ) ERC721(name, symbol) {
        require(_feeRecipient != address(0), "Invalid fee recipient");
        feeRecipient = _feeRecipient;
    }

    function mintTicket(
        address to,
        uint256 eventId
    ) internal returns (uint256) {
        uint256 tokenId = nextTokenId++;
        _safeMint(to, tokenId);

        tickets[tokenId] = StorageTypes.Ticket({
            eventId: eventId,
            originalOwner: to,
            isUsed: false,
            purchaseTime: block.timestamp,
            transferHistory: new address[](0)
        });

        emit TicketMinted(tokenId, to, eventId);
        return tokenId;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    // View functions
    function getTicket(
        uint256 tokenId
    ) external view returns (StorageTypes.Ticket memory) {
        return tickets[tokenId];
    }

    function getEvent(
        uint256 eventId
    ) external view returns (StorageTypes.Event memory) {
        return events[eventId];
    }

    function getUser(
        address userAddress
    ) external view returns (StorageTypes.User memory) {
        return users[userAddress];
    }
}
