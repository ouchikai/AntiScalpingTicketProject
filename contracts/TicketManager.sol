// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./TicketNFT.sol";
import "./ValidationUtils.sol";

/**
 * @title TicketManager
 * @dev チケットの売買、転送、使用、返金を管理
 */
contract TicketManager {
    TicketNFT public immutable ticketContract;

    event TicketPurchased(
        uint256 indexed tokenId,
        address indexed buyer,
        uint256 indexed eventId
    );
    event TicketTransferred(
        uint256 indexed tokenId,
        address indexed from,
        address indexed to
    );
    event TicketUsed(uint256 indexed tokenId, address indexed user);
    event TicketRefunded(
        uint256 indexed tokenId,
        address indexed owner,
        uint256 amount
    );

    modifier onlyTicketContract() {
        require(msg.sender == address(ticketContract), "Unauthorized");
        _;
    }

    constructor(address _ticketContract) {
        ticketContract = TicketNFT(_ticketContract);
    }

    function buyTicket(
        address buyer,
        uint256 eventId,
        uint256 payment
    ) external onlyTicketContract {
        // イベント存在確認
        StorageTypes.Event memory eventData = ticketContract.getEvent(eventId);
        require(eventData.maxTickets > 0, "Event not found");

        // 販売期間確認
        require(
            block.timestamp >= eventData.saleStart &&
                block.timestamp <= eventData.saleEnd,
            "Sale not active"
        );

        // 価格確認
        require(payment >= eventData.price, "Insufficient payment");

        // 在庫確認
        require(eventData.soldTickets < eventData.maxTickets, "Sold out");

        // チケット発行
        uint256 tokenId = ticketContract.mintTicket(buyer, eventId);

        // イベントデータ更新
        _updateEventSoldTickets(eventId);

        emit TicketPurchased(tokenId, buyer, eventId);
    }

    function transferTicket(
        address from,
        address to,
        uint256 tokenId
    ) external onlyTicketContract {
        require(ticketContract.ownerOf(tokenId) == from, "Not owner");
        require(to != address(0), "Invalid recipient");

        StorageTypes.Ticket memory ticket = ticketContract.getTicket(tokenId);
        require(!ticket.isUsed, "Ticket already used");

        // 転送履歴を更新
        _updateTransferHistory(tokenId, to);

        // 実際の転送
        ticketContract.safeTransferFrom(from, to, tokenId);

        emit TicketTransferred(tokenId, from, to);
    }

    function useTicket(
        address user,
        uint256 tokenId
    ) external onlyTicketContract {
        require(ticketContract.ownerOf(tokenId) == user, "Not owner");

        StorageTypes.Ticket memory ticket = ticketContract.getTicket(tokenId);
        require(!ticket.isUsed, "Already used");

        StorageTypes.Event memory eventData = ticketContract.getEvent(
            ticket.eventId
        );
        require(block.timestamp >= eventData.eventDate, "Event not started");
        require(
            block.timestamp <= eventData.eventDate + 24 hours,
            "Event expired"
        );

        // チケットを使用済みにマーク
        _markTicketAsUsed(tokenId);

        emit TicketUsed(tokenId, user);
    }

    function refundTicket(
        address owner,
        uint256 tokenId
    ) external onlyTicketContract {
        require(ticketContract.ownerOf(tokenId) == owner, "Not owner");

        StorageTypes.Ticket memory ticket = ticketContract.getTicket(tokenId);
        require(!ticket.isUsed, "Cannot refund used ticket");

        StorageTypes.Event memory eventData = ticketContract.getEvent(
            ticket.eventId
        );
        require(
            block.timestamp < eventData.eventDate - 24 hours,
            "Too late for refund"
        );

        // 返金額計算
        uint256 refundAmount = _calculateRefundAmount(
            eventData.price,
            ticket.transferHistory.length
        );

        // チケット焼却
        ticketContract.burn(tokenId);

        // 返金実行
        payable(owner).transfer(refundAmount);

        emit TicketRefunded(tokenId, owner, refundAmount);
    }

    // === 内部関数 ===

    function _updateEventSoldTickets(uint256 eventId) private {
        // イベントの販売済みチケット数を増加
        // ※実装はStorageTypesの構造に依存
    }

    function _updateTransferHistory(uint256 tokenId, address to) private {
        // 転送履歴を更新
        // ※実装はStorageTypesの構造に依存
    }

    function _markTicketAsUsed(uint256 tokenId) private {
        // チケットを使用済みにマーク
        // ※実装はStorageTypesの構造に依存
    }

    function _calculateRefundAmount(
        uint256 originalPrice,
        uint256 transferCount
    ) private pure returns (uint256) {
        // 転送回数に基づいて返金額を計算（スキャルピング対策）
        uint256 penalty = transferCount * 5; // 転送1回につき5%減額
        if (penalty > 50) penalty = 50; // 最大50%減額

        return (originalPrice * (100 - penalty)) / 100;
    }
}
