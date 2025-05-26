// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../libraries/LegacyTypes.sol";
import "../verifiers/Halo2Verifier.sol";

contract LegacyVault is ReentrancyGuard {
    // Constants
    uint256 public constant MIN_VAULT_DURATION = 30 days;
    uint256 public constant MAX_VAULT_DURATION = 3650 days * 100; // 100 years
    uint256 private constant OPERATION_COOLDOWN = 1 hours;
    uint256 private constant MIN_LGC_REQUIRED = 1 * 10**18; // 1 LGC required
    uint256 private constant MAX_BENEFICIARIES = 10;
    uint256 private constant MAX_ADMINS = 5;
    uint256 private constant EARLY_CANCELLATION_FEE = 10; // 10%

    // Storage
    mapping(address => LegacyTypes.Vault[]) private _vaults;
    mapping(bytes32 => LegacyTypes.PrivateVault) private _privateVaults;
    mapping(bytes32 => LegacyTypes.VaultTemplate) private _vaultTemplates;
    mapping(address => uint256) private _lastOperationTime;
    mapping(address => uint256) private _vaultCreationCount;
    mapping(bytes32 => LegacyTypes.VaultAccess[]) private _vaultAccess;
    mapping(bytes32 => LegacyTypes.VaultCondition[]) private _vaultConditions;
    mapping(bytes32 => LegacyTypes.VaultSchedule) private _vaultSchedules;

    // LGC Token
    IERC20 public lgcToken;
    address public dexAddress;

    // Halo2 verifier
    Halo2Verifier public halo2Verifier;

    // Events
    event VaultCreated(
        bytes32 indexed vaultId,
        address indexed owner,
        uint256 amount,
        uint256 unlockTimestamp,
        address[] beneficiaries,
        address[] admins
    );
    event PrivateVaultCreated(
        bytes32 indexed vaultId,
        uint256 unlockTimestamp,
        address[] admins
    );
    event VaultCancelled(
        bytes32 indexed vaultId,
        address indexed owner,
        uint256 feeAmount,
        uint256 returnedAmount
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
    event VaultClaimed(
        bytes32 indexed vaultId,
        address indexed beneficiary,
        uint256 amount
    );
    event VaultAccessUpdated(
        bytes32 indexed vaultId,
        address indexed user,
        uint256 accessLevel
    );
    event VaultConditionAdded(
        bytes32 indexed vaultId,
        bytes32 conditionId,
        LegacyTypes.ConditionType conditionType
    );
    event VaultScheduleUpdated(
        bytes32 indexed vaultId,
        uint256[] timestamps,
        uint256[] amounts
    );

    constructor(address _halo2Verifier, address _lgcToken, address _dexAddress) {
        halo2Verifier = Halo2Verifier(_halo2Verifier);
        lgcToken = IERC20(_lgcToken);
        dexAddress = _dexAddress;
    }

    function createVault(
        uint256 amount,
        uint256 unlockTimestamp,
        address[] calldata beneficiaries,
        address[] calldata admins,
        bool hasDeadManSwitch,
        LegacyTypes.VerificationMethod verificationMethod,
        address[] calldata verifiers,
        uint256 requiredVerifications,
        address successor,
        LegacyTypes.VaultCondition[] calldata conditions,
        LegacyTypes.VaultSchedule calldata schedule
    ) external nonReentrant {
        require(amount > 0, "Invalid amount");
        require(unlockTimestamp > block.timestamp, "Invalid timestamp");
        require(beneficiaries.length > 0 && beneficiaries.length <= MAX_BENEFICIARIES, "Invalid beneficiaries");
        require(admins.length > 0 && admins.length <= MAX_ADMINS, "Invalid admins");
        require(lgcToken.balanceOf(msg.sender) >= MIN_LGC_REQUIRED, "Must hold at least 1 LGC token");
        require(_vaultCreationCount[msg.sender] < 10, "Too many vaults");
        
        if (hasDeadManSwitch) {
            require(successor != address(0), "Invalid successor");
            if (verificationMethod == LegacyTypes.VerificationMethod.MULTI_SIG) {
                require(verifiers.length > 0, "No verifiers provided");
                require(requiredVerifications > 0 && requiredVerifications <= verifiers.length, "Invalid required verifications");
            }
        }

        bytes32 vaultId = keccak256(abi.encodePacked(
            msg.sender,
            block.timestamp,
            amount,
            unlockTimestamp
        ));

        LegacyTypes.VerificationConfig memory config = LegacyTypes.VerificationConfig({
            isEnabled: hasDeadManSwitch,
            method: verificationMethod,
            lastVerification: hasDeadManSwitch ? block.timestamp : 0,
            verificationInterval: 90 days,
            verifiers: verifiers,
            requiredVerifications: requiredVerifications
        });

        LegacyTypes.Vault memory vault = LegacyTypes.Vault({
            amount: amount,
            unlockTimestamp: unlockTimestamp,
            beneficiaries: beneficiaries,
            admins: admins,
            isActive: true,
            hasDeadManSwitch: hasDeadManSwitch,
            verificationConfig: config,
            successor: hasDeadManSwitch ? successor : address(0)
        });

        _vaults[msg.sender].push(vault);
        _vaultCreationCount[msg.sender]++;

        // Store conditions
        for (uint i = 0; i < conditions.length; i++) {
            _vaultConditions[vaultId].push(conditions[i]);
        }

        // Store schedule
        _vaultSchedules[vaultId] = schedule;

        emit VaultCreated(
            vaultId,
            msg.sender,
            amount,
            unlockTimestamp,
            beneficiaries,
            admins
        );
    }

    function createPrivateVault(
        bytes32 vaultId,
        uint256 amount,
        uint256 unlockTimestamp,
        address admin,
        bool hasDeadManSwitch,
        LegacyTypes.VerificationMethod verificationMethod,
        address[] calldata verifiers,
        uint256 requiredVerifications,
        address successor,
        bytes32[] calldata publicInputs,
        bytes calldata proof
    ) external nonReentrant {
        require(amount > 0, "Invalid amount");
        require(unlockTimestamp > block.timestamp, "Invalid timestamp");
        require(admin != address(0), "Invalid admin");
        require(_privateVaults[vaultId].amount == 0, "Vault already exists");
        require(halo2Verifier.verifyProof(vaultId, publicInputs, proof), "Invalid proof");
        require(lgcToken.balanceOf(msg.sender) >= MIN_LGC_REQUIRED, "Must hold at least 1 LGC token");
        require(_vaultCreationCount[msg.sender] < 10, "Too many vaults");

        LegacyTypes.VerificationConfig memory config = LegacyTypes.VerificationConfig({
            isEnabled: hasDeadManSwitch,
            method: verificationMethod,
            lastVerification: hasDeadManSwitch ? block.timestamp : 0,
            verificationInterval: 90 days,
            verifiers: verifiers,
            requiredVerifications: requiredVerifications
        });

        LegacyTypes.PrivateVault memory vault = LegacyTypes.PrivateVault({
            amount: amount,
            unlockTimestamp: unlockTimestamp,
            proof: proof,
            publicInputs: publicInputs,
            admin: admin,
            isAdminActive: true,
            hasDeadManSwitch: hasDeadManSwitch,
            verificationConfig: config,
            successor: hasDeadManSwitch ? successor : address(0)
        });

        _privateVaults[vaultId] = vault;
        _vaultCreationCount[msg.sender]++;
        emit PrivateVaultCreated(vaultId, unlockTimestamp, new address[](0));
    }

    function updateVaultAccess(
        bytes32 vaultId,
        address user,
        uint256 accessLevel,
        bytes32[] calldata publicInputs,
        bytes calldata proof
    ) external nonReentrant {
        require(halo2Verifier.verifyProof(vaultId, publicInputs, proof), "Invalid proof");
        require(_isVaultAdmin(vaultId, msg.sender), "Not vault admin");

        _vaultAccess[vaultId].push(LegacyTypes.VaultAccess({
            user: user,
            accessLevel: accessLevel,
            timestamp: block.timestamp
        }));

        emit VaultAccessUpdated(vaultId, user, accessLevel);
    }

    function addVaultCondition(
        bytes32 vaultId,
        LegacyTypes.ConditionType conditionType,
        bytes calldata conditionData,
        bytes32[] calldata publicInputs,
        bytes calldata proof
    ) external nonReentrant {
        require(halo2Verifier.verifyProof(vaultId, publicInputs, proof), "Invalid proof");
        require(_isVaultAdmin(vaultId, msg.sender), "Not vault admin");

        bytes32 conditionId = keccak256(abi.encodePacked(
            vaultId,
            conditionType,
            conditionData,
            block.timestamp
        ));

        _vaultConditions[vaultId].push(LegacyTypes.VaultCondition({
            conditionType: conditionType,
            conditionData: conditionData,
            isActive: true
        }));

        emit VaultConditionAdded(vaultId, conditionId, conditionType);
    }

    function updateVaultSchedule(
        bytes32 vaultId,
        uint256[] calldata timestamps,
        uint256[] calldata amounts,
        bytes32[] calldata publicInputs,
        bytes calldata proof
    ) external nonReentrant {
        require(halo2Verifier.verifyProof(vaultId, publicInputs, proof), "Invalid proof");
        require(_isVaultAdmin(vaultId, msg.sender), "Not vault admin");
        require(timestamps.length == amounts.length, "Invalid schedule");

        _vaultSchedules[vaultId] = LegacyTypes.VaultSchedule({
            timestamps: timestamps,
            amounts: amounts
        });

        emit VaultScheduleUpdated(vaultId, timestamps, amounts);
    }

    function cancelVault(
        bytes32 vaultId,
        bytes32[] calldata publicInputs,
        bytes calldata proof
    ) external nonReentrant {
        require(halo2Verifier.verifyProof(vaultId, publicInputs, proof), "Invalid proof");
        require(_isVaultAdmin(vaultId, msg.sender), "Not vault admin");

        LegacyTypes.Vault storage vault = _vaults[msg.sender][_findVaultIndex(vaultId)];
        require(vault.isActive, "Vault not active");
        require(block.timestamp < vault.unlockTimestamp, "Vault already unlocked");

        // Calculate early cancellation fee
        uint256 feeAmount = (vault.amount * EARLY_CANCELLATION_FEE) / 100;
        uint256 returnedAmount = vault.amount - feeAmount;

        // Transfer fee to DEX
        require(lgcToken.transfer(dexAddress, feeAmount), "Fee transfer failed");
        
        // Return remaining amount to owner
        require(lgcToken.transfer(msg.sender, returnedAmount), "Return transfer failed");

        vault.isActive = false;

        emit VaultCancelled(vaultId, msg.sender, feeAmount, returnedAmount);
    }

    // View functions
    function getVaults(address owner) external view returns (LegacyTypes.Vault[] memory) {
        return _vaults[owner];
    }

    function getPrivateVault(bytes32 vaultId) external view returns (LegacyTypes.PrivateVault memory) {
        return _privateVaults[vaultId];
    }

    function getVaultCreationCount(address owner) external view returns (uint256) {
        return _vaultCreationCount[owner];
    }

    function getRequiredLGCBalance() external pure returns (uint256) {
        return MIN_LGC_REQUIRED;
    }

    function getVaultAccess(bytes32 vaultId) external view returns (LegacyTypes.VaultAccess[] memory) {
        return _vaultAccess[vaultId];
    }

    function getVaultConditions(bytes32 vaultId) external view returns (LegacyTypes.VaultCondition[] memory) {
        return _vaultConditions[vaultId];
    }

    function getVaultSchedule(bytes32 vaultId) external view returns (LegacyTypes.VaultSchedule memory) {
        return _vaultSchedules[vaultId];
    }

    // Internal functions
    function _isVaultAdmin(bytes32 vaultId, address admin) internal view returns (bool) {
        LegacyTypes.Vault storage vault = _vaults[msg.sender][_findVaultIndex(vaultId)];
        for (uint i = 0; i < vault.admins.length; i++) {
            if (vault.admins[i] == admin) {
                return true;
            }
        }
        return false;
    }

    function _findVaultIndex(bytes32 vaultId) internal view returns (uint256) {
        LegacyTypes.Vault[] storage vaults = _vaults[msg.sender];
        for (uint i = 0; i < vaults.length; i++) {
            if (keccak256(abi.encode(vaults[i])) == vaultId) {
                return i;
            }
        }
        revert("Vault not found");
    }
} 