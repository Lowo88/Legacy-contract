// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IZCashIntegration.sol";
import "./verifiers/Halo2Verifier.sol";

contract ZCashIntegration is IZCashIntegration, Ownable, ReentrancyGuard {
    Halo2Verifier public immutable halo2Verifier;
    
    // Constants
    uint256 public constant MAX_TRANSACTION_AGE = 30 days;
    uint256 public constant MIN_PROOF_LENGTH = 32;
    uint256 public constant MAX_PUBLIC_INPUTS = 10;
    
    // Mapping of shielded transaction IDs to their details
    mapping(bytes32 => ShieldedTransaction) private _shieldedTransactions;
    
    // Mapping of commitment nullifiers to prevent double-spending
    mapping(bytes32 => bool) private _nullifiers;
    
    // Mapping of viewing keys to transaction IDs
    mapping(address => bytes32[]) private _viewingKeys;
    
    // Mapping of revoked viewing keys
    mapping(bytes32 => bool) private _revokedViewingKeys;
    
    constructor(address _halo2Verifier) Ownable(msg.sender) {
        require(_halo2Verifier != address(0), "Invalid verifier address");
        halo2Verifier = Halo2Verifier(_halo2Verifier);
    }
    
    function createShieldedTransaction(
        bytes32[] calldata publicInputs,
        bytes calldata proof,
        bytes32 viewingKey
    ) external override nonReentrant returns (bytes32) {
        // Validate inputs
        require(publicInputs.length > 0 && publicInputs.length <= MAX_PUBLIC_INPUTS, "Invalid public inputs length");
        require(proof.length >= MIN_PROOF_LENGTH, "Invalid proof length");
        require(viewingKey != bytes32(0), "Invalid viewing key");
        require(!_revokedViewingKeys[viewingKey], "Viewing key is revoked");
        
        // Generate a unique transaction ID
        bytes32 transactionId = keccak256(abi.encodePacked(
            msg.sender,
            block.timestamp,
            publicInputs
        ));
        
        // Verify the zero-knowledge proof
        require(
            halo2Verifier.verifyProof(transactionId, publicInputs, proof),
            "Invalid proof"
        );
        
        // Store the shielded transaction
        _shieldedTransactions[transactionId] = ShieldedTransaction({
            sender: msg.sender,
            timestamp: block.timestamp,
            publicInputs: publicInputs,
            proof: proof,
            viewingKey: viewingKey
        });
        
        // Store the viewing key for later access
        _viewingKeys[msg.sender].push(transactionId);
        
        emit ShieldedTransactionCreated(transactionId, msg.sender, viewingKey);
        
        return transactionId;
    }
    
    function verifyShieldedTransaction(
        bytes32 transactionId,
        bytes32[] calldata publicInputs,
        bytes calldata proof
    ) external view override returns (bool) {
        ShieldedTransaction storage transaction = _shieldedTransactions[transactionId];
        if (transaction.timestamp == 0) return false;
        if (block.timestamp > transaction.timestamp + MAX_TRANSACTION_AGE) return false;
        
        return halo2Verifier.verifyProof(transactionId, publicInputs, proof);
    }
    
    function getShieldedTransaction(
        bytes32 transactionId,
        bytes32 viewingKey
    ) external view override returns (ShieldedTransaction memory) {
        ShieldedTransaction storage transaction = _shieldedTransactions[transactionId];
        require(transaction.timestamp > 0, "Transaction does not exist");
        require(transaction.viewingKey == viewingKey, "Invalid viewing key");
        require(!_revokedViewingKeys[viewingKey], "Viewing key is revoked");
        require(block.timestamp <= transaction.timestamp + MAX_TRANSACTION_AGE, "Transaction expired");
        
        return transaction;
    }
    
    function getTransactionsByViewingKey(
        address owner
    ) external view override returns (bytes32[] memory) {
        return _viewingKeys[owner];
    }
    
    function verifyNullifier(bytes32 nullifier) external view override returns (bool) {
        return _nullifiers[nullifier];
    }
    
    function markNullifierUsed(bytes32 nullifier) external override onlyOwner {
        require(!_nullifiers[nullifier], "Nullifier already used");
        _nullifiers[nullifier] = true;
        emit NullifierUsed(nullifier);
    }
    
    function revokeViewingKey(bytes32 viewingKey) external onlyOwner {
        require(!_revokedViewingKeys[viewingKey], "Viewing key already revoked");
        _revokedViewingKeys[viewingKey] = true;
        emit ViewingKeyRevoked(viewingKey);
    }
    
    function batchVerifyTransactions(
        bytes32[] calldata transactionIds,
        bytes32[][] calldata publicInputs,
        bytes[] calldata proofs
    ) external view returns (bool[] memory) {
        require(
            transactionIds.length == publicInputs.length && 
            transactionIds.length == proofs.length,
            "Array lengths must match"
        );
        
        bool[] memory results = new bool[](transactionIds.length);
        
        for (uint256 i = 0; i < transactionIds.length; i++) {
            results[i] = this.verifyShieldedTransaction(
                transactionIds[i],
                publicInputs[i],
                proofs[i]
            );
        }
        
        return results;
    }
} 