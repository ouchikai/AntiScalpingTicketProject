// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19; // Solidityバージョン指定

// OpenZeppelinの各種セキュリティ・標準ライブラリ
import "@openzeppelin/contracts/token/ERC721/ERC721.sol"; // NFT標準
import "@openzeppelin/contracts/access/Ownable.sol"; // 管理者権限
import "@openzeppelin/contracts/security/ReentrancyGuard.sol"; // 再入防止
import "@openzeppelin/contracts/security/Pausable.sol"; // 一時停止
import "@openzeppelin/contracts/utils/Counters.sol"; // カウンター
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol"; // 署名検証

/**
    /**
     * @dev チケット購入処理
     *
     * 指定イベントのNFTチケットを購入する関数。
     * - KYC認証済み・ブラックリスト外・地域制限クリア済みユーザーのみ購入可能
     * - イベント販売期間・販売数・支払金額・購入制限などを厳格にチェック
     * - 購入ごとにNFTチケットを新規発行し、座席情報や入場用シークレットを保存
     *
     * @param eventId 購入対象イベントID
     * @param seatInfo 座席情報（自由記述）
     * @return ticketId 発行されたチケットID
     */
    function purchaseTicket(
        uint256 eventId,
        string memory seatInfo
    )
        public
        payable
        onlyVerifiedUser // KYC認証済みユーザーのみ
        whenEventActive(eventId) // イベント有効時のみ
        onlyAllowedRegion(eventId) // 地域制限クリア必須
        nonReentrant // 再入防止
    /**
     * @dev チケット転売処理
     *
     * NFTチケットの所有者が他ユーザーへ転売する際のロジック。
     * - 転売回数・価格・クールダウン・時間制限・KYC・ブラックリスト等を厳格にチェック
     * - プラットフォーム手数料を差し引き、履歴を記録し、NFT所有権を移転
     *
     * @param ticketId 転売対象チケットID
     * @param to 転売先アドレス
     * @param price 転売価格
     */
    function resellTicket(
        uint256 ticketId,
        address to,
        uint256 price
    ) external payable nonReentrant whenNotPaused {
        // --- バリデーション ---
        // チケットが存在するか
        require(_exists(ticketId), "Ticket does not exist");
        // 呼び出し元が現在の所有者か
        require(ownerOf(ticketId) == msg.sender, "Not ticket owner");
        // 転売先アドレスが0アドレスでないか
        require(to != address(0), "Invalid recipient");
        // 転売先がKYC認証済みか
        require(verifiedUsers[to], "Recipient not verified");
        // 転売先がブラックリストに載っていないか
        require(!blacklistedUsers[to], "Recipient is blacklisted");
        // 支払金額が指定された転売価格と一致しているか
        require(msg.value == price, "Incorrect payment amount");

        // --- 状態取得 ---
        Ticket storage ticket = tickets[ticketId];
        Event storage eventInfo = events[ticket.eventId];

        // イベントが譲渡可能か
        require(eventInfo.transferable, "Ticket not transferable");
        // チケットが既に使用済みでないか
        require(!ticket.isUsed, "Ticket already used");
        // イベント開催前のみ転売可能
        require(
            block.timestamp < eventInfo.eventDate,
            "Event has already occurred"
        );
        // 転売クールダウン期間（購入から24時間）経過しているか
        require(
            block.timestamp >= ticket.purchaseTime + TRANSFER_COOLDOWN,
            "Transfer cooldown not met"
        );
        // 転売価格がイベントごとの上限を超えていないか
        require(
            price <= eventInfo.maxResalePrice,
            "Price exceeds maximum resale price"
        );
        // 転売回数が上限未満か
        require(
            ticket.transferCount < MAX_TRANSFER_COUNT,
            "Transfer count exceeded"
        );

        // --- 時間制限転売チェック ---
        // 時間制限転売が有効な場合は、転売期間内か
        if (timeLimitedResaleEnabled[ticketId]) {
            require(
                block.timestamp <= timeLimitedResaleEnd[ticketId],
                "Time limited resale period ended"
            );
        }

        // --- セカンダリ転売価格制限 ---
        // オリジナル購入者以外が転売する場合は、前回転売価格を超えていないか
        if (msg.sender != ticket.originalBuyer) {
            require(
                price <= ticket.purchasePrice,
                "Secondary resale must not exceed previous price"
            );
        }

        // --- 手数料・支払計算 ---
        // プラットフォーム手数料（2.5%）を計算
        uint256 platformFee = (price * PLATFORM_FEE_RATE) / 10000;
        // 売り手への支払額
        uint256 sellerAmount = price - platformFee;

        // --- 転売履歴記録 ---
        transferHistories[ticketId].push(
            TransferHistory({
                from: msg.sender,
                to: to,
                price: price,
                timestamp: block.timestamp
            })
        );

        // --- 転売回数更新 ---
        ticket.transferCount++;

        // --- NFT所有権移転 ---
        _transfer(msg.sender, to, ticketId);

        // --- 売り手・プラットフォームへ支払い ---
        payable(msg.sender).transfer(sellerAmount);
        payable(feeRecipient).transfer(platformFee);

        // --- イベント発行 ---
        emit TicketTransferred(ticketId, msg.sender, to, price);
    }
    /// @dev 抽選情報
    struct LotteryInfo {
        uint256 applicationStart; // 応募開始時刻
        uint256 applicationEnd; // 応募終了時刻
        uint256 maxWinners; // 当選者数上限
        uint256 totalApplications; // 総応募数
        bool isCompleted; // 抽選完了フラグ
        bool isActive; // 抽選有効フラグ
        uint256 winnerCount; // 当選者数
    }

    // ===== 状態変数 =====

    // イベントID => イベント情報
    mapping(uint256 => Event) public events;
    // チケットID => チケット情報
    mapping(uint256 => Ticket) public tickets;
    // 公式販売者アドレス管理
    mapping(address => bool) public authorizedSellers;
    // KYC認証済みユーザー管理
    mapping(address => bool) public verifiedUsers;
    // ユーザーごとの購入制限数
    mapping(address => uint256) public userPurchaseLimit;

    // 追加マッピング
    // チケットID => 転売履歴配列
    mapping(uint256 => TransferHistory[]) public transferHistories;
    // ブラックリストユーザー管理
    mapping(address => bool) public blacklistedUsers;
    // イベントID => ホワイトリストユーザー
    mapping(uint256 => mapping(address => bool)) public eventWhitelist;
    // 使用済みシークレット（入場認証用）
    mapping(bytes32 => bool) public usedSecrets;

    // 地理的制限
    // 地域制限
    mapping(bytes32 => bool) public allowedRegions; // 許可地域ハッシュ
    mapping(address => bytes32) public userRegion; // ユーザー地域ハッシュ
    mapping(uint256 => bytes32[]) public eventRegions; // イベントごとの許可地域

    // 時間制限転売システム
    // 時間制限転売システム
    mapping(uint256 => uint256) public timeLimitedResaleEnd; // チケットごとの転売期限
    mapping(uint256 => bool) public timeLimitedResaleEnabled; // 時間制限転売有効フラグ

    // 抽選システム
    // 抽選システム
    mapping(uint256 => LotteryInfo) public lotteries; // イベントID => 抽選情報
    mapping(uint256 => mapping(address => bool)) public lotteryApplications; // イベントID => ユーザー応募状況
    mapping(uint256 => address[]) public lotteryParticipants; // イベントID => 応募者リスト
    mapping(uint256 => mapping(address => bool)) public lotteryWinners; // イベントID => 当選者

    // カウンター
    // イベントID・チケットIDの自動採番用カウンター
    Counters.Counter private _eventIds;
    Counters.Counter private _ticketIds;

    // 定数
    // 転売・返金・手数料などの定数パラメータ
    uint256 public constant MAX_RESALE_MULTIPLIER = 110; // 転売上限（定価の110%まで）
    uint256 public constant TRANSFER_COOLDOWN = 24 hours; // 転売クールダウン期間
    uint256 public constant REFUND_DEADLINE_HOURS = 48; // 返金期限（イベント前何時間まで）
    uint256 public constant MAX_TRANSFER_COUNT = 3; // 最大転売回数
    uint256 public constant PLATFORM_FEE_RATE = 250; // プラットフォーム手数料（2.5%）

    // 動的パラメータ
    // 返金手数料率（5% = 500/10000）
    uint256 public refundFeeRate = 500;
    // 手数料受取人
    address public feeRecipient;

    // ===== イベント（ログ）定義 =====

    // 新規イベント作成時
    event EventCreated(uint256 indexed eventId, string name, uint256 eventDate);
    event TicketMinted(
        uint256 indexed ticketId,
        uint256 indexed eventId,
        address buyer
    ); // チケット発行時
    event TicketTransferred(
        uint256 indexed ticketId,
        address from,
        address to,
        uint256 price
    ); // チケット転売時
    event TicketUsed(uint256 indexed ticketId, bytes32 secret); // チケット使用時
    event TicketRefunded(
        uint256 indexed ticketId,
        address buyer,
        uint256 refundAmount
    ); // チケット返金時
    event UserBlacklisted(address indexed user, string reason); // ユーザーをブラックリスト追加時
    event UserWhitelisted(uint256 indexed eventId, address indexed user); // イベントごとホワイトリスト追加時
    event EmergencyWithdraw(address indexed recipient, uint256 amount); // 緊急資金引き出し時
    event RegionUpdated(address indexed user, bytes32 regionHash); // ユーザー地域設定時
    event TimeLimitedResaleEnabled(uint256 indexed ticketId, uint256 endTime); // 時間制限転売有効化時
    event LotteryCreated(
        uint256 indexed eventId,
        uint256 applicationEnd,
        uint256 maxWinners
    ); // 抽選作成時
    event LotteryEntered(uint256 indexed eventId, address indexed user); // 抽選応募時
    event LotteryCompleted(uint256 indexed eventId, uint256 winnerCount); // 抽選完了時

    // ===== コンストラクタ =====

    // コントラクト初期化（NFT名・シンボル・手数料受取人）
    constructor(address _feeRecipient) ERC721("Anti-Scalping Ticket", "AST") {
        feeRecipient = _feeRecipient;
    }

    // ===== 修飾子 =====

    modifier onlyAuthorizedSeller() {
        require(
            authorizedSellers[msg.sender] || msg.sender == owner(),
            "Not authorized seller"
        );
        _;
    }

    modifier onlyVerifiedUser() {
        require(verifiedUsers[msg.sender], "User not verified");
        require(!blacklistedUsers[msg.sender], "User is blacklisted");
        _;
    }

    modifier whenEventActive(uint256 eventId) {
        require(events[eventId].isActive, "Event is not active");
        _;
    }

    modifier onlyAllowedRegion(uint256 eventId) {
        if (eventRegions[eventId].length > 0) {
            bytes32 userRegionHash = userRegion[msg.sender];
            require(userRegionHash != bytes32(0), "User region not set");

            bool isAllowed = false;
            for (uint256 i = 0; i < eventRegions[eventId].length; i++) {
                if (eventRegions[eventId][i] == userRegionHash) {
                    isAllowed = true;
                    break;
                }
            }
            require(isAllowed, "Region not allowed for this event");
        }
        _;
    }

    // ===== ユーザー管理機能 =====

    /**
     * @dev KYC認証済みユーザーを追加
     */
    function addVerifiedUser(address user) external onlyOwner {
        verifiedUsers[user] = true;
    }

    /**
     * @dev KYC認証を取り消し
     */
    function removeVerifiedUser(address user) external onlyOwner {
        verifiedUsers[user] = false;
    }

    /**
     * @dev ユーザーをブラックリストに追加（追加機能）
     */
    function addToBlacklist(
        address user,
        string memory reason
    ) external onlyOwner {
        blacklistedUsers[user] = true;
        emit UserBlacklisted(user, reason);
    }

    /**
     * @dev ブラックリストから削除
     */
    function removeFromBlacklist(address user) external onlyOwner {
        blacklistedUsers[user] = false;
    }

    /**
     * @dev イベント別ホワイトリストに追加（追加機能）
     */
    function addToEventWhitelist(
        uint256 eventId,
        address user
    ) external onlyAuthorizedSeller {
        eventWhitelist[eventId][user] = true;
        emit UserWhitelisted(eventId, user);
    }

    // ===== 地理的制限管理機能 =====

    /**
     * @dev 許可地域の追加
     */
    function addAllowedRegion(bytes32 regionHash) external onlyOwner {
        allowedRegions[regionHash] = true;
    }

    /**
     * @dev 許可地域の削除
     */
    function removeAllowedRegion(bytes32 regionHash) external onlyOwner {
        allowedRegions[regionHash] = false;
    }

    /**
     * @dev ユーザー地域の設定（KYC時に実行）
     */
    function setUserRegion(
        address user,
        bytes32 regionHash
    ) external onlyOwner {
        require(allowedRegions[regionHash], "Region not allowed");
        userRegion[user] = regionHash;
        emit RegionUpdated(user, regionHash);
    }

    /**
     * @dev イベント別許可地域の設定
     */
    function setEventAllowedRegions(
        uint256 eventId,
        bytes32[] memory regions
    ) external onlyAuthorizedSeller {
        delete eventRegions[eventId];
        for (uint256 i = 0; i < regions.length; i++) {
            require(allowedRegions[regions[i]], "Invalid region");
            eventRegions[eventId].push(regions[i]);
        }
    }

    // ===== 販売者管理機能 =====

    function addAuthorizedSeller(address seller) external onlyOwner {
        authorizedSellers[seller] = true;
    }

    function removeAuthorizedSeller(address seller) external onlyOwner {
        authorizedSellers[seller] = false;
    }

    // ===== イベント管理機能 =====

    /**
     * @dev イベント作成
     *
     * 公式販売者が新しいイベント（ライブ・スポーツ等）を作成する関数。
     * イベント名、開催日時、最大チケット数、定価、転売上限価格、譲渡可否、返金可否、販売期間などを設定。
     * 転売上限や販売期間などのバリデーションも厳格に行う。
     *
     * @param name イベント名
     * @param eventDate 開催日時（Unixタイムスタンプ）
     * @param maxTickets 最大チケット数
     * @param originalPrice チケット定価
     * @param maxResalePrice 転売上限価格
     * @param transferable 譲渡可能か
     * @param refundable 返金可能か
     * @param saleStartTime 販売開始時刻
     * @param saleEndTime 販売終了時刻
     * @return eventId 発行されたイベントID
     */
    function createEvent(
        string memory name,
        uint256 eventDate,
        uint256 maxTickets,
        uint256 originalPrice,
        uint256 maxResalePrice,
        bool transferable,
        bool refundable,
        uint256 saleStartTime, // 追加
        uint256 saleEndTime // 追加
    ) external onlyAuthorizedSeller whenNotPaused returns (uint256) {
        // イベント開催日が未来かチェック
        require(eventDate > block.timestamp, "Event date must be in future");
        // 販売期間の整合性チェック
        require(saleStartTime < saleEndTime, "Invalid sale period");
        require(saleEndTime <= eventDate, "Sale must end before event");
        // 転売上限価格が定価以上かチェック
        require(maxResalePrice >= originalPrice, "Max resale price too low");
        // 転売上限価格が定価のMAX_RESALE_MULTIPLIER%以下かチェック
        require(
            maxResalePrice <= (originalPrice * MAX_RESALE_MULTIPLIER) / 100,
            "Max resale price too high"
        );

        // イベントIDをインクリメントし新規IDを発行
        _eventIds.increment();
        uint256 eventId = _eventIds.current();

        // イベント情報を保存
        Event storage newEvent = events[eventId];
        newEvent.name = name;
        newEvent.eventDate = eventDate;
        newEvent.maxTickets = maxTickets;
        newEvent.originalPrice = originalPrice;
        newEvent.maxResalePrice = maxResalePrice;
        newEvent.transferable = transferable;
        newEvent.refundable = refundable;
        newEvent.ticketsSold = 0; // 初期販売数は0
        newEvent.isActive = true; // デフォルトで有効
        newEvent.saleStartTime = saleStartTime;
        newEvent.saleEndTime = saleEndTime;

        // イベント作成ログを発行
        emit EventCreated(eventId, name, eventDate);
        return eventId;
    }

    /**
     * @dev イベント無効化（追加機能）
     */
    function deactivateEvent(uint256 eventId) external onlyAuthorizedSeller {
        events[eventId].isActive = false;
    }

    // ===== チケット購入機能 =====

    /**
     * @dev チケット購入
     */
    function purchaseTicket(
        uint256 eventId,
        string memory seatInfo
    )
        public
        payable
        onlyVerifiedUser
        whenEventActive(eventId)
        onlyAllowedRegion(eventId)
        nonReentrant
        whenNotPaused
        returns (uint256)
    {
        Event storage eventInfo = events[eventId];
        require(bytes(eventInfo.name).length > 0, "Event does not exist");
        require(eventInfo.ticketsSold < eventInfo.maxTickets, "Event sold out");
        require(
            msg.value == eventInfo.originalPrice,
            "Incorrect payment amount"
        );
        require(block.timestamp >= eventInfo.saleStartTime, "Sale not started");
        require(block.timestamp <= eventInfo.saleEndTime, "Sale ended");

        // 購入制限チェック
        uint256 userLimit = userPurchaseLimit[msg.sender];
        if (userLimit == 0) userLimit = 2; // デフォルト制限
        require(
            eventInfo.purchaseCount[msg.sender] < userLimit,
            "Purchase limit exceeded"
        );

        _ticketIds.increment();
        uint256 ticketId = _ticketIds.current();

        // シークレットハッシュ生成（入場認証用）
        bytes32 secretHash = keccak256(
            abi.encodePacked(ticketId, msg.sender, block.timestamp)
        );

        // チケット情報保存
        tickets[ticketId] = Ticket({
            eventId: eventId,
            originalBuyer: msg.sender,
            purchasePrice: eventInfo.originalPrice,
            purchaseTime: block.timestamp,
            isUsed: false,
            seatInfo: seatInfo,
            transferCount: 0,
            secretHash: secretHash
        });

        // 購入カウント更新
        eventInfo.purchaseCount[msg.sender]++;
        eventInfo.ticketsSold++;

        _mint(msg.sender, ticketId);

        emit TicketMinted(ticketId, eventId, msg.sender);
        return ticketId;
    }

    // ===== チケット転売機能 =====

    /**
     * @dev 時間制限転売の有効化
     */
    function enableTimeLimitedResale(
        uint256 ticketId,
        uint256 duration
    ) external {
        require(_exists(ticketId), "Ticket does not exist");
        require(ownerOf(ticketId) == msg.sender, "Not ticket owner");
        require(duration > 0 && duration <= 7 days, "Invalid duration");

        Ticket storage ticket = tickets[ticketId];
        Event storage eventInfo = events[ticket.eventId];
        require(eventInfo.transferable, "Ticket not transferable");
        require(!ticket.isUsed, "Ticket already used");

        uint256 endTime = block.timestamp + duration;
        require(
            endTime < eventInfo.eventDate,
            "Resale period extends beyond event date"
        );

        timeLimitedResaleEnabled[ticketId] = true;
        timeLimitedResaleEnd[ticketId] = endTime;

        emit TimeLimitedResaleEnabled(ticketId, endTime);
    }

    /**
     * @dev チケット転売
     */
    function resellTicket(
        uint256 ticketId,
        address to,
        uint256 price
    ) external payable nonReentrant whenNotPaused {
        require(_exists(ticketId), "Ticket does not exist");
        require(ownerOf(ticketId) == msg.sender, "Not ticket owner");
        require(to != address(0), "Invalid recipient");
        require(verifiedUsers[to], "Recipient not verified");
        require(!blacklistedUsers[to], "Recipient is blacklisted");
        require(msg.value == price, "Incorrect payment amount");

        Ticket storage ticket = tickets[ticketId];
        Event storage eventInfo = events[ticket.eventId];

        require(eventInfo.transferable, "Ticket not transferable");
        require(!ticket.isUsed, "Ticket already used");
        require(
            block.timestamp < eventInfo.eventDate,
            "Event has already occurred"
        );
        require(
            block.timestamp >= ticket.purchaseTime + TRANSFER_COOLDOWN,
            "Transfer cooldown not met"
        );
        require(
            price <= eventInfo.maxResalePrice,
            "Price exceeds maximum resale price"
        );
        require(
            ticket.transferCount < MAX_TRANSFER_COUNT,
            "Transfer count exceeded"
        );

        // 時間制限転売チェック
        if (timeLimitedResaleEnabled[ticketId]) {
            require(
                block.timestamp <= timeLimitedResaleEnd[ticketId],
                "Time limited resale period ended"
            );
        }

        // 転売価格制限（オリジナル購入者以外）
        if (msg.sender != ticket.originalBuyer) {
            require(
                price <= ticket.purchasePrice,
                "Secondary resale must not exceed previous price"
            );
        }

        // プラットフォーム手数料計算
        uint256 platformFee = (price * PLATFORM_FEE_RATE) / 10000;
        uint256 sellerAmount = price - platformFee;

        // 転売履歴記録
        transferHistories[ticketId].push(
            TransferHistory({
                from: msg.sender,
                to: to,
                price: price,
                timestamp: block.timestamp
            })
        );

        // 転売回数更新
        ticket.transferCount++;

        // 所有権移転
        _transfer(msg.sender, to, ticketId);

        // 支払い処理
        payable(msg.sender).transfer(sellerAmount);
        payable(feeRecipient).transfer(platformFee);

        emit TicketTransferred(ticketId, msg.sender, to, price);
    }

    // ===== チケット使用機能 =====

    /**
     * @dev チケット使用（署名検証付き）
     */
    /**
     * @dev チケット使用（署名検証付き）
     *
     * イベント会場等でチケットを使用する際、NFT所有者の署名とシークレットを検証し、
     * 不正利用や二重利用を防止する。公式販売者のみ実行可能。
     *
     * @param ticketId 使用するチケットID
     * @param secret 入場用シークレット（乱数等）
     * @param signature NFT所有者による署名
     */
    function useTicketWithSignature(
        uint256 ticketId,
        bytes32 secret,
        bytes memory signature
    ) external onlyAuthorizedSeller whenNotPaused {
        // チケット存在チェック
        require(_exists(ticketId), "Ticket does not exist");
        // シークレットの二重利用防止
        require(!usedSecrets[secret], "Secret already used");

        // チケット情報取得
        Ticket storage ticket = tickets[ticketId];
        // 既に使用済みか
        require(!ticket.isUsed, "Ticket already used");

        // イベント情報取得
        Event storage eventInfo = events[ticket.eventId];
        // イベント開始2時間前以降、終了6時間後以前のみ使用可能
        require(
            block.timestamp >= eventInfo.eventDate - 2 hours,
            "Too early to use ticket"
        );
        require(
            block.timestamp <= eventInfo.eventDate + 6 hours,
            "Too late to use ticket"
        );

        // 署名検証（NFT所有者がticketIdとsecretで署名したことを確認）
        bytes32 messageHash = keccak256(abi.encodePacked(ticketId, secret));
        address signer = messageHash.toEthSignedMessageHash().recover(
            signature
        );
        require(signer == ownerOf(ticketId), "Invalid signature");

        // チケット使用処理（使用済みフラグ・シークレット登録）
        ticket.isUsed = true;
        usedSecrets[secret] = true;

        // ログ発行
        emit TicketUsed(ticketId, secret);
    }

    // ===== 返金機能 =====

    /**
     * @dev チケット返金
     */
    function refundTicket(
        uint256 ticketId
    ) external nonReentrant whenNotPaused {
        require(_exists(ticketId), "Ticket does not exist");
        require(ownerOf(ticketId) == msg.sender, "Not ticket owner");

        Ticket storage ticket = tickets[ticketId];
        Event storage eventInfo = events[ticket.eventId];

        require(eventInfo.refundable, "Ticket not refundable");
        require(!ticket.isUsed, "Ticket already used");
        require(
            block.timestamp <=
                eventInfo.eventDate - REFUND_DEADLINE_HOURS * 1 hours,
            "Refund deadline passed"
        );

        uint256 refundAmount = ticket.purchasePrice;

        // 返金手数料計算
        uint256 fee = (refundAmount * refundFeeRate) / 10000;
        uint256 actualRefund = refundAmount - fee;

        // チケット削除
        _burn(ticketId);
        delete tickets[ticketId];

        // 購入カウント減算
        if (eventInfo.purchaseCount[msg.sender] > 0) {
            eventInfo.purchaseCount[msg.sender]--;
        }
        eventInfo.ticketsSold--;

        // 返金実行
        payable(msg.sender).transfer(actualRefund);
        if (fee > 0) {
            payable(feeRecipient).transfer(fee);
        }

        emit TicketRefunded(ticketId, msg.sender, actualRefund);
    }

    // ===== 抽選システム =====

    /**
     * @dev 抽選システムの作成
     */
    function createLottery(
        uint256 eventId,
        uint256 applicationStart,
        uint256 applicationEnd,
        uint256 maxWinners
    ) external onlyAuthorizedSeller whenEventActive(eventId) {
        require(
            applicationStart < applicationEnd,
            "Invalid application period"
        );
        require(
            applicationEnd < events[eventId].saleStartTime,
            "Lottery must end before sale starts"
        );
        require(maxWinners > 0, "Invalid winner count");
        require(!lotteries[eventId].isActive, "Lottery already exists");

        lotteries[eventId] = LotteryInfo({
            applicationStart: applicationStart,
            applicationEnd: applicationEnd,
            maxWinners: maxWinners,
            totalApplications: 0,
            isCompleted: false,
            isActive: true,
            winnerCount: 0
        });

        emit LotteryCreated(eventId, applicationEnd, maxWinners);
    }

    /**
     * @dev 抽選応募
     */
    function enterLottery(
        uint256 eventId
    ) external onlyVerifiedUser onlyAllowedRegion(eventId) whenNotPaused {
        LotteryInfo storage lottery = lotteries[eventId];
        require(lottery.isActive, "Lottery not active");
        require(
            block.timestamp >= lottery.applicationStart,
            "Application not started"
        );
        require(
            block.timestamp <= lottery.applicationEnd,
            "Application period ended"
        );
        require(!lotteryApplications[eventId][msg.sender], "Already applied");
        require(!lottery.isCompleted, "Lottery already completed");

        lotteryApplications[eventId][msg.sender] = true;
        lotteryParticipants[eventId].push(msg.sender);
        lottery.totalApplications++;

        emit LotteryEntered(eventId, msg.sender);
    }

    /**
     * @dev 抽選実行（簡易版 - 実際はより安全なランダム性が必要）
     */
    function executeLottery(
        uint256 eventId,
        uint256 randomSeed
    ) external onlyAuthorizedSeller {
        LotteryInfo storage lottery = lotteries[eventId];
        require(lottery.isActive, "Lottery not active");
        require(
            block.timestamp > lottery.applicationEnd,
            "Application period not ended"
        );
        require(!lottery.isCompleted, "Lottery already completed");
        require(lottery.totalApplications > 0, "No applications");

        uint256 winnersToSelect = lottery.maxWinners;
        if (winnersToSelect > lottery.totalApplications) {
            winnersToSelect = lottery.totalApplications;
        }

        // 簡易抽選アルゴリズム（実際はChainlink VRF等を使用推奨）
        address[] memory participants = lotteryParticipants[eventId];
        for (uint256 i = 0; i < winnersToSelect; i++) {
            uint256 randomIndex = (uint256(
                keccak256(abi.encodePacked(randomSeed, i, block.timestamp))
            ) % participants.length);

            // 重複当選チェック
            if (!lotteryWinners[eventId][participants[randomIndex]]) {
                lotteryWinners[eventId][participants[randomIndex]] = true;
                lottery.winnerCount++;
            }
        }

        lottery.isCompleted = true;

        emit LotteryCompleted(eventId, lottery.winnerCount);
    }

    /**
     * @dev 抽選当選者のチケット購入
     */
    function purchaseTicketAsWinner(
        uint256 eventId,
        string memory seatInfo
    )
        external
        payable
        onlyVerifiedUser
        whenEventActive(eventId)
        onlyAllowedRegion(eventId)
        nonReentrant
        whenNotPaused
        returns (uint256)
    {
        require(lotteryWinners[eventId][msg.sender], "Not a lottery winner");

        LotteryInfo storage lottery = lotteries[eventId];
        require(lottery.isCompleted, "Lottery not completed");

        // 通常の購入処理を実行（抽選当選者用の別ロジックも可能）
        return purchaseTicket(eventId, seatInfo);
    }

    // ===== 設定機能 =====

    function setUserPurchaseLimit(
        address user,
        uint256 limit
    ) external onlyOwner {
        userPurchaseLimit[user] = limit;
    }

    function setRefundFeeRate(uint256 newRate) external onlyOwner {
        require(newRate <= 1000, "Fee rate too high"); // 最大10%
        refundFeeRate = newRate;
    }

    function setFeeRecipient(address newRecipient) external onlyOwner {
        require(newRecipient != address(0), "Invalid recipient");
        feeRecipient = newRecipient;
    }

    // ===== 取得機能 =====

    function getTicketInfo(
        uint256 ticketId
    )
        external
        view
        returns (
            uint256 eventId,
            address originalBuyer,
            uint256 purchasePrice,
            uint256 purchaseTime,
            bool isUsed,
            string memory seatInfo,
            uint256 transferCount
        )
    {
        require(_exists(ticketId), "Ticket does not exist");
        Ticket storage ticket = tickets[ticketId];
        return (
            ticket.eventId,
            ticket.originalBuyer,
            ticket.purchasePrice,
            ticket.purchaseTime,
            ticket.isUsed,
            ticket.seatInfo,
            ticket.transferCount
        );
    }

    function getEventInfo(
        uint256 eventId
    )
        external
        view
        returns (
            string memory name,
            uint256 eventDate,
            uint256 maxTickets,
            uint256 originalPrice,
            uint256 maxResalePrice,
            bool transferable,
            bool refundable,
            uint256 ticketsSold,
            bool isActive,
            uint256 saleStartTime,
            uint256 saleEndTime
        )
    {
        Event storage eventInfo = events[eventId];
        return (
            eventInfo.name,
            eventInfo.eventDate,
            eventInfo.maxTickets,
            eventInfo.originalPrice,
            eventInfo.maxResalePrice,
            eventInfo.transferable,
            eventInfo.refundable,
            eventInfo.ticketsSold,
            eventInfo.isActive,
            eventInfo.saleStartTime,
            eventInfo.saleEndTime
        );
    }

    /**
     * @dev 転売履歴取得（追加機能）
     */
    function getTransferHistory(
        uint256 ticketId
    ) external view returns (TransferHistory[] memory) {
        return transferHistories[ticketId];
    }

    /**
     * @dev 抽選情報取得
     */
    function getLotteryInfo(
        uint256 eventId
    )
        external
        view
        returns (
            uint256 applicationStart,
            uint256 applicationEnd,
            uint256 maxWinners,
            uint256 totalApplications,
            bool isCompleted,
            bool isActive,
            uint256 winnerCount
        )
    {
        LotteryInfo storage lottery = lotteries[eventId];
        return (
            lottery.applicationStart,
            lottery.applicationEnd,
            lottery.maxWinners,
            lottery.totalApplications,
            lottery.isCompleted,
            lottery.isActive,
            lottery.winnerCount
        );
    }

    /**
     * @dev 抽選当選確認
     */
    function isLotteryWinner(
        uint256 eventId,
        address user
    ) external view returns (bool) {
        return lotteryWinners[eventId][user];
    }

    /**
     * @dev 抽選応募確認
     */
    function hasAppliedToLottery(
        uint256 eventId,
        address user
    ) external view returns (bool) {
        return lotteryApplications[eventId][user];
    }

    /**
     * @dev 時間制限転売状況確認
     */
    function getTimeLimitedResaleInfo(
        uint256 ticketId
    ) external view returns (bool enabled, uint256 endTime) {
        return (
            timeLimitedResaleEnabled[ticketId],
            timeLimitedResaleEnd[ticketId]
        );
    }

    /**
     * @dev イベント別許可地域取得
     */
    function getEventAllowedRegions(
        uint256 eventId
    ) external view returns (bytes32[] memory) {
        return eventRegions[eventId];
    }

    // ===== 管理機能 =====

    function withdrawFunds() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        payable(owner()).transfer(balance);
    }

    /**
     * @dev 緊急停止機能
     */
    function emergencyPause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev 緊急資金引き出し（追加機能）
     */
    function emergencyWithdraw(
        address recipient,
        uint256 amount
    ) external onlyOwner whenPaused {
        require(recipient != address(0), "Invalid recipient");
        require(amount <= address(this).balance, "Insufficient balance");
        payable(recipient).transfer(amount);
        emit EmergencyWithdraw(recipient, amount);
    }

    // ===== Override functions =====

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }
}
