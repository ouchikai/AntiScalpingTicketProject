// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract UserRegionManager is Ownable {
    mapping(address => bool) public verifiedUsers;
    mapping(address => bool) public blacklistedUsers;
    mapping(uint256 => mapping(address => bool)) public eventWhitelist;
    mapping(bytes32 => bool) public allowedRegions;
    mapping(address => bytes32) public userRegion;
    mapping(uint256 => bytes32[]) public eventRegions;

    event UserBlacklisted(address indexed user, string reason);
    event UserWhitelisted(uint256 indexed eventId, address indexed user);
    event RegionUpdated(address indexed user, bytes32 regionHash);

    function addVerifiedUser(address user) external onlyOwner {
        verifiedUsers[user] = true;
    }
    function removeVerifiedUser(address user) external onlyOwner {
        verifiedUsers[user] = false;
    }
    function addToBlacklist(
        address user,
        string memory reason
    ) external onlyOwner {
        blacklistedUsers[user] = true;
        emit UserBlacklisted(user, reason);
    }
    function removeFromBlacklist(address user) external onlyOwner {
        blacklistedUsers[user] = false;
    }
    function addToEventWhitelist(
        uint256 eventId,
        address user
    ) external onlyOwner {
        eventWhitelist[eventId][user] = true;
        emit UserWhitelisted(eventId, user);
    }
    function addAllowedRegion(bytes32 regionHash) external onlyOwner {
        allowedRegions[regionHash] = true;
    }
    function removeAllowedRegion(bytes32 regionHash) external onlyOwner {
        allowedRegions[regionHash] = false;
    }
    function setUserRegion(
        address user,
        bytes32 regionHash
    ) external onlyOwner {
        require(allowedRegions[regionHash], "Region not allowed");
        userRegion[user] = regionHash;
        emit RegionUpdated(user, regionHash);
    }
    function setEventAllowedRegions(
        uint256 eventId,
        bytes32[] memory regions
    ) external onlyOwner {
        delete eventRegions[eventId];
        for (uint256 i = 0; i < regions.length; i++) {
            require(allowedRegions[regions[i]], "Invalid region");
            eventRegions[eventId].push(regions[i]);
        }
    }
}
