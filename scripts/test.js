const { ethers } = require("hardhat");

async function main() {
    // コントラクトをデプロイ
    const AntiScalpingTicket = await ethers.getContractFactory("AntiScalpingTicket");
    const feeRecipient = "0xYourFeeRecipientAddress"; // 手数料受取人のアドレスを指定
    const antiScalpingTicket = await AntiScalpingTicket.deploy(feeRecipient);

    await antiScalpingTicket.deployed();
    console.log("AntiScalpingTicket deployed to:", antiScalpingTicket.address);

    // テスト用のイベントを作成
    const eventId = await antiScalpingTicket.createEvent(
        "Sample Event",
        Math.floor(Date.now() / 1000) + 3600, // 1時間後
        100,
        ethers.utils.parseEther("0.1"), // 0.1 ETH
        ethers.utils.parseEther("0.2"), // 0.2 ETH
        true,
        true,
        Math.floor(Date.now() / 1000), // 現在時刻
        Math.floor(Date.now() / 1000) + 7200 // 2時間後
    );

    console.log("Event created with ID:", eventId);
}

// スクリプトを実行
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });