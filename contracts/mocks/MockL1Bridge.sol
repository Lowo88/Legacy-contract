// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockL1Bridge {
    mapping(address => mapping(address => uint256)) public deposits;
    
    event Deposit(
        address indexed from,
        address indexed token,
        uint256 amount
    );

    function deposit(
        address to,
        address token,
        uint256 amount,
        bytes calldata data
    ) external payable {
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        deposits[to][token] += amount;
        
        emit Deposit(msg.sender, token, amount);
    }

    function getDeposit(
        address account,
        address token
    ) external view returns (uint256) {
        return deposits[account][token];
    }
} 