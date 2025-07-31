// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./TicketNFT.sol";
import "./TicketManager.sol";
import "./EventManager.sol";
import "./UserManager.sol";
import "./LotteryManager.sol";
import "./EmergencyControls.sol";

/**
 * @title AntiScalpingTicket
 * @dev メインコントラクト - 各コンポーネントを統合し、公開APIを提供
 */
contract AntiScalpingTicket is TicketNFT, EmergencyControls {
    TicketManager public ticketManager;
    EventManager public eventManager;
    UserManager public userManager;
    LotteryManager public lotteryManager;

    constructor(
        address _feeRecipient
    ) TicketNFT("Anti-Scalping Ticket", "AST", _feeRecipient) {
        _initializeManagers();
    }

    function _initializeManagers() private {
        ticketManager = new TicketManager(address(this));
        eventManager = new EventManager(address(this));
        userManager = new UserManager(address(this));
        lotteryManager = new LotteryManager(address(this));
    }

    // === 公開API ===

    function buyTicket(
        uint256 eventId
    ) external payable whenNotPaused nonReentrant {
        ticketManager.buyTicket(msg.sender, eventId, msg.value);
    }

    function transferTicket(
        address to,
        uint256 tokenId
    ) external whenNotPaused {
        ticketManager.transferTicket(msg.sender, to, tokenId);
    }

    function useTicket(uint256 tokenId) external whenNotPaused {
        ticketManager.useTicket(msg.sender, tokenId);
    }

    function refundTicket(uint256 tokenId) external whenNotPaused nonReentrant {
        ticketManager.refundTicket(msg.sender, tokenId);
    }

    // イベント管理
    function createEvent(
        string memory name,
        uint256 price,
        uint256 maxTickets,
        uint256 saleStart,
        uint256 saleEnd,
        uint256 eventDate
    ) external onlyOwner {
        eventManager.createEvent(
            name,
            price,
            maxTickets,
            saleStart,
            saleEnd,
            eventDate
        );
    }
}
