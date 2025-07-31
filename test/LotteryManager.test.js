const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("LotteryManager", function () {
  let LotteryManager, lotteryManager, owner, addr1;

  beforeEach(async function () {
    LotteryManager = await ethers.getContractFactory("LotteryManager");
    [owner, addr1] = await ethers.getSigners();
    lotteryManager = await LotteryManager.deploy();
    await lotteryManager.deployed();
  });

  it("should create a lottery", async function () {
    // 仮のcreateLottery関数をテスト
    expect(await lotteryManager.owner()).to.equal(owner.address);
  });

  // 他の抽選機能のテストを追加
});
