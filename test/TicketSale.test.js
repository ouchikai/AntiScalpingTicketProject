const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("TicketSale", function () {
  let TicketSale, ticketSale, owner, addr1;

  beforeEach(async function () {
    TicketSale = await ethers.getContractFactory("TicketSale");
    [owner, addr1] = await ethers.getSigners();
    ticketSale = await TicketSale.deploy();
    await ticketSale.deployed();
  });

  it("should allow ticket purchase", async function () {
    // 仮のpurchaseTicket関数をテスト（実装に合わせて修正）
    expect(await ticketSale.owner()).to.equal(owner.address);
  });

  // 他の販売・転売・返金機能のテストを追加
});
