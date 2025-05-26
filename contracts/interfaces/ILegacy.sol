// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../libraries/LegacyTypes.sol";

interface ILegacy is IERC20 {
    // Vault Management
    function createVault(
        uint256 amount,
        uint256 unlockTimestamp,
        address beneficiary,
        address admin,
        bool enableDeadManSwitch,
        LegacyTypes.VerificationMethod verificationMethod,
        address[] calldata verifiers,
        uint256 requiredVerifications,
        address successor
    ) external;

    function createPrivateVault(
        bytes32 vaultId,
        uint256 amount,
        uint256 unlockTimestamp,
        address admin,
        bool enableDeadManSwitch,
        LegacyTypes.VerificationMethod verificationMethod,
        address[] calldata verifiers,
        uint256 requiredVerifications,
        address successor,
        bytes32[] calldata publicInputs,
        bytes calldata proof
    ) external;

    function claimFromPrivateVault(bytes32 vaultId, bytes32[] calldata publicInputs, bytes calldata proof) external;
    function cancelPrivateVault(bytes32 vaultId, bytes32[] calldata publicInputs, bytes calldata proof) external;
    function extendPrivateVault(bytes32 vaultId, uint256 newUnlockTimestamp, bytes32[] calldata publicInputs, bytes calldata proof) external;
    function splitPrivateVault(bytes32 vaultId, uint256[] calldata amounts, bytes32[] calldata newVaultIds, bytes32[] calldata publicInputs, bytes calldata proof) external;
    function mergePrivateVaults(bytes32[] calldata vaultIds, bytes32 newVaultId, bytes32[] calldata publicInputs, bytes calldata proof) external;

    // Admin Management
    function requestAdminChange(bytes32 vaultId, address newAdmin, bytes32[] calldata publicInputs, bytes calldata proof) external;
    function approveAdminChange(bytes32 vaultId, bytes32[] calldata publicInputs, bytes calldata proof) external;
    function rejectAdminChange(bytes32 vaultId, bytes32[] calldata publicInputs, bytes calldata proof) external;
    function sendHeartbeat(bytes32 vaultId, bytes32[] calldata publicInputs, bytes calldata proof) external;
    function requestSuccessorChange(bytes32 vaultId, address newSuccessor, bytes32[] calldata publicInputs, bytes calldata proof) external;
    function activateSuccessor(bytes32 vaultId, bytes32[] calldata publicInputs, bytes calldata proof) external;
    function rejectSuccessorChange(
        bytes32 vaultId,
        bytes32[] calldata publicInputs,
        bytes calldata proof
    ) external;

    function approveSuccessorChange(
        bytes32 vaultId,
        bytes32[] calldata publicInputs,
        bytes calldata proof
    ) external;

    // Asset Management
    function addPrivateAsset(bytes32 assetId, bytes32[] calldata publicInputs, bytes calldata proof) external;
    function removePrivateAsset(bytes32 assetId, bytes32[] calldata publicInputs, bytes calldata proof) external;
    function verifyPrivateAsset(bytes32 assetId, bytes32[] calldata publicInputs, bytes calldata proof) external returns (bool);
    function addAsset(string calldata assetType, uint256 amount, uint256 price) external;

    // Emergency Access
    function addEmergencyContact(address contact, uint256 delayPeriod, uint256 accessLevel, bytes32[] calldata publicInputs, bytes calldata proof) external;
    function revokeEmergencyAccess(address contact, bytes32[] calldata publicInputs, bytes calldata proof) external;

    // Dead Man's Switch Functions
    function enableDeadManSwitch(
        bytes32 vaultId,
        address successor,
        bytes32[] calldata publicInputs,
        bytes calldata proof
    ) external;

    function disableDeadManSwitch(
        bytes32 vaultId,
        bytes32[] calldata publicInputs,
        bytes calldata proof
    ) external;

    // Verification Functions
    function verifyIdentity(
        bytes32 vaultId,
        LegacyTypes.VerificationMethod method,
        bytes32[] calldata publicInputs,
        bytes calldata proof
    ) external;

    function updateVerificationConfig(
        bytes32 vaultId,
        LegacyTypes.VerificationMethod method,
        address[] calldata verifiers,
        uint256 requiredVerifications,
        uint256 verificationInterval,
        bytes32[] calldata publicInputs,
        bytes calldata proof
    ) external;

    // View Functions
    function getVaults(address owner) external view returns (LegacyTypes.Vault[] memory);
    function getBackingAssets() external view returns (LegacyTypes.AssetBacking[] memory);
} 