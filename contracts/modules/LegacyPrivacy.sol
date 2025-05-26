// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../libraries/LegacyTypes.sol";
import "../verifiers/Halo2Verifier.sol";

contract LegacyPrivacy is ReentrancyGuard {
    // Privacy-related storage
    mapping(bytes32 => bool) private _nullifiers;
    mapping(bytes32 => LegacyTypes.ShieldedBalance) private _shieldedBalances;
    mapping(address => bytes32[]) private _viewingKeys;
    mapping(bytes32 => bool) private _revokedViewingKeys;
    mapping(bytes32 => LegacyTypes.PrivateAsset) private _privateAssets;

    // Halo2 verifier
    Halo2Verifier public halo2Verifier;

    // Events
    event ShieldedTransfer(
        bytes32 indexed nullifier,
        bytes32 indexed commitment,
        uint256 amount
    );
    event ViewingKeyCreated(
        address indexed owner,
        bytes32 indexed viewingKey
    );
    event ViewingKeyRevoked(
        bytes32 indexed viewingKey
    );
    event ShieldedBalanceUpdated(
        bytes32 indexed commitment,
        uint256 newBalance
    );
    event PrivateAssetAdded(
        bytes32 indexed assetId,
        bytes32[] publicInputs
    );
    event PrivateAssetRemoved(
        bytes32 indexed assetId
    );

    constructor(address _halo2Verifier) {
        halo2Verifier = Halo2Verifier(_halo2Verifier);
    }

    function createShieldedTransfer(
        bytes32 nullifier,
        bytes32 commitment,
        uint256 amount,
        bytes calldata proof
    ) external nonReentrant {
        require(!_nullifiers[nullifier], "Nullifier already used");
        require(amount > 0, "Invalid amount");
        
        bytes32[] memory publicInputs = new bytes32[](3);
        publicInputs[0] = nullifier;
        publicInputs[1] = commitment;
        publicInputs[2] = bytes32(amount);
        
        require(
            halo2Verifier.verifyProof(
                keccak256(abi.encodePacked(nullifier, commitment, amount)),
                publicInputs,
                proof
            ),
            "Invalid proof"
        );

        _nullifiers[nullifier] = true;
        _shieldedBalances[commitment].amount += amount;
        _shieldedBalances[commitment].lastUpdate = block.timestamp;

        emit ShieldedTransfer(nullifier, commitment, amount);
        emit ShieldedBalanceUpdated(commitment, _shieldedBalances[commitment].amount);
    }

    function createViewingKey() external returns (bytes32) {
        bytes32 viewingKey = keccak256(abi.encodePacked(
            msg.sender,
            block.timestamp,
            block.prevrandao
        ));
        
        _viewingKeys[msg.sender].push(viewingKey);
        emit ViewingKeyCreated(msg.sender, viewingKey);
        
        return viewingKey;
    }

    function revokeViewingKey(bytes32 viewingKey) external {
        require(_viewingKeys[msg.sender].length > 0, "No viewing keys");
        
        for (uint i = 0; i < _viewingKeys[msg.sender].length; i++) {
            if (_viewingKeys[msg.sender][i] == viewingKey) {
                _viewingKeys[msg.sender][i] = _viewingKeys[msg.sender][_viewingKeys[msg.sender].length - 1];
                _viewingKeys[msg.sender].pop();
                _revokedViewingKeys[viewingKey] = true;
                emit ViewingKeyRevoked(viewingKey);
                break;
            }
        }
    }

    function getShieldedBalance(bytes32 commitment, bytes32 viewingKey) external view returns (uint256) {
        require(!_revokedViewingKeys[viewingKey], "Viewing key revoked");
        return _shieldedBalances[commitment].amount;
    }

    function addPrivateAsset(
        bytes32 assetId,
        bytes32[] calldata publicInputs,
        bytes calldata proof
    ) external nonReentrant {
        require(_privateAssets[assetId].proof.length == 0, "Asset already exists");
        require(halo2Verifier.verifyProof(assetId, publicInputs, proof), "Invalid proof");

        LegacyTypes.PrivateAsset memory asset = LegacyTypes.PrivateAsset({
            proof: proof,
            publicInputs: publicInputs,
            timestamp: block.timestamp
        });

        _privateAssets[assetId] = asset;
        emit PrivateAssetAdded(assetId, publicInputs);
    }

    function removePrivateAsset(
        bytes32 assetId,
        bytes32[] calldata publicInputs,
        bytes calldata proof
    ) external nonReentrant {
        require(_privateAssets[assetId].proof.length > 0, "Asset does not exist");
        require(halo2Verifier.verifyProof(assetId, publicInputs, proof), "Invalid proof");

        delete _privateAssets[assetId];
        emit PrivateAssetRemoved(assetId);
    }

    function verifyPrivateAsset(
        bytes32 assetId,
        bytes32[] calldata publicInputs,
        bytes calldata proof
    ) external returns (bool) {
        LegacyTypes.PrivateAsset storage asset = _privateAssets[assetId];
        if (asset.proof.length == 0) return false;
        return halo2Verifier.verifyProof(assetId, publicInputs, proof);
    }
} 