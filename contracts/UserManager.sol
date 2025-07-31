// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./TicketNFT.sol";
import "./ValidationUtils.sol";

/**
 * @title UserManager
 * @dev ユーザーの認証、レピュテーション、BAN管理を担当
 */
contract UserManager {
    TicketNFT public immutable ticketContract;

    // 認証済みユーザー管理
    mapping(address => bool) public verifiers;

    event UserVerified(address indexed user, address indexed verifier);
    event UserBanned(address indexed user, string reason);
    event UserUnbanned(address indexed user);
    event ReputationUpdated(address indexed user, uint256 newReputation);
    event VerifierAdded(address indexed verifier);
    event VerifierRemoved(address indexed verifier);

    modifier onlyTicketContract() {
        require(msg.sender == address(ticketContract), "Unauthorized");
        _;
    }

    modifier onlyVerifier() {
        require(verifiers[msg.sender], "Not authorized verifier");
        _;
    }

    constructor(address _ticketContract) {
        ticketContract = TicketNFT(_ticketContract);
    }

    /**
     * @dev 認証者を追加
     */
    function addVerifier(address verifier) external onlyTicketContract {
        ValidationUtils.validateAddress(verifier);
        verifiers[verifier] = true;
        emit VerifierAdded(verifier);
    }

    /**
     * @dev 認証者を削除
     */
    function removeVerifier(address verifier) external onlyTicketContract {
        verifiers[verifier] = false;
        emit VerifierRemoved(verifier);
    }

    /**
     * @dev ユーザーを認証
     */
    function verifyUser(address user) external onlyVerifier {
        ValidationUtils.validateAddress(user);

        StorageTypes.User storage userData = ticketContract.users(user);
        userData.isVerified = true;
        userData.reputation = 100; // 初期レピュテーション

        emit UserVerified(user, msg.sender);
    }

    /**
     * @dev ユーザーをBAN
     */
    function banUser(
        address user,
        string calldata reason
    ) external onlyTicketContract {
        StorageTypes.User storage userData = ticketContract.users(user);
        userData.isBanned = true;
        userData.reputation = 0;

        emit UserBanned(user, reason);
    }

    /**
     * @dev ユーザーのBAN解除
     */
    function unbanUser(address user) external onlyTicketContract {
        StorageTypes.User storage userData = ticketContract.users(user);
        userData.isBanned = false;
        userData.reputation = 50; // 低めの初期値で復帰

        emit UserUnbanned(user);
    }

    /**
     * @dev 購入後のユーザーデータ更新
     */
    function updateAfterPurchase(
        address user,
        uint256 price
    ) external onlyTicketContract {
        StorageTypes.User storage userData = ticketContract.users(user);
        userData.purchaseCount++;
        userData.lastPurchaseTime = block.timestamp;

        // レピュテーション向上（正常な購入）
        StorageTypes.updateReputation(userData, true, 5);

        emit ReputationUpdated(user, userData.reputation);
    }

    /**
     * @dev 転送後のユーザーデータ更新
     */
    function updateAfterTransfer(
        address from,
        address to
    ) external onlyTicketContract {
        // 転送元のデータ更新
        StorageTypes.User storage fromUser = ticketContract.users(from);
        fromUser.transferCount++;

        // 頻繁な転送にペナルティ
        if (fromUser.transferCount > 5) {
            StorageTypes.updateReputation(fromUser, false, 10);
        } else {
            StorageTypes.updateReputation(fromUser, false, 2);
        }

        // 転送先のユーザー情報初期化（必要に応じて）
        StorageTypes.User storage toUser = ticketContract.users(to);
        if (!toUser.isVerified && toUser.purchaseCount == 0) {
            toUser.reputation = 50; // 新規ユーザーの初期値
        }

        emit ReputationUpdated(from, fromUser.reputation);
    }

    /**
     * @dev 不正行為検出時のペナルティ
     */
    function applyPenalty(
        address user,
        uint256 penaltyPoints,
        string calldata reason
    ) external onlyTicketContract {
        StorageTypes.User storage userData = ticketContract.users(user);
        StorageTypes.updateReputation(userData, false, penaltyPoints);

        // 重大な不正の場合はBAN
        if (userData.reputation < 10) {
            userData.isBanned = true;
            emit UserBanned(user, reason);
        }

        emit ReputationUpdated(user, userData.reputation);
    }

    /**
     * @dev ユーザーの購入制限チェック
     */
    function canPurchase(
        address user
    ) external view returns (bool, string memory) {
        StorageTypes.User memory userData = ticketContract.getUser(user);

        if (userData.isBanned) {
            return (false, "User is banned");
        }

        if (!userData.isVerified) {
            return (false, "User not verified");
        }

        if (userData.reputation < 30) {
            return (false, "Reputation too low");
        }

        // 短時間での連続購入制限
        if (block.timestamp < userData.lastPurchaseTime + 300) {
            // 5分制限
            return (false, "Too frequent purchases");
        }

        return (true, "");
    }

    /**
     * @dev ユーザーの転送制限チェック
     */
    function canTransfer(
        address user
    ) external view returns (bool, string memory) {
        StorageTypes.User memory userData = ticketContract.getUser(user);

        if (userData.isBanned) {
            return (false, "User is banned");
        }

        if (userData.reputation < 20) {
            return (false, "Reputation too low for transfer");
        }

        // 頻繁な転送の制限
        if (userData.transferCount > 10) {
            return (false, "Transfer limit exceeded");
        }

        return (true, "");
    }

    /**
     * @dev ユーザー統計取得
     */
    function getUserStats(
        address user
    )
        external
        view
        returns (
            bool isVerified,
            bool isBanned,
            uint256 reputation,
            uint256 purchaseCount,
            uint256 transferCount
        )
    {
        StorageTypes.User memory userData = ticketContract.getUser(user);
        return (
            userData.isVerified,
            userData.isBanned,
            userData.reputation,
            userData.purchaseCount,
            userData.transferCount
        );
    }
}
