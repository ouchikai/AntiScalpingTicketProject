// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title StorageTypes
 * @dev 全コントラクトで使用される共通データ構造を定義
 */
library StorageTypes {
    // チケット情報
    struct Ticket {
        uint256 eventId; // 関連するイベントID
        address originalOwner; // 最初の購入者
        bool isUsed; // 使用済みフラグ
        uint256 purchaseTime; // 購入時刻
        address[] transferHistory; // 転送履歴
        uint256 purchasePrice; // 購入価格
    }

    // イベント情報
    struct Event {
        string name; // イベント名
        uint256 price; // チケット価格
        uint256 maxTickets; // 最大チケット数
        uint256 soldTickets; // 販売済みチケット数
        uint256 saleStart; // 販売開始時刻
        uint256 saleEnd; // 販売終了時刻
        uint256 eventDate; // イベント開催日時
        bool isActive; // イベントの有効性
        address organizer; // 主催者アドレス
    }

    // ユーザー情報
    struct User {
        bool isVerified; // 認証済みフラグ
        uint256 purchaseCount; // 購入回数
        uint256 transferCount; // 転送回数
        uint256 lastPurchaseTime; // 最後の購入時刻
        bool isBanned; // BAN状態
        uint256 reputation; // レピュテーションスコア
    }

    // 抽選情報
    struct Lottery {
        uint256 eventId; // 対象イベントID
        uint256 applicationStart; // 応募開始時刻
        uint256 applicationEnd; // 応募終了時刻
        uint256 drawTime; // 抽選時刻
        uint256 maxWinners; // 当選者数上限
        bool isDrawn; // 抽選済みフラグ
        address[] applicants; // 応募者リスト
        address[] winners; // 当選者リスト
    }

    // 返金情報
    struct RefundPolicy {
        uint256 transferPenalty; // 転送ペナルティ率(%)
        uint256 refundDeadline; // 返金期限(イベント前何時間)
        uint256 baseFee; // 基本手数料率(%)
        bool isRefundable; // 返金可能フラグ
    }

    // 転送制限情報
    struct TransferRestriction {
        uint256 maxTransfers; // 最大転送回数
        uint256 minHoldTime; // 最小保有時間
        uint256 transferFee; // 転送手数料
        bool requiresVerification; // 認証必須フラグ
    }

    // === ヘルパー関数 ===

    /**
     * @dev チケットが転送可能かチェック
     */
    function isTransferable(
        Ticket memory ticket,
        TransferRestriction memory restriction
    ) internal view returns (bool) {
        if (ticket.isUsed) return false;
        if (ticket.transferHistory.length >= restriction.maxTransfers)
            return false;
        if (block.timestamp < ticket.purchaseTime + restriction.minHoldTime)
            return false;
        return true;
    }

    /**
     * @dev イベントが販売期間中かチェック
     */
    function isSaleActive(Event memory eventData) internal view returns (bool) {
        return
            block.timestamp >= eventData.saleStart &&
            block.timestamp <= eventData.saleEnd &&
            eventData.isActive &&
            eventData.soldTickets < eventData.maxTickets;
    }

    /**
     * @dev 返金可能かチェック
     */
    function isRefundable(
        Ticket memory ticket,
        Event memory eventData,
        RefundPolicy memory policy
    ) internal view returns (bool) {
        if (ticket.isUsed || !policy.isRefundable) return false;

        uint256 deadline = eventData.eventDate -
            (policy.refundDeadline * 1 hours);
        return block.timestamp <= deadline;
    }

    /**
     * @dev 返金額を計算
     */
    function calculateRefundAmount(
        uint256 originalPrice,
        uint256 transferCount,
        RefundPolicy memory policy
    ) internal pure returns (uint256) {
        // 基本手数料
        uint256 baseFeeAmount = (originalPrice * policy.baseFee) / 100;

        // 転送ペナルティ
        uint256 transferPenalty = (originalPrice *
            policy.transferPenalty *
            transferCount) / 100;

        // 最大50%まで減額
        uint256 totalDeduction = baseFeeAmount + transferPenalty;
        if (totalDeduction > originalPrice / 2) {
            totalDeduction = originalPrice / 2;
        }

        return originalPrice - totalDeduction;
    }

    /**
     * @dev ユーザーのレピュテーションスコアを更新
     */
    function updateReputation(
        User storage user,
        bool isPositive,
        uint256 points
    ) internal {
        if (isPositive) {
            user.reputation += points;
        } else {
            if (user.reputation >= points) {
                user.reputation -= points;
            } else {
                user.reputation = 0;
            }
        }
    }
}
