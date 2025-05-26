// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../libraries/LegacyTypes.sol";
import "../verifiers/Halo2Verifier.sol";

contract LegacyProofGenerator is ReentrancyGuard {
    // Constants
    uint256 private constant PROOF_EXPIRY = 1 hours;
    
    // Storage
    mapping(bytes32 => LegacyTypes.Proof) private _proofs;
    mapping(address => uint256) private _lastProofGeneration;
    
    // Halo2 verifier
    Halo2Verifier public halo2Verifier;
    
    // Events
    event ProofGenerated(
        bytes32 indexed proofId,
        address indexed generator,
        uint256 expiry
    );
    event ProofVerified(
        bytes32 indexed proofId,
        bool isValid
    );
    event ProofExpired(
        bytes32 indexed proofId
    );
    
    constructor(address _halo2Verifier) {
        halo2Verifier = Halo2Verifier(_halo2Verifier);
    }
    
    function generateProof(
        bytes32 proofId,
        bytes32[] calldata publicInputs,
        bytes calldata proof
    ) external nonReentrant {
        require(_proofs[proofId].generator == address(0), "Proof already exists");
        require(block.timestamp >= _lastProofGeneration[msg.sender] + 1 minutes, "Too many proofs");
        
        _proofs[proofId] = LegacyTypes.Proof({
            generator: msg.sender,
            publicInputs: publicInputs,
            proof: proof,
            timestamp: block.timestamp,
            expiry: block.timestamp + PROOF_EXPIRY,
            isVerified: false
        });
        
        _lastProofGeneration[msg.sender] = block.timestamp;
        
        emit ProofGenerated(proofId, msg.sender, block.timestamp + PROOF_EXPIRY);
    }
    
    function verifyProof(
        bytes32 proofId,
        bytes32[] calldata publicInputs,
        bytes calldata proof
    ) external nonReentrant returns (bool) {
        require(_proofs[proofId].generator != address(0), "Proof does not exist");
        require(block.timestamp <= _proofs[proofId].expiry, "Proof expired");
        
        bool isValid = halo2Verifier.verifyProof(proofId, publicInputs, proof);
        _proofs[proofId].isVerified = isValid;
        
        emit ProofVerified(proofId, isValid);
        return isValid;
    }
    
    function checkProofExpiry(bytes32 proofId) external {
        if (block.timestamp > _proofs[proofId].expiry) {
            delete _proofs[proofId];
            emit ProofExpired(proofId);
        }
    }
    
    function getProof(bytes32 proofId) external view returns (LegacyTypes.Proof memory) {
        return _proofs[proofId];
    }
    
    function isProofValid(bytes32 proofId) external view returns (bool) {
        LegacyTypes.Proof storage proof = _proofs[proofId];
        return proof.generator != address(0) && 
               block.timestamp <= proof.expiry && 
               proof.isVerified;
    }
} 