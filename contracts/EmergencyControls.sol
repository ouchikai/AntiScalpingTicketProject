// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title EmergencyControls
 * @dev 緊急時の制御機能を提供
 */
abstract contract EmergencyControls is Ownable, Pausable {
    event EmergencyWithdrawal(address indexed recipient, uint256 amount);
    event FundsWithdrawn(uint256 amount);

    function emergencyPause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function withdrawFunds() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        payable(owner()).transfer(balance);
        emit FundsWithdrawn(balance);
    }

    function emergencyWithdraw(
        address recipient,
        uint256 amount
    ) external onlyOwner whenPaused {
        require(recipient != address(0), "Invalid recipient");
        require(amount <= address(this).balance, "Insufficient balance");

        payable(recipient).transfer(amount);
        emit EmergencyWithdrawal(recipient, amount);
    }
}
