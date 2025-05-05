// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IZKRollup.sol";
import "./verifiers/Halo2Verifier.sol";
import "./ZCashIntegration.sol";

contract ZKRollup is IZKRollup, Ownable, ReentrancyGuard {
    Halo2Verifier public immutable halo2Verifier;
    ZCashIntegration public immutable zcashIntegration;
    
    // Constants
    uint256 public constant MAX_BLOCK_SIZE = 1000;
    uint256 public constant MIN_PROOF_LENGTH = 32;
    
    // State variables
    uint256 private _latestBlockNumber;
    bytes32 private _merkleRoot;
    
    // Mappings
    mapping(uint256 => RollupBlock) private _blocks;
    mapping(bytes32 => RollupTransaction) private _transactions;
    mapping(bytes32 => bool) private _nullifiers;
    mapping(bytes32 => bool) private _commitments;
    
    constructor(
        address _halo2Verifier,
        address _zcashIntegration
    ) Ownable(msg.sender) {
        require(_halo2Verifier != address(0), "Invalid verifier address");
        require(_zcashIntegration != address(0), "Invalid ZCash integration address");
        
        halo2Verifier = Halo2Verifier(_halo2Verifier);
        zcashIntegration = ZCashIntegration(_zcashIntegration);
    }
    
    function submitBlock(
        bytes32 merkleRoot,
        bytes32[] calldata publicInputs,
        bytes calldata proof
    ) external override onlyOwner nonReentrant returns (uint256) {
        require(proof.length >= MIN_PROOF_LENGTH, "Invalid proof length");
        require(publicInputs.length > 0, "Empty public inputs");
        
        // Verify the block proof
        require(
            halo2Verifier.verifyProof(
                keccak256(abi.encodePacked(merkleRoot, _latestBlockNumber)),
                publicInputs,
                proof
            ),
            "Invalid block proof"
        );
        
        // Create new block
        uint256 blockNumber = _latestBlockNumber + 1;
        _blocks[blockNumber] = RollupBlock({
            merkleRoot: merkleRoot,
            blockNumber: blockNumber,
            timestamp: block.timestamp,
            publicInputs: publicInputs,
            proof: proof
        });
        
        // Update state
        _latestBlockNumber = blockNumber;
        _merkleRoot = merkleRoot;
        
        emit RollupBlockSubmitted(blockNumber, merkleRoot, publicInputs);
        emit RollupStateUpdated(blockNumber, merkleRoot);
        
        return blockNumber;
    }
    
    function submitTransaction(
        address recipient,
        uint256 amount,
        bytes32 nullifier,
        bytes32 commitment,
        bytes calldata proof
    ) external override nonReentrant returns (bytes32) {
        require(recipient != address(0), "Invalid recipient");
        require(amount > 0, "Invalid amount");
        require(proof.length >= MIN_PROOF_LENGTH, "Invalid proof length");
        require(!_nullifiers[nullifier], "Nullifier already used");
        require(!_commitments[commitment], "Commitment already used");
        
        // Generate transaction ID
        bytes32 transactionId = keccak256(abi.encodePacked(
            msg.sender,
            recipient,
            amount,
            nullifier,
            commitment,
            block.timestamp
        ));
        
        // Verify the transaction proof
        require(
            halo2Verifier.verifyProof(
                transactionId,
                abi.encodePacked(nullifier, commitment),
                proof
            ),
            "Invalid transaction proof"
        );
        
        // Store transaction
        _transactions[transactionId] = RollupTransaction({
            sender: msg.sender,
            recipient: recipient,
            amount: amount,
            nullifier: nullifier,
            commitment: commitment,
            proof: proof
        });
        
        // Mark nullifier and commitment as used
        _nullifiers[nullifier] = true;
        _commitments[commitment] = true;
        
        emit RollupTransactionSubmitted(transactionId, msg.sender, recipient, amount);
        
        return transactionId;
    }
    
    function verifyBlock(
        uint256 blockNumber,
        bytes32[] calldata publicInputs,
        bytes calldata proof
    ) external view override returns (bool) {
        RollupBlock storage block = _blocks[blockNumber];
        if (block.timestamp == 0) return false;
        
        return halo2Verifier.verifyProof(
            keccak256(abi.encodePacked(block.merkleRoot, blockNumber)),
            publicInputs,
            proof
        );
    }
    
    function verifyTransaction(
        bytes32 transactionId,
        bytes calldata proof
    ) external view override returns (bool) {
        RollupTransaction storage transaction = _transactions[transactionId];
        if (transaction.sender == address(0)) return false;
        
        return halo2Verifier.verifyProof(
            transactionId,
            abi.encodePacked(transaction.nullifier, transaction.commitment),
            proof
        );
    }
    
    function getBlock(
        uint256 blockNumber
    ) external view override returns (RollupBlock memory) {
        return _blocks[blockNumber];
    }
    
    function getTransaction(
        bytes32 transactionId
    ) external view override returns (RollupTransaction memory) {
        return _transactions[transactionId];
    }
    
    function getLatestBlockNumber() external view override returns (uint256) {
        return _latestBlockNumber;
    }
    
    function getMerkleRoot() external view override returns (bytes32) {
        return _merkleRoot;
    }
} 