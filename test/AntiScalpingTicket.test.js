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
            const now = Math.floor(Date.now() / 1000);
            const tx = await antiScalpingTicket.createEvent(
                "Concert",
                now + 3600,
                100,
                ethers.utils.parseEther("0.1"),
                ethers.utils.parseEther("0.1"), // maxResalePrice = originalPrice
                true,
                true,
                now,
                now + 1800
            );
            const receipt = await tx.wait();
            const eventId = receipt.events.find(e => e.event === "EventCreated").args.eventId;
            const eventInfo = await antiScalpingTicket.getEventInfo(eventId);
            expect(eventInfo.name).to.equal("Concert");
        });
    });

    describe("Ticket Purchase", function () {
        it("Should allow a verified user to purchase a ticket", async function () {
            await antiScalpingTicket.addVerifiedUser(addr1.address);
            const now = Math.floor(Date.now() / 1000);
            const tx = await antiScalpingTicket.createEvent(
                "Concert",
                now + 3600,
                100,
                ethers.utils.parseEther("0.1"),
                ethers.utils.parseEther("0.1"),
                true,
                true,
                now,
                now + 1800
            );
            const receipt = await tx.wait();
            const eventId = receipt.events.find(e => e.event === "EventCreated").args.eventId;
            await expect(
                antiScalpingTicket.connect(addr1).purchaseTicket(eventId, "A1", { value: ethers.utils.parseEther("0.1") })
            ).to.emit(antiScalpingTicket, "TicketMinted");
        });
    });

    describe("Ticket Resale", function () {
        it("Should allow ticket resale within limits", async function () {
            await antiScalpingTicket.addVerifiedUser(addr1.address);
            await antiScalpingTicket.addVerifiedUser(addr2.address);
            const now = Math.floor(Date.now() / 1000);
            const tx = await antiScalpingTicket.createEvent(
                "Concert",
                now + (27 * 3600), // 27時間後
                100,
                ethers.utils.parseEther("0.1"),
                ethers.utils.parseEther("0.1"),
                true,
                true,
                now,
                now + 3600
            );
            const receipt = await tx.wait();
            const eventId = receipt.events.find(e => e.event === "EventCreated").args.eventId;
            const ticketTx = await antiScalpingTicket.connect(addr1).purchaseTicket(eventId, "A1", { value: ethers.utils.parseEther("0.1") });
            const ticketReceipt = await ticketTx.wait();
            const ticketId = ticketReceipt.events.find(e => e.event === "TicketMinted").args.ticketId;
            await antiScalpingTicket.connect(addr1).enableTimeLimitedResale(ticketId, 25 * 3600); // 25時間 resale period
            await ethers.provider.send("evm_increaseTime", [24 * 3600 + 1]);
            await ethers.provider.send("evm_mine", []);
            await expect(
                antiScalpingTicket.connect(addr1).resellTicket(ticketId, addr2.address, ethers.utils.parseEther("0.1"), { value: ethers.utils.parseEther("0.1") })
            ).to.emit(antiScalpingTicket, "TicketTransferred");
        });
    });
});