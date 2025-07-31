// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./TicketCore.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

abstract contract TicketSale is TicketCore, ReentrancyGuard {
    // 定数パラメータ
    uint256 public constant MAX_RESALE_MULTIPLIER = 110;
    uint256 public constant TRANSFER_COOLDOWN = 24 hours;
    uint256 public constant REFUND_DEADLINE_HOURS = 48;
    uint256 public constant MAX_TRANSFER_COUNT = 3;
    uint256 public constant PLATFORM_FEE_RATE = 250;

    // 動的パラメータ
    uint256 public refundFeeRate = 500;
    address public feeRecipient;

    // 時間制限転売システム
    mapping(uint256 => uint256) public timeLimitedResaleEnd;
    mapping(uint256 => bool) public timeLimitedResaleEnabled;

    // 転売履歴
    struct TransferHistory {
        address from;
        address to;
        uint256 price;
        uint256 timestamp;
    }
    mapping(uint256 => TransferHistory[]) public transferHistories;

    // 販売・転売・返金の内部ロジックはAntiScalpingTicketで呼び出し
}
