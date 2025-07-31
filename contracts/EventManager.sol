// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./TicketNFT.sol";

/**
 * @title EventManager
 * @dev イベントの作成、管理を担当
 */
contract EventManager {
    TicketNFT public immutable ticketContract;
    uint256 public nextEventId = 1;

    event EventCreated(
        uint256 indexed eventId,
        string name,
        uint256 price,
        uint256 maxTickets,
        uint256 eventDate
    );

    modifier onlyTicketContract() {
        require(msg.sender == address(ticketContract), "Unauthorized");
        _;
    }

    constructor(address _ticketContract) {
        ticketContract = TicketNFT(_ticketContract);
    }

    function createEvent(
        string memory name,
        uint256 price,
        uint256 maxTickets,
        uint256 saleStart,
        uint256 saleEnd,
        uint256 eventDate
    ) external onlyTicketContract returns (uint256) {
        require(bytes(name).length > 0, "Empty name");
        require(price > 0, "Invalid price");
        require(maxTickets > 0, "Invalid max tickets");
        require(saleStart < saleEnd, "Invalid sale period");
        require(saleEnd < eventDate, "Event before sale end");

        uint256 eventId = nextEventId++;

        // イベントデータを保存
        _storeEventData(
            eventId,
            name,
            price,
            maxTickets,
            saleStart,
            saleEnd,
            eventDate
        );

        emit EventCreated(eventId, name, price, maxTickets, eventDate);
        return eventId;
    }

    function _storeEventData(
        uint256 eventId,
        string memory name,
        uint256 price,
        uint256 maxTickets,
        uint256 saleStart,
        uint256 saleEnd,
        uint256 eventDate
    ) private {
        ticketContract.events(eventId) = StorageTypes.Event({
            name: name,
            price: price,
            maxTickets: maxTickets,
            soldTickets: 0,
            saleStart: saleStart,
            saleEnd: saleEnd,
            eventDate: eventDate,
            isActive: true,
            organizer: msg.sender
        });
    }
}
