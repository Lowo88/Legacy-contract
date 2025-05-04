// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/ILegacy.sol";
import "./libraries/LegacyTypes.sol";
import "./verifiers/Halo2Verifier.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Legacy is ERC20, Ownable, ReentrancyGuard, ILegacy {
    using LegacyTypes for *;
    using LegacyTypes for LegacyTypes.Vault;
    using LegacyTypes for LegacyTypes.AssetBacking;
    using LegacyTypes for LegacyTypes.PrivateAsset;
    using LegacyTypes for LegacyTypes.PrivateVault;
    using LegacyTypes for LegacyTypes.EmergencyContact;

    // Storage
    mapping(address => LegacyTypes.Vault[]) private _vaults;
    mapping(bytes32 => LegacyTypes.PrivateVault) private _privateVaults;
    mapping(bytes32 => LegacyTypes.PrivateAsset) private _privateAssets;
    mapping(address => LegacyTypes.EmergencyContact[]) private _emergencyContacts;
    mapping(bytes32 => LegacyTypes.VaultTemplate) private _vaultTemplates;
    mapping(address => uint256) private _lastOperationTime;
    mapping(address => bool) private _blacklistedAddresses;
    
    uint256 private constant PRICE_PEG = 1 ether;
    uint256 private constant OPERATION_COOLDOWN = 1 hours;
    uint256 private constant MAX_EMERGENCY_CONTACTS = 5;
    
    LegacyTypes.AssetBacking[] private _backingAssets;
    uint256 public constant MIN_VAULT_DURATION = 30 days;
    uint256 public constant MAX_VAULT_DURATION = 3650 days;

    // Halo2 verifier
    Halo2Verifier public halo2Verifier;

    // Events
    event VaultCreated(
        address indexed owner,
        uint256 amount,
        uint256 unlockTimestamp,
        address beneficiary
    );
    event PrivateVaultCreated(
        bytes32 indexed vaultId,
        uint256 unlockTimestamp
    );
    event VaultCancelled(
        bytes32 indexed vaultId,
        address indexed owner
    );
    event VaultExtended(
        bytes32 indexed vaultId,
        uint256 newUnlockTimestamp
    );
    event VaultSplit(
        bytes32 indexed originalVaultId,
        bytes32[] newVaultIds
    );
    event VaultsMerged(
        bytes32[] vaultIds,
        bytes32 newVaultId
    );
    event EmergencyContactAdded(
        address indexed owner,
        address indexed contact,
        uint256 delayPeriod
    );
    event EmergencyAccessGranted(
        address indexed owner,
        address indexed contact,
        uint256 accessLevel
    );
    event EmergencyAccessRevoked(
        address indexed owner,
        address indexed contact
    );
    event BlacklistUpdated(
        address indexed address,
        bool isBlacklisted
    );

    constructor(uint256 initialSupply, address _halo2Verifier) ERC20("Legacy", "LGC") {
        _mint(msg.sender, initialSupply);
        _transferOwnership(msg.sender);
        halo2Verifier = Halo2Verifier(_halo2Verifier);
    }

    // External functions
    function transfer(address to, uint256 value) public virtual override(ERC20, IERC20) nonReentrant returns (bool) {
        return super.transfer(to, value);
    }

    function createVault(
        uint256 amount,
        uint256 unlockTimestamp,
        address beneficiary
    ) external override nonReentrant {
        require(amount > 0, "Invalid amount");
        require(unlockTimestamp > block.timestamp, "Invalid timestamp");
        require(beneficiary != address(0), "Invalid beneficiary");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");

        LegacyTypes.Vault memory vault = LegacyTypes.Vault({
            amount: amount,
            unlockTimestamp: unlockTimestamp,
            beneficiary: beneficiary
        });

        _vaults[msg.sender].push(vault);
        _transfer(msg.sender, address(this), amount);

        emit VaultCreated(msg.sender, amount, unlockTimestamp, beneficiary);
    }

    // New function to create a private vault using Halo2
    function createPrivateVault(
        bytes32 vaultId,
        uint256 amount,
        uint256 unlockTimestamp,
        bytes32[] calldata publicInputs,
        bytes calldata proof
    ) external override nonReentrant {
        require(amount > 0, "Invalid amount");
        require(unlockTimestamp > block.timestamp, "Invalid timestamp");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        require(_privateVaults[vaultId].amount == 0, "Vault already exists");

        // Verify the Halo2 proof
        require(halo2Verifier.verifyProof(vaultId, publicInputs, proof), "Invalid proof");

        LegacyTypes.PrivateVault memory vault = LegacyTypes.PrivateVault({
            amount: amount,
            unlockTimestamp: unlockTimestamp,
            proof: proof,
            publicInputs: publicInputs
        });

        _privateVaults[vaultId] = vault;
        _transfer(msg.sender, address(this), amount);

        emit PrivateVaultCreated(vaultId, unlockTimestamp);
    }

    // New function to claim from a private vault
    function claimFromPrivateVault(
        bytes32 vaultId,
        bytes32[] calldata publicInputs,
        bytes calldata proof
    ) external override nonReentrant {
        LegacyTypes.PrivateVault storage vault = _privateVaults[vaultId];
        require(vault.amount > 0, "Vault does not exist");
        require(block.timestamp >= vault.unlockTimestamp, "Vault is locked");
        require(halo2Verifier.verifyProof(vaultId, publicInputs, proof), "Invalid proof");

        uint256 amount = vault.amount;
        delete _privateVaults[vaultId];
        _transfer(address(this), msg.sender, amount);
    }

    // New function to add a private asset
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

    // New function to remove a private asset
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

    // New function to verify private asset ownership
    function verifyPrivateAsset(
        bytes32 assetId,
        bytes32[] calldata publicInputs,
        bytes calldata proof
    ) external view returns (bool) {
        LegacyTypes.PrivateAsset storage asset = _privateAssets[assetId];
        if (asset.proof.length == 0) return false;
        return halo2Verifier.verifyProof(assetId, publicInputs, proof);
    }

    function addAsset(
        string calldata assetType,
        uint256 amount,
        uint256 price
    ) external override onlyOwner {
        require(amount > 0, "Invalid amount");
        require(price > 0, "Invalid price");
        require(bytes(assetType).length > 0, "Invalid asset type");

        _backingAssets.push(LegacyTypes.AssetBacking({
            assetType: assetType,
            amount: amount,
            price: price
        }));

        emit AssetAdded(assetType, amount, price);
    }

    // Enhanced Vault Management Functions
    function cancelPrivateVault(
        bytes32 vaultId,
        bytes32[] calldata publicInputs,
        bytes calldata proof
    ) external nonReentrant {
        require(!_blacklistedAddresses[msg.sender], "Address is blacklisted");
        require(block.timestamp >= _lastOperationTime[msg.sender] + OPERATION_COOLDOWN, "Operation cooldown");
        
        LegacyTypes.PrivateVault storage vault = _privateVaults[vaultId];
        require(vault.amount > 0, "Vault does not exist");
        require(halo2Verifier.verifyProof(vaultId, publicInputs, proof), "Invalid proof");

        uint256 amount = vault.amount;
        delete _privateVaults[vaultId];
        _transfer(address(this), msg.sender, amount);
        _lastOperationTime[msg.sender] = block.timestamp;

        emit VaultCancelled(vaultId, msg.sender);
    }

    function extendPrivateVault(
        bytes32 vaultId,
        uint256 newUnlockTimestamp,
        bytes32[] calldata publicInputs,
        bytes calldata proof
    ) external nonReentrant {
        require(!_blacklistedAddresses[msg.sender], "Address is blacklisted");
        require(block.timestamp >= _lastOperationTime[msg.sender] + OPERATION_COOLDOWN, "Operation cooldown");
        
        LegacyTypes.PrivateVault storage vault = _privateVaults[vaultId];
        require(vault.amount > 0, "Vault does not exist");
        require(newUnlockTimestamp > vault.unlockTimestamp, "Invalid new timestamp");
        require(halo2Verifier.verifyProof(vaultId, publicInputs, proof), "Invalid proof");

        vault.unlockTimestamp = newUnlockTimestamp;
        _lastOperationTime[msg.sender] = block.timestamp;

        emit VaultExtended(vaultId, newUnlockTimestamp);
    }

    function splitPrivateVault(
        bytes32 vaultId,
        uint256[] calldata amounts,
        bytes32[] calldata newVaultIds,
        bytes32[] calldata publicInputs,
        bytes calldata proof
    ) external nonReentrant {
        require(!_blacklistedAddresses[msg.sender], "Address is blacklisted");
        require(block.timestamp >= _lastOperationTime[msg.sender] + OPERATION_COOLDOWN, "Operation cooldown");
        
        LegacyTypes.PrivateVault storage originalVault = _privateVaults[vaultId];
        require(originalVault.amount > 0, "Vault does not exist");
        require(halo2Verifier.verifyProof(vaultId, publicInputs, proof), "Invalid proof");

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }
        require(totalAmount == originalVault.amount, "Amounts don't match");

        delete _privateVaults[vaultId];
        for (uint256 i = 0; i < newVaultIds.length; i++) {
            _privateVaults[newVaultIds[i]] = LegacyTypes.PrivateVault({
                amount: amounts[i],
                unlockTimestamp: originalVault.unlockTimestamp,
                proof: originalVault.proof,
                publicInputs: originalVault.publicInputs
            });
        }
        _lastOperationTime[msg.sender] = block.timestamp;

        emit VaultSplit(vaultId, newVaultIds);
    }

    function mergePrivateVaults(
        bytes32[] calldata vaultIds,
        bytes32 newVaultId,
        bytes32[] calldata publicInputs,
        bytes calldata proof
    ) external nonReentrant {
        require(!_blacklistedAddresses[msg.sender], "Address is blacklisted");
        require(block.timestamp >= _lastOperationTime[msg.sender] + OPERATION_COOLDOWN, "Operation cooldown");
        
        uint256 totalAmount = 0;
        uint256 unlockTimestamp = 0;
        bytes memory mergedProof;
        bytes32[] memory mergedPublicInputs;

        for (uint256 i = 0; i < vaultIds.length; i++) {
            LegacyTypes.PrivateVault storage vault = _privateVaults[vaultIds[i]];
            require(vault.amount > 0, "Vault does not exist");
            require(halo2Verifier.verifyProof(vaultIds[i], publicInputs, proof), "Invalid proof");

            totalAmount += vault.amount;
            if (unlockTimestamp == 0 || vault.unlockTimestamp > unlockTimestamp) {
                unlockTimestamp = vault.unlockTimestamp;
                mergedProof = vault.proof;
                mergedPublicInputs = vault.publicInputs;
            }
            delete _privateVaults[vaultIds[i]];
        }

        _privateVaults[newVaultId] = LegacyTypes.PrivateVault({
            amount: totalAmount,
            unlockTimestamp: unlockTimestamp,
            proof: mergedProof,
            publicInputs: mergedPublicInputs
        });
        _lastOperationTime[msg.sender] = block.timestamp;

        emit VaultsMerged(vaultIds, newVaultId);
    }

    // Enhanced Emergency Access Functions
    function addEmergencyContact(
        address contact,
        uint256 delayPeriod,
        uint256 accessLevel,
        bytes32[] calldata publicInputs,
        bytes calldata proof
    ) external nonReentrant {
        require(!_blacklistedAddresses[msg.sender], "Address is blacklisted");
        require(contact != address(0), "Invalid contact");
        require(_emergencyContacts[msg.sender].length < MAX_EMERGENCY_CONTACTS, "Too many contacts");
        require(halo2Verifier.verifyProof(bytes32(uint256(uint160(contact))), publicInputs, proof), "Invalid proof");

        _emergencyContacts[msg.sender].push(LegacyTypes.EmergencyContact({
            contact: contact,
            delayPeriod: delayPeriod,
            accessLevel: accessLevel,
            isActive: true
        }));

        emit EmergencyContactAdded(msg.sender, contact, delayPeriod);
    }

    function revokeEmergencyAccess(
        address contact,
        bytes32[] calldata publicInputs,
        bytes calldata proof
    ) external nonReentrant {
        require(!_blacklistedAddresses[msg.sender], "Address is blacklisted");
        require(halo2Verifier.verifyProof(bytes32(uint256(uint160(contact))), publicInputs, proof), "Invalid proof");

        LegacyTypes.EmergencyContact[] storage contacts = _emergencyContacts[msg.sender];
        for (uint256 i = 0; i < contacts.length; i++) {
            if (contacts[i].contact == contact) {
                contacts[i].isActive = false;
                emit EmergencyAccessRevoked(msg.sender, contact);
                break;
            }
        }
    }

    // Security Functions
    function updateBlacklist(
        address[] calldata addresses,
        bool[] calldata isBlacklisted,
        bytes32[] calldata publicInputs,
        bytes calldata proof
    ) external onlyOwner {
        require(addresses.length == isBlacklisted.length, "Invalid input");
        require(halo2Verifier.verifyProof(bytes32(0), publicInputs, proof), "Invalid proof");

        for (uint256 i = 0; i < addresses.length; i++) {
            _blacklistedAddresses[addresses[i]] = isBlacklisted[i];
            emit BlacklistUpdated(addresses[i], isBlacklisted[i]);
        }
    }

    // View functions
    function getVaults(address owner) external view override returns (LegacyTypes.Vault[] memory) {
        return _vaults[owner];
    }

    function getBackingAssets() external view override returns (LegacyTypes.AssetBacking[] memory) {
        return _backingAssets;
    }

    // Internal functions
    function _transfer(address from, address to, uint256 amount) internal virtual override {
        super._transfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal virtual override {
        super._mint(account, amount);
    }
} 