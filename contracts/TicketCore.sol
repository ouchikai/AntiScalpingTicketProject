// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "@openzeppelin/contracts/utils/Counters.sol";

abstract contract TicketCore is ERC721 {
    using Counters for Counters.Counter;

    struct Ticket {
        uint256 eventId;
        address originalBuyer;
        uint256 purchasePrice;
        uint256 purchaseTime;
        bool isUsed;
        string seatInfo;
        uint256 transferCount;
        bytes32 secretHash;
    }

    mapping(uint256 => Ticket) public tickets;
    Counters.Counter internal _ticketIds;

    event TicketMinted(
        uint256 indexed ticketId,
        uint256 indexed eventId,
        address buyer
    );
    event TicketTransferred(
        uint256 indexed ticketId,
        address from,
        address to,
        uint256 price
    );
    event TicketUsed(uint256 indexed ticketId, bytes32 secret);
    event TicketRefunded(
        uint256 indexed ticketId,
        address buyer,
        uint256 refundAmount
    );

    constructor(
        string memory name_,
        string memory symbol_
    ) ERC721(name_, symbol_) {}

    function _mintTicket(
        address to,
        uint256 eventId,
        string memory seatInfo,
        uint256 price
    ) internal returns (uint256) {
        _ticketIds.increment();
        uint256 ticketId = _ticketIds.current();
        bytes32 secretHash = keccak256(
            abi.encodePacked(ticketId, to, block.timestamp)
        );
        tickets[ticketId] = Ticket({
            eventId: eventId,
            originalBuyer: to,
            purchasePrice: price,
            purchaseTime: block.timestamp,
            isUsed: false,
            seatInfo: seatInfo,
            transferCount: 0,
            secretHash: secretHash
        });
        _mint(to, ticketId);
        emit TicketMinted(ticketId, eventId, to);
        return ticketId;
    }

    function _burnTicket(uint256 ticketId) internal {
        _burn(ticketId);
        delete tickets[ticketId];
    }
}
