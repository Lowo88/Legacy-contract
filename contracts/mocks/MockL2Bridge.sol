// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockL2Bridge {
    mapping(address => mapping(address => uint256)) public withdrawals;
    
    event Withdrawal(
        address indexed from,
        address indexed token,
        uint256 amount
    );

    function withdraw(
        address to,
        address token,
        uint256 amount
    ) external {
        withdrawals[to][token] += amount;
        
        emit Withdrawal(msg.sender, token, amount);
    }

    function getWithdrawal(
        address account,
        address token
    ) external view returns (uint256) {
        return withdrawals[account][token];
    }
} 