// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IZCashIntegration {
    struct ShieldedTransaction {
        address sender;
        uint256 timestamp;
        bytes32[] publicInputs;
        bytes proof;
        bytes32 viewingKey;
    }
    
    event ShieldedTransactionCreated(
        bytes32 indexed transactionId,
        address indexed sender,
        bytes32 viewingKey
    );
    
    event NullifierUsed(bytes32 indexed nullifier);
    
    event ViewingKeyRevoked(bytes32 indexed viewingKey);
    
    function createShieldedTransaction(
        bytes32[] calldata publicInputs,
        bytes calldata proof,
        bytes32 viewingKey
    ) external returns (bytes32);
    
    function verifyShieldedTransaction(
        bytes32 transactionId,
        bytes32[] calldata publicInputs,
        bytes calldata proof
    ) external view returns (bool);
    
    function getShieldedTransaction(
        bytes32 transactionId,
        bytes32 viewingKey
    ) external view returns (ShieldedTransaction memory);
    
    function getTransactionsByViewingKey(
        address owner
    ) external view returns (bytes32[] memory);
    
    function verifyNullifier(bytes32 nullifier) external view returns (bool);
    
    function markNullifierUsed(bytes32 nullifier) external;
    
    function revokeViewingKey(bytes32 viewingKey) external;
    
    function batchVerifyTransactions(
        bytes32[] calldata transactionIds,
        bytes32[][] calldata publicInputs,
        bytes[] calldata proofs
    ) external view returns (bool[] memory);
} 