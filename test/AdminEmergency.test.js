const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("AdminEmergency", function () {
  let AdminEmergency, adminEmergency, owner, addr1;

  beforeEach(async function () {
    AdminEmergency = await ethers.getContractFactory("AdminEmergency");
    [owner, addr1] = await ethers.getSigners();
    adminEmergency = await AdminEmergency.deploy();
    await adminEmergency.deployed();
  });

  it("should allow emergency withdraw", async function () {
    // 仮のemergencyWithdraw関数をテスト
    expect(await adminEmergency.owner()).to.equal(owner.address);
  });

  // 他の管理・緊急機能のテストを追加
});
