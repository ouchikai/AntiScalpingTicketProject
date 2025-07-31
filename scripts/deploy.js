const hre = require("hardhat");

async function main() {
    const [deployer] = await hre.ethers.getSigners();

    console.log("Deploying contracts with the account:", deployer.address);

    const AntiScalpingTicket = await hre.ethers.getContractFactory("AntiScalpingTicket");
    const feeRecipient = "0x2546BcD3c84621e976D8185a91A922aE77ECEc30"; // ここに手数料受取人のアドレスを設定
    const antiScalpingTicket = await AntiScalpingTicket.deploy(feeRecipient);

    await antiScalpingTicket.deployed();

    console.log("AntiScalpingTicket deployed to:", antiScalpingTicket.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });