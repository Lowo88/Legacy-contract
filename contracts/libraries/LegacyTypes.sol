// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library LegacyTypes {
    struct Vault {
        uint256 amount;
        uint256 unlockTimestamp;
        address beneficiary;
    }

    struct PrivateVault {
        uint256 amount;
        uint256 unlockTimestamp;
        bytes proof;
        bytes32[] publicInputs;
    }

    struct PrivateAsset {
        bytes proof;
        bytes32[] publicInputs;
        uint256 timestamp;
    }

    struct AssetBacking {
        string assetType;
        uint256 amount;
        uint256 price;
    }

    struct EmergencyContact {
        address contact;
        uint256 delayPeriod;
        uint256 accessLevel;
        bool isActive;
    }

    struct VaultTemplate {
        string name;
        string description;
        string[] tags;
        uint256 defaultDuration;
        uint256 defaultAmount;
        bytes32[] requiredProofs;
    }

    struct VaultCategory {
        string name;
        string description;
        bytes32[] vaultIds;
    }

    struct VaultHealth {
        uint256 lastCheck;
        uint256 healthScore;
        bool needsAttention;
        string[] warnings;
    }

    struct MultiSigOperation {
        address[] signers;
        uint256 requiredSignatures;
        bytes32 operationHash;
        bool executed;
    }
} 