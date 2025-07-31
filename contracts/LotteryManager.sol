// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./TicketNFT.sol";
import "./ValidationUtils.sol";

/**
 * @title LotteryManager
 * @dev 人気イベントの抽選システムを管理
 */
contract LotteryManager {
    TicketNFT public immutable ticketContract;
    uint256 public nextLotteryId = 1;

    // 抽選データ
    mapping(uint256 => StorageTypes.Lottery) public lotteries;
    mapping(uint256 => mapping(address => bool)) public hasApplied;
    mapping(uint256 => mapping(address => bool)) public isWinner;

    // VRF用のランダムネス（簡略版）
    uint256 private nonce;

    event LotteryCreated(
        uint256 indexed lotteryId,
        uint256 indexed eventId,
        uint256 applicationEnd,
        uint256 maxWinners
    );
    event LotteryApplication(
        uint256 indexed lotteryId,
        address indexed applicant
    );
    event LotteryDrawn(uint256 indexed lotteryId, address[] winners);
    event WinnerTicketClaimed(
        uint256 indexed lotteryId,
        address indexed winner,
        uint256 tokenId
    );

    modifier onlyTicketContract() {
        require(msg.sender == address(ticketContract), "Unauthorized");
        _;
    }

    constructor(address _ticketContract) {
        ticketContract = TicketNFT(_ticketContract);
    }

    /**
     * @dev 抽選を作成
     */
    function createLottery(
        uint256 eventId,
        uint256 applicationStart,
        uint256 applicationEnd,
        uint256 drawTime,
        uint256 maxWinners
    ) external onlyTicketContract returns (uint256) {
        // バリデーション
        StorageTypes.Event memory eventData = ticketContract.getEvent(eventId);
        require(eventData.maxTickets > 0, "Event not found");
        require(
            applicationStart > block.timestamp,
            "Start time must be future"
        );
        require(applicationEnd > applicationStart, "Invalid time range");
        require(
            drawTime > applicationEnd,
            "Draw time must be after application"
        );
        require(
            maxWinners > 0 && maxWinners <= eventData.maxTickets,
            "Invalid max winners"
        );

        uint256 lotteryId = nextLotteryId++;

        lotteries[lotteryId] = StorageTypes.Lottery({
            eventId: eventId,
            applicationStart: applicationStart,
            applicationEnd: applicationEnd,
            drawTime: drawTime,
            maxWinners: maxWinners,
            isDrawn: false,
            applicants: new address[](0),
            winners: new address[](0)
        });

        emit LotteryCreated(lotteryId, eventId, applicationEnd, maxWinners);
        return lotteryId;
    }

    /**
     * @dev 抽選に応募
     */
    function applyForLottery(
        address applicant,
        uint256 lotteryId
    ) external onlyTicketContract {
        StorageTypes.Lottery storage lottery = lotteries[lotteryId];
        require(lottery.eventId > 0, "Lottery not found");
        require(
            block.timestamp >= lottery.applicationStart &&
                block.timestamp <= lottery.applicationEnd,
            "Application period not active"
        );
        require(!hasApplied[lotteryId][applicant], "Already applied");
        require(!lottery.isDrawn, "Lottery already drawn");

        // ユーザー資格チェック
        StorageTypes.User memory userData = ticketContract.getUser(applicant);
        require(!userData.isBanned, "User is banned");
        require(userData.isVerified, "User not verified");

        // 応募登録
        lottery.applicants.push(applicant);
        hasApplied[lotteryId][applicant] = true;

        emit LotteryApplication(lotteryId, applicant);
    }

    /**
     * @dev 抽選実行
     */
    function drawLottery(uint256 lotteryId) external onlyTicketContract {
        StorageTypes.Lottery storage lottery = lotteries[lotteryId];
        require(lottery.eventId > 0, "Lottery not found");
        require(block.timestamp >= lottery.drawTime, "Draw time not reached");
        require(!lottery.isDrawn, "Already drawn");
        require(lottery.applicants.length > 0, "No applicants");

        lottery.isDrawn = true;

        // 当選者数を決定（応募者数と最大当選者数の小さい方）
        uint256 winnerCount = lottery.applicants.length > lottery.maxWinners
            ? lottery.maxWinners
            : lottery.applicants.length;

        // 抽選実行
        address[] memory selectedWinners = _selectWinners(
            lottery.applicants,
            winnerCount
        );

        // 当選者を記録
        for (uint256 i = 0; i < selectedWinners.length; i++) {
            lottery.winners.push(selectedWinners[i]);
            isWinner[lotteryId][selectedWinners[i]] = true;
        }

        emit LotteryDrawn(lotteryId, selectedWinners);
    }

    /**
     * @dev 当選者がチケットを受け取り
     */
    function claimWinnerTicket(
        address winner,
        uint256 lotteryId
    ) external onlyTicketContract returns (uint256) {
        StorageTypes.Lottery memory lottery = lotteries[lotteryId];
        require(lottery.isDrawn, "Lottery not drawn yet");
        require(isWinner[lotteryId][winner], "Not a winner");

        // 重複受け取り防止
        isWinner[lotteryId][winner] = false;

        // チケット発行
        uint256 tokenId = ticketContract.mintTicket(winner, lottery.eventId);

        emit WinnerTicketClaimed(lotteryId, winner, tokenId);
        return tokenId;
    }

    /**
     * @dev 抽選結果確認
     */
    function checkLotteryResult(
        uint256 lotteryId,
        address user
    )
        external
        view
        returns (bool hasAppliedResult, bool isWinnerResult, bool canClaim)
    {
        hasAppliedResult = hasApplied[lotteryId][user];
        isWinnerResult = isWinner[lotteryId][user];
        canClaim = isWinnerResult && lotteries[lotteryId].isDrawn;

        return (hasAppliedResult, isWinnerResult, canClaim);
    }

    /**
     * @dev 抽選情報取得
     */
    function getLotteryInfo(
        uint256 lotteryId
    ) external view returns (StorageTypes.Lottery memory) {
        return lotteries[lotteryId];
    }

    /**
     * @dev 応募者数取得
     */
    function getApplicantCount(
        uint256 lotteryId
    ) external view returns (uint256) {
        return lotteries[lotteryId].applicants.length;
    }

    /**
     * @dev 当選者リスト取得
     */
    function getWinners(
        uint256 lotteryId
    ) external view returns (address[] memory) {
        return lotteries[lotteryId].winners;
    }

    // === 内部関数 ===

    /**
     * @dev 抽選アルゴリズム（フィッシャー・イェーツシャッフル）
     */
    function _selectWinners(
        address[] memory applicants,
        uint256 winnerCount
    ) private returns (address[] memory) {
        require(applicants.length >= winnerCount, "Not enough applicants");

        // 配列をコピー
        address[] memory shuffled = new address[](applicants.length);
        for (uint256 i = 0; i < applicants.length; i++) {
            shuffled[i] = applicants[i];
        }

        // フィッシャー・イェーツシャッフル
        for (uint256 i = shuffled.length - 1; i > 0; i--) {
            uint256 j = _generateRandomIndex(i + 1);

            // スワップ
            address temp = shuffled[i];
            shuffled[i] = shuffled[j];
            shuffled[j] = temp;
        }

        // 上位N名を返す
        address[] memory winners = new address[](winnerCount);
        for (uint256 i = 0; i < winnerCount; i++) {
            winners[i] = shuffled[i];
        }

        return winners;
    }

    /**
     * @dev 疑似ランダム数生成（本番環境ではChainlink VRFを推奨）
     */
    function _generateRandomIndex(uint256 max) private returns (uint256) {
        nonce++;
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        block.timestamp,
                        block.difficulty,
                        msg.sender,
                        nonce
                    )
                )
            ) % max;
    }
}
