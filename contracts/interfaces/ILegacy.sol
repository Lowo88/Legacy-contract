// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../libraries/LegacyTypes.sol";

interface ILegacy is IERC20 {
    // Vault Management
    function createVault(uint256 amount, uint256 unlockTimestamp, address beneficiary) external;
    function createPrivateVault(bytes32 vaultId, uint256 amount, uint256 unlockTimestamp, bytes32[] calldata publicInputs, bytes calldata proof) external;
    function claimFromPrivateVault(bytes32 vaultId, bytes32[] calldata publicInputs, bytes calldata proof) external;
    function cancelPrivateVault(bytes32 vaultId, bytes32[] calldata publicInputs, bytes calldata proof) external;
    function extendPrivateVault(bytes32 vaultId, uint256 newUnlockTimestamp, bytes32[] calldata publicInputs, bytes calldata proof) external;
    function splitPrivateVault(bytes32 vaultId, uint256[] calldata amounts, bytes32[] calldata newVaultIds, bytes32[] calldata publicInputs, bytes calldata proof) external;
    function mergePrivateVaults(bytes32[] calldata vaultIds, bytes32 newVaultId, bytes32[] calldata publicInputs, bytes calldata proof) external;

    // Asset Management
    function addPrivateAsset(bytes32 assetId, bytes32[] calldata publicInputs, bytes calldata proof) external;
    function removePrivateAsset(bytes32 assetId, bytes32[] calldata publicInputs, bytes calldata proof) external;
    function verifyPrivateAsset(bytes32 assetId, bytes32[] calldata publicInputs, bytes calldata proof) external view returns (bool);
    function addAsset(string calldata assetType, uint256 amount, uint256 price) external;

    // Emergency Access
    function addEmergencyContact(address contact, uint256 delayPeriod, uint256 accessLevel, bytes32[] calldata publicInputs, bytes calldata proof) external;
    function revokeEmergencyAccess(address contact, bytes32[] calldata publicInputs, bytes calldata proof) external;

    // View Functions
    function getVaults(address owner) external view returns (LegacyTypes.Vault[] memory);
    function getBackingAssets() external view returns (LegacyTypes.AssetBacking[] memory);
} 