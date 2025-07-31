const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("AntiScalpingTicket", function () {
    let AntiScalpingTicket;
    let antiScalpingTicket;
    let owner;
    let addr1;
    let addr2;

    beforeEach(async function () {
        AntiScalpingTicket = await ethers.getContractFactory("AntiScalpingTicket");
        [owner, addr1, addr2] = await ethers.getSigners();
        antiScalpingTicket = await AntiScalpingTicket.deploy(owner.address);
        await antiScalpingTicket.deployed();
    });

    describe("Event Creation", function () {
        it("Should create an event", async function () {
            const eventId = await antiScalpingTicket.createEvent(
                "Concert",
                Math.floor(Date.now() / 1000) + 3600, // 1 hour from now
                100,
                ethers.utils.parseEther("0.1"),
                ethers.utils.parseEther("0.15"),
                true,
                true,
                Math.floor(Date.now() / 1000), // sale start time
                Math.floor(Date.now() / 1000) + 7200 // sale end time
            );

            const eventInfo = await antiScalpingTicket.getEventInfo(eventId);
            expect(eventInfo.name).to.equal("Concert");
        });
    });

    describe("Ticket Purchase", function () {
        it("Should allow a verified user to purchase a ticket", async function () {
            await antiScalpingTicket.addVerifiedUser(addr1.address);
            await antiScalpingTicket.createEvent(
                "Concert",
                Math.floor(Date.now() / 1000) + 3600,
                100,
                ethers.utils.parseEther("0.1"),
                ethers.utils.parseEther("0.15"),
                true,
                true,
                Math.floor(Date.now() / 1000),
                Math.floor(Date.now() / 1000) + 7200
            );

            await expect(
                antiScalpingTicket.connect(addr1).purchaseTicket(1, "A1", { value: ethers.utils.parseEther("0.1") })
            ).to.emit(antiScalpingTicket, "TicketMinted");
        });
    });

    describe("Ticket Resale", function () {
        it("Should allow ticket resale within limits", async function () {
            await antiScalpingTicket.addVerifiedUser(addr1.address);
            await antiScalpingTicket.createEvent(
                "Concert",
                Math.floor(Date.now() / 1000) + 3600,
                100,
                ethers.utils.parseEther("0.1"),
                ethers.utils.parseEther("0.15"),
                true,
                true,
                Math.floor(Date.now() / 1000),
                Math.floor(Date.now() / 1000) + 7200
            );

            await antiScalpingTicket.connect(addr1).purchaseTicket(1, "A1", { value: ethers.utils.parseEther("0.1") });
            await antiScalpingTicket.connect(addr1).enableTimeLimitedResale(1, 3600); // 1 hour resale period

            await expect(
                antiScalpingTicket.connect(addr1).resellTicket(1, addr2.address, ethers.utils.parseEther("0.12"), { value: ethers.utils.parseEther("0.12") })
            ).to.emit(antiScalpingTicket, "TicketTransferred");
        });
    });

    describe("Ticket Usage", function () {
        it("Should allow ticket usage with valid signature", async function () {
            await antiScalpingTicket.addVerifiedUser(addr1.address);
            await antiScalpingTicket.createEvent(
                "Concert",
                Math.floor(Date.now() / 1000) + 3600,
                100,
                ethers.utils.parseEther("0.1"),
                ethers.utils.parseEther("0.15"),
                true,
                true,
                Math.floor(Date.now() / 1000),
                Math.floor(Date.now() / 1000) + 7200
            );

            await antiScalpingTicket.connect(addr1).purchaseTicket(1, "A1", { value: ethers.utils.parseEther("0.1") });
            const ticketId = 1; // Assuming this is the ticket ID purchased
            const secret = ethers.utils.keccak256(ethers.utils.defaultAbiCoder.encode(["uint256", "address", "uint256"], [ticketId, addr1.address, Math.floor(Date.now() / 1000)]));

            await expect(
                antiScalpingTicket.connect(owner).useTicketWithSignature(ticketId, secret, "signature")
            ).to.emit(antiScalpingTicket, "TicketUsed");
        });
    });
});