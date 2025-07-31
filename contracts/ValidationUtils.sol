// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ValidationUtils
 * @dev 共通のバリデーション機能を提供
 */
library ValidationUtils {
    function validateAddress(address addr) internal pure {
        require(addr != address(0), "Invalid address");
    }

    function validateTimeRange(uint256 start, uint256 end) internal pure {
        require(start < end, "Invalid time range");
        require(start > block.timestamp, "Start time must be in future");
    }

    function validatePrice(uint256 price) internal pure {
        require(price > 0, "Price must be positive");
    }

    function validateTicketCount(uint256 count) internal pure {
        require(count > 0 && count <= 10000, "Invalid ticket count");
    }
}
