// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockZkSync {
    mapping(address => uint256) public balances;
    
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 amount
    );

    function transfer(
        address to,
        uint256 amount,
        bytes calldata data
    ) external {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        
        balances[msg.sender] -= amount;
        balances[to] += amount;
        
        emit Transfer(msg.sender, to, amount);
    }

    function deposit(
        address token,
        uint256 amount
    ) external {
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        balances[msg.sender] += amount;
    }

    function withdraw(
        address token,
        uint256 amount
    ) external {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        
        balances[msg.sender] -= amount;
        IERC20(token).transfer(msg.sender, amount);
    }

    function getBalance(address account) external view returns (uint256) {
        return balances[account];
    }
} 