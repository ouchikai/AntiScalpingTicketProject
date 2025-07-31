// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

abstract contract LotteryManager {
    struct LotteryInfo {
        uint256 applicationStart;
        uint256 applicationEnd;
        uint256 maxWinners;
        uint256 totalApplications;
        bool isCompleted;
        bool isActive;
        uint256 winnerCount;
    }

    mapping(uint256 => LotteryInfo) public lotteries;
    mapping(uint256 => mapping(address => bool)) public lotteryApplications;
    mapping(uint256 => address[]) public lotteryParticipants;
    mapping(uint256 => mapping(address => bool)) public lotteryWinners;

    event LotteryCreated(
        uint256 indexed eventId,
        uint256 applicationEnd,
        uint256 maxWinners
    );
    event LotteryEntered(uint256 indexed eventId, address indexed user);
    event LotteryCompleted(uint256 indexed eventId, uint256 winnerCount);
}
