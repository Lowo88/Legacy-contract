// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../libraries/LegacyTypes.sol";
import "../verifiers/Halo2Verifier.sol";

contract LegacySavingsVault is ReentrancyGuard {
    // Constants
    uint256 public constant MIN_SAVINGS_DURATION = 365 days; // 1 year minimum
    uint256 public constant MAX_SAVINGS_DURATION = 365 days * 100; // 100 years maximum
    uint256 private constant OPERATION_COOLDOWN = 1 days;
    uint256 private constant MIN_LGC_REQUIRED = 1 * 10**18; // 1 LGC required
    uint256 private constant MAX_HEIRS = 10;
    uint256 private constant MAX_TRUSTEES = 5;
    uint256 private constant EARLY_WITHDRAWAL_FEE = 20; // 20% fee for early withdrawal
    uint256 private constant MAX_VAULTS_PER_ADDRESS = 5;
    uint256 private constant VERIFICATION_INTERVAL = 90 days;
    uint256 private constant EMERGENCY_UNLOCK_DELAY = 30 days;

    // Structs
    struct SavingsVault {
        uint256 amount;
        uint256 unlockTimestamp;
        address[] heirs;
        address[] trustees;
        mapping(address => bool) isHeir;
        mapping(address => bool) isTrustee;
        uint256 lastVerification;
        uint256 verificationInterval;
        bool isActive;
        string legacyMessage;
        bytes32[] conditions;
        uint256 emergencyUnlockRequestTime;
        address emergencyUnlockRequester;
        bool isEmergencyUnlockRequested;
        uint256[] verificationHistory;
    }

    struct LegacyMessage {
        string message;
        uint256 timestamp;
        address from;
    }

    struct VaultStatus {
        bool isActive;
        uint256 lastVerification;
        uint256 nextVerificationDue;
        uint256 timeUntilUnlock;
        bool isEmergencyUnlockRequested;
        uint256 emergencyUnlockTimeRemaining;
    }

    // Storage
    mapping(address => SavingsVault[]) private _savingsVaults;
    mapping(bytes32 => LegacyMessage[]) private _legacyMessages;
    mapping(address => uint256) private _lastOperationTime;
    mapping(address => uint256) private _vaultCreationCount;
    mapping(bytes32 => uint256) private _vaultTotalValue;
    mapping(address => uint256) private _userTotalVaulted;

    // LGC Token
    IERC20 public immutable lgcToken;
    address public immutable dexAddress;

    // Halo2 verifier
    Halo2Verifier public immutable halo2Verifier;

    // Events
    event SavingsVaultCreated(
        bytes32 indexed vaultId,
        address indexed owner,
        uint256 amount,
        uint256 unlockTimestamp,
        address[] heirs,
        address[] trustees
    );
    event HeirAdded(
        bytes32 indexed vaultId,
        address indexed heir
    );
    event TrusteeAdded(
        bytes32 indexed vaultId,
        address indexed trustee
    );
    event LegacyMessageAdded(
        bytes32 indexed vaultId,
        address indexed from,
        string message
    );
    event VaultUnlocked(
        bytes32 indexed vaultId,
        address indexed beneficiary,
        uint256 amount
    );
    event EarlyWithdrawal(
        bytes32 indexed vaultId,
        address indexed owner,
        uint256 amount,
        uint256 fee
    );
    event EmergencyUnlockRequested(
        bytes32 indexed vaultId,
        address indexed requester,
        uint256 unlockTime
    );
    event EmergencyUnlockCancelled(
        bytes32 indexed vaultId,
        address indexed canceller
    );
    event VaultVerified(
        bytes32 indexed vaultId,
        address indexed verifier,
        uint256 timestamp
    );

    constructor(
        address _halo2Verifier,
        address _lgcToken,
        address _dexAddress
    ) {
        halo2Verifier = Halo2Verifier(_halo2Verifier);
        lgcToken = IERC20(_lgcToken);
        dexAddress = _dexAddress;
    }

    function createSavingsVault(
        uint256 amount,
        uint256 duration,
        address[] calldata heirs,
        address[] calldata trustees,
        string calldata legacyMessage
    ) external nonReentrant {
        require(amount > 0, "Invalid amount");
        require(duration >= MIN_SAVINGS_DURATION && duration <= MAX_SAVINGS_DURATION, "Invalid duration");
        require(heirs.length > 0 && heirs.length <= MAX_HEIRS, "Invalid number of heirs");
        require(trustees.length > 0 && trustees.length <= MAX_TRUSTEES, "Invalid number of trustees");
        require(lgcToken.balanceOf(msg.sender) >= MIN_LGC_REQUIRED, "Must hold at least 1 LGC token");
        require(_vaultCreationCount[msg.sender] < MAX_VAULTS_PER_ADDRESS, "Too many savings vaults");

        // Transfer LGC tokens
        require(
            lgcToken.transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );

        bytes32 vaultId = keccak256(abi.encodePacked(
            msg.sender,
            block.timestamp,
            amount,
            duration
        ));

        SavingsVault storage vault = _savingsVaults[msg.sender].push();
        vault.amount = amount;
        vault.unlockTimestamp = block.timestamp + duration;
        vault.heirs = heirs;
        vault.trustees = trustees;
        vault.lastVerification = block.timestamp;
        vault.verificationInterval = VERIFICATION_INTERVAL;
        vault.isActive = true;
        vault.legacyMessage = legacyMessage;
        vault.verificationHistory.push(block.timestamp);

        // Set heir and trustee flags
        for (uint i = 0; i < heirs.length; i++) {
            vault.isHeir[heirs[i]] = true;
        }
        for (uint i = 0; i < trustees.length; i++) {
            vault.isTrustee[trustees[i]] = true;
        }

        _vaultCreationCount[msg.sender]++;
        _vaultTotalValue[vaultId] = amount;
        _userTotalVaulted[msg.sender] += amount;

        emit SavingsVaultCreated(
            vaultId,
            msg.sender,
            amount,
            vault.unlockTimestamp,
            heirs,
            trustees
        );
    }

    function requestEmergencyUnlock(
        bytes32 vaultId,
        bytes32[] calldata publicInputs,
        bytes calldata proof
    ) external nonReentrant {
        require(halo2Verifier.verifyProof(vaultId, publicInputs, proof), "Invalid proof");
        
        SavingsVault storage vault = _savingsVaults[msg.sender][_findVaultIndex(vaultId)];
        require(vault.isActive, "Vault not active");
        require(block.timestamp < vault.unlockTimestamp, "Vault already unlocked");
        require(
            vault.isHeir[msg.sender] || vault.isTrustee[msg.sender],
            "Not authorized"
        );
        require(!vault.isEmergencyUnlockRequested, "Emergency unlock already requested");

        vault.isEmergencyUnlockRequested = true;
        vault.emergencyUnlockRequestTime = block.timestamp;
        vault.emergencyUnlockRequester = msg.sender;

        emit EmergencyUnlockRequested(
            vaultId,
            msg.sender,
            block.timestamp + EMERGENCY_UNLOCK_DELAY
        );
    }

    function cancelEmergencyUnlock(
        bytes32 vaultId,
        bytes32[] calldata publicInputs,
        bytes calldata proof
    ) external nonReentrant {
        require(halo2Verifier.verifyProof(vaultId, publicInputs, proof), "Invalid proof");
        
        SavingsVault storage vault = _savingsVaults[msg.sender][_findVaultIndex(vaultId)];
        require(vault.isActive, "Vault not active");
        require(vault.isEmergencyUnlockRequested, "No emergency unlock requested");
        require(
            vault.isHeir[msg.sender] || vault.isTrustee[msg.sender],
            "Not authorized"
        );

        vault.isEmergencyUnlockRequested = false;
        vault.emergencyUnlockRequestTime = 0;
        vault.emergencyUnlockRequester = address(0);

        emit EmergencyUnlockCancelled(vaultId, msg.sender);
    }

    function verifyVault(
        bytes32 vaultId,
        bytes32[] calldata publicInputs,
        bytes calldata proof
    ) external nonReentrant {
        require(halo2Verifier.verifyProof(vaultId, publicInputs, proof), "Invalid proof");
        
        SavingsVault storage vault = _savingsVaults[msg.sender][_findVaultIndex(vaultId)];
        require(vault.isActive, "Vault not active");
        require(
            block.timestamp >= vault.lastVerification + vault.verificationInterval,
            "Too early to verify"
        );
        require(
            vault.isHeir[msg.sender] || vault.isTrustee[msg.sender],
            "Not authorized"
        );

        vault.lastVerification = block.timestamp;
        vault.verificationHistory.push(block.timestamp);

        emit VaultVerified(vaultId, msg.sender, block.timestamp);
    }

    function unlockVault(
        bytes32 vaultId,
        bytes32[] calldata publicInputs,
        bytes calldata proof
    ) external nonReentrant {
        require(halo2Verifier.verifyProof(vaultId, publicInputs, proof), "Invalid proof");
        
        SavingsVault storage vault = _savingsVaults[msg.sender][_findVaultIndex(vaultId)];
        require(vault.isActive, "Vault not active");
        require(vault.isHeir[msg.sender], "Not an heir");
        
        bool canUnlock = block.timestamp >= vault.unlockTimestamp || 
            (vault.isEmergencyUnlockRequested && 
             block.timestamp >= vault.emergencyUnlockRequestTime + EMERGENCY_UNLOCK_DELAY);
        
        require(canUnlock, "Cannot unlock yet");

        uint256 amount = vault.amount;
        vault.isActive = false;

        require(
            lgcToken.transfer(msg.sender, amount),
            "Transfer failed"
        );

        _userTotalVaulted[msg.sender] -= amount;

        emit VaultUnlocked(vaultId, msg.sender, amount);
    }

    function earlyWithdrawal(
        bytes32 vaultId,
        bytes32[] calldata publicInputs,
        bytes calldata proof
    ) external nonReentrant {
        require(halo2Verifier.verifyProof(vaultId, publicInputs, proof), "Invalid proof");
        
        SavingsVault storage vault = _savingsVaults[msg.sender][_findVaultIndex(vaultId)];
        require(vault.isActive, "Vault not active");
        require(block.timestamp < vault.unlockTimestamp, "Vault already unlocked");

        uint256 amount = vault.amount;
        uint256 fee = (amount * EARLY_WITHDRAWAL_FEE) / 100;
        uint256 returnAmount = amount - fee;

        vault.isActive = false;

        // Transfer fee to DEX
        require(
            lgcToken.transfer(dexAddress, fee),
            "Fee transfer failed"
        );

        // Return remaining amount to owner
        require(
            lgcToken.transfer(msg.sender, returnAmount),
            "Return transfer failed"
        );

        emit EarlyWithdrawal(vaultId, msg.sender, returnAmount, fee);
    }

    // View functions
    function getVaultStatus(bytes32 vaultId) external view returns (VaultStatus memory) {
        SavingsVault storage vault = _savingsVaults[msg.sender][_findVaultIndex(vaultId)];
        
        return VaultStatus({
            isActive: vault.isActive,
            lastVerification: vault.lastVerification,
            nextVerificationDue: vault.lastVerification + vault.verificationInterval,
            timeUntilUnlock: vault.unlockTimestamp > block.timestamp ? 
                vault.unlockTimestamp - block.timestamp : 0,
            isEmergencyUnlockRequested: vault.isEmergencyUnlockRequested,
            emergencyUnlockTimeRemaining: vault.isEmergencyUnlockRequested ? 
                (vault.emergencyUnlockRequestTime + EMERGENCY_UNLOCK_DELAY) - block.timestamp : 0
        });
    }

    function getSavingsVaults(address owner) external view returns (SavingsVault[] memory) {
        return _savingsVaults[owner];
    }

    function getLegacyMessages(bytes32 vaultId) external view returns (LegacyMessage[] memory) {
        return _legacyMessages[vaultId];
    }

    function getVaultCreationCount(address owner) external view returns (uint256) {
        return _vaultCreationCount[owner];
    }

    function getTotalVaultedValue(address owner) external view returns (uint256) {
        return _userTotalVaulted[owner];
    }

    function getVerificationHistory(bytes32 vaultId) external view returns (uint256[] memory) {
        SavingsVault storage vault = _savingsVaults[msg.sender][_findVaultIndex(vaultId)];
        return vault.verificationHistory;
    }

    // Internal functions
    function _findVaultIndex(bytes32 vaultId) internal view returns (uint256) {
        SavingsVault[] storage vaults = _savingsVaults[msg.sender];
        for (uint i = 0; i < vaults.length; i++) {
            if (keccak256(abi.encode(vaults[i])) == vaultId) {
                return i;
            }
        }
        revert("Vault not found");
    }
} 