// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IZKRollup {
    struct RollupBlock {
        bytes32 merkleRoot;
        uint256 blockNumber;
        uint256 timestamp;
        bytes32[] publicInputs;
        bytes proof;
    }
    
    struct RollupTransaction {
        address sender;
        address recipient;
        uint256 amount;
        bytes32 nullifier;
        bytes32 commitment;
        bytes proof;
    }
    
    event RollupBlockSubmitted(
        uint256 indexed blockNumber,
        bytes32 merkleRoot,
        bytes32[] publicInputs
    );
    
    event RollupTransactionSubmitted(
        bytes32 indexed transactionId,
        address indexed sender,
        address indexed recipient,
        uint256 amount
    );
    
    event RollupStateUpdated(
        uint256 indexed blockNumber,
        bytes32 merkleRoot
    );
    
    function submitBlock(
        bytes32 merkleRoot,
        bytes32[] calldata publicInputs,
        bytes calldata proof
    ) external returns (uint256);
    
    function submitTransaction(
        address recipient,
        uint256 amount,
        bytes32 nullifier,
        bytes32 commitment,
        bytes calldata proof
    ) external returns (bytes32);
    
    function verifyBlock(
        uint256 blockNumber,
        bytes32[] calldata publicInputs,
        bytes calldata proof
    ) external view returns (bool);
    
    function verifyTransaction(
        bytes32 transactionId,
        bytes calldata proof
    ) external view returns (bool);
    
    function getBlock(uint256 blockNumber) external view returns (RollupBlock memory);
    
    function getTransaction(bytes32 transactionId) external view returns (RollupTransaction memory);
    
    function getLatestBlockNumber() external view returns (uint256);
    
    function getMerkleRoot() external view returns (bytes32);
} 