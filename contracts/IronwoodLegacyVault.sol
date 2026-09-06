// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title IronwoodLegacyVault
/// @notice Time-lock policy for an Ironwood note that may be staked to a Crosslink finalizer.
/// @dev Does not hold or transfer ZEC. Check-in is staking-health only. A missed check-in
///      *recalls* stake from the finalizer back into the vault until `unlockAt`.
///      Early release attests a 10% penalty to the Ironwood donation UA; scheduled release has no penalty.
contract IronwoodLegacyVault is ReentrancyGuard {
    uint256 public constant MIN_LOCK = 30 days;
    uint256 public constant MAX_LOCK = 365 days * 30;
    uint256 public constant MAX_HEIRS = 10;
    uint256 public constant MAX_TRUSTEES = 5;
    uint256 public constant MAX_VAULTS_PER_OWNER = 5;
    uint256 public constant UA_MIN_LEN = 78;
    uint256 public constant UA_MAX_LEN = 256;
    /// @notice Crosslink finalizer health ping. Missed ping → unstake, stay locked.
    uint256 public constant STAKING_CHECK_IN_INTERVAL = 30 days;
    uint256 public constant EARLY_PENALTY_BPS = 1_000;
    uint256 public constant BPS_DENOMINATOR = 10_000;

    /// @notice Ironwood unified address (`u1…` / `utest1…`) that receives the 10% early-exit share.
    string public donationUa;
    bytes32 public immutable donationUaHash;

    struct Vault {
        address owner;
        address manager;
        bytes32 noteCommitment;
        bytes32 finalizer;
        uint64 createdAt;
        uint64 unlockAt;
        uint64 lastCheckIn;
        bool stakedToFinalizer;
        bool active;
        bool released;
        bool earlyRelease;
        string legacyMessage;
    }

    struct VaultView {
        address owner;
        address manager;
        bytes32 noteCommitment;
        bytes32 finalizer;
        uint64 createdAt;
        uint64 unlockAt;
        uint64 lastCheckIn;
        bool stakedToFinalizer;
        bool active;
        bool released;
        bool earlyRelease;
        uint16 penaltyBps;
        string legacyMessage;
        bytes32[] heirUaHashes;
        address[] trustees;
    }

    mapping(bytes32 => Vault) private _vaults;
    mapping(bytes32 => bytes32[]) private _heirUaHashes;
    mapping(bytes32 => mapping(bytes32 => bool)) private _isHeirUaHash;
    mapping(bytes32 => address[]) private _trustees;
    mapping(bytes32 => mapping(address => bool)) private _isTrustee;
    mapping(bytes32 => bool) private _noteTaken;
    mapping(address => uint256) private _vaultCount;
    mapping(address => bytes32[]) private _vaultsByOwner;

    event VaultCreated(
        bytes32 indexed vaultId,
        address indexed owner,
        bytes32 indexed noteCommitment,
        bytes32 finalizer,
        uint64 unlockAt
    );
    event StakingCheckIn(
        bytes32 indexed vaultId,
        address indexed actor,
        bytes32 finalizer,
        uint64 at
    );
    event RecalledFromFinalizer(
        bytes32 indexed vaultId,
        bytes32 finalizer,
        address indexed actor
    );
    event RestakedToFinalizer(bytes32 indexed vaultId, bytes32 finalizer, address indexed actor);
    event VaultReleased(
        bytes32 indexed vaultId,
        address indexed actor,
        bytes32 noteCommitment,
        bool earlyRelease,
        uint16 penaltyBps
    );
    event HeirAdded(bytes32 indexed vaultId, bytes32 heirUaHash);
    event TrusteeAdded(bytes32 indexed vaultId, address indexed trustee);
    event ManagerUpdated(bytes32 indexed vaultId, address indexed manager);

    error InvalidNote();
    error InvalidDuration();
    error InvalidHeirs();
    error InvalidTrustees();
    error InvalidFinalizer();
    error InvalidIronwoodAddress();
    error NoteAlreadyVaulted();
    error TooManyVaults();
    error UnknownVault();
    error NotAuthorized();
    error Inactive();
    error AlreadyReleased();
    error TooEarly();
    error NotStaked();
    error AlreadyStaked();
    error CheckInStillValid();
    error DuplicateHeir();
    error DuplicateTrustee();
    error ZeroAddress();

    constructor(string memory donationUa_) {
        bytes32 hashed = _hashIronwoodUa(donationUa_);
        donationUa = donationUa_;
        donationUaHash = hashed;
    }

    function hashUnifiedAddress(string calldata ua) public pure returns (bytes32) {
        return _hashIronwoodUa(ua);
    }

    function createVault(
        bytes32 noteCommitment,
        uint256 duration,
        bytes32 finalizer,
        address manager,
        bytes32[] calldata heirUaHashes,
        address[] calldata trustees,
        string calldata legacyMessage
    ) external nonReentrant returns (bytes32 vaultId) {
        if (noteCommitment == bytes32(0)) revert InvalidNote();
        if (duration < MIN_LOCK || duration > MAX_LOCK) revert InvalidDuration();
        if (finalizer == bytes32(0)) revert InvalidFinalizer();
        if (heirUaHashes.length == 0 || heirUaHashes.length > MAX_HEIRS) revert InvalidHeirs();
        if (trustees.length == 0 || trustees.length > MAX_TRUSTEES) revert InvalidTrustees();
        if (_noteTaken[noteCommitment]) revert NoteAlreadyVaulted();
        if (_vaultCount[msg.sender] >= MAX_VAULTS_PER_OWNER) revert TooManyVaults();
        if (manager == address(0)) revert ZeroAddress();

        vaultId = keccak256(
            abi.encodePacked(msg.sender, noteCommitment, block.timestamp, _vaultCount[msg.sender])
        );

        Vault storage v = _vaults[vaultId];
        v.owner = msg.sender;
        v.manager = manager;
        v.noteCommitment = noteCommitment;
        v.finalizer = finalizer;
        v.createdAt = uint64(block.timestamp);
        v.unlockAt = uint64(block.timestamp + duration);
        v.lastCheckIn = uint64(block.timestamp);
        v.stakedToFinalizer = true;
        v.active = true;
        v.legacyMessage = legacyMessage;

        for (uint256 i = 0; i < heirUaHashes.length; i++) {
            bytes32 h = heirUaHashes[i];
            if (h == bytes32(0) || _isHeirUaHash[vaultId][h]) revert InvalidHeirs();
            _isHeirUaHash[vaultId][h] = true;
            _heirUaHashes[vaultId].push(h);
        }

        for (uint256 i = 0; i < trustees.length; i++) {
            address t = trustees[i];
            if (t == address(0) || t == msg.sender || _isTrustee[vaultId][t]) revert InvalidTrustees();
            _isTrustee[vaultId][t] = true;
            _trustees[vaultId].push(t);
        }

        _noteTaken[noteCommitment] = true;
        _vaultCount[msg.sender] += 1;
        _vaultsByOwner[msg.sender].push(vaultId);

        emit VaultCreated(vaultId, msg.sender, noteCommitment, finalizer, v.unlockAt);
    }

    /// @notice Owner or manager attests the Crosslink finalizer is meeting standard.
    ///         Only valid while the vault is staked to that finalizer.
    function checkIn(bytes32 vaultId) external nonReentrant {
        Vault storage v = _requireActive(vaultId);
        _requireOwnerOrManager(v);
        if (!v.stakedToFinalizer) revert NotStaked();
        v.lastCheckIn = uint64(block.timestamp);
        emit StakingCheckIn(vaultId, msg.sender, v.finalizer, v.lastCheckIn);
    }

    /// @notice Missed staking check-in: unstake from the finalizer and sit idle in the
    ///         time vault until `unlockAt`. Does not pay heirs and has no 10% penalty.
    function recallFromFinalizer(bytes32 vaultId) external nonReentrant {
        Vault storage v = _requireActive(vaultId);
        if (!_isOwnerManagerOrTrustee(vaultId, v, msg.sender)) revert NotAuthorized();
        if (!v.stakedToFinalizer) revert NotStaked();
        if (block.timestamp <= uint256(v.lastCheckIn) + STAKING_CHECK_IN_INTERVAL) {
            revert CheckInStillValid();
        }
        bytes32 fin = v.finalizer;
        v.stakedToFinalizer = false;
        emit RecalledFromFinalizer(vaultId, fin, msg.sender);
    }

    /// @notice Owner/manager may stake again to a finalizer while still inside the lock.
    function restakeToFinalizer(bytes32 vaultId, bytes32 finalizer) external nonReentrant {
        Vault storage v = _requireActive(vaultId);
        _requireOwnerOrManager(v);
        if (v.stakedToFinalizer) revert AlreadyStaked();
        if (finalizer == bytes32(0)) revert InvalidFinalizer();
        v.finalizer = finalizer;
        v.stakedToFinalizer = true;
        v.lastCheckIn = uint64(block.timestamp);
        emit RestakedToFinalizer(vaultId, finalizer, msg.sender);
        emit StakingCheckIn(vaultId, msg.sender, finalizer, v.lastCheckIn);
    }

    function setManager(bytes32 vaultId, address manager) external nonReentrant {
        Vault storage v = _requireActiveOwner(vaultId);
        if (manager == address(0)) revert ZeroAddress();
        v.manager = manager;
        emit ManagerUpdated(vaultId, manager);
    }

    /// @notice Scheduled unlock after `unlockAt`. No donation penalty.
    ///         If still staked, also signals unstake from the finalizer.
    function markReleased(bytes32 vaultId) external nonReentrant {
        Vault storage v = _requireActive(vaultId);
        if (block.timestamp < v.unlockAt) revert TooEarly();
        if (!_isOwnerManagerOrTrustee(vaultId, v, msg.sender)) revert NotAuthorized();
        _release(vaultId, v, false);
    }

    /// @notice Leave the vault before `unlockAt`. Attests 10% to `donationWallet` /
    ///         `donationUaHash`. Remaining 90% follows heirs off-chain.
    function earlyRelease(bytes32 vaultId) external nonReentrant {
        Vault storage v = _requireActive(vaultId);
        _requireOwnerOrManager(v);
        if (block.timestamp >= v.unlockAt) revert TooEarly();
        _release(vaultId, v, true);
    }

    function addHeir(bytes32 vaultId, bytes32 heirUaHash) external nonReentrant {
        _requireActiveOwner(vaultId);
        if (heirUaHash == bytes32(0)) revert InvalidHeirs();
        if (_isHeirUaHash[vaultId][heirUaHash]) revert DuplicateHeir();
        if (_heirUaHashes[vaultId].length >= MAX_HEIRS) revert InvalidHeirs();
        _isHeirUaHash[vaultId][heirUaHash] = true;
        _heirUaHashes[vaultId].push(heirUaHash);
        emit HeirAdded(vaultId, heirUaHash);
    }

    function addTrustee(bytes32 vaultId, address trustee) external nonReentrant {
        Vault storage v = _requireActiveOwner(vaultId);
        if (trustee == address(0)) revert ZeroAddress();
        if (trustee == v.owner) revert InvalidTrustees();
        if (_isTrustee[vaultId][trustee]) revert DuplicateTrustee();
        if (_trustees[vaultId].length >= MAX_TRUSTEES) revert InvalidTrustees();
        _isTrustee[vaultId][trustee] = true;
        _trustees[vaultId].push(trustee);
        emit TrusteeAdded(vaultId, trustee);
    }

    function getVault(bytes32 vaultId) external view returns (VaultView memory) {
        Vault storage v = _vaults[vaultId];
        if (v.owner == address(0)) revert UnknownVault();
        uint16 penalty = v.earlyRelease ? uint16(EARLY_PENALTY_BPS) : 0;
        return
            VaultView({
                owner: v.owner,
                manager: v.manager,
                noteCommitment: v.noteCommitment,
                finalizer: v.finalizer,
                createdAt: v.createdAt,
                unlockAt: v.unlockAt,
                lastCheckIn: v.lastCheckIn,
                stakedToFinalizer: v.stakedToFinalizer,
                active: v.active,
                released: v.released,
                earlyRelease: v.earlyRelease,
                penaltyBps: penalty,
                legacyMessage: v.legacyMessage,
                heirUaHashes: _heirUaHashes[vaultId],
                trustees: _trustees[vaultId]
            });
    }

    function vaultsOf(address owner) external view returns (bytes32[] memory) {
        return _vaultsByOwner[owner];
    }

    function isHeir(bytes32 vaultId, bytes32 heirUaHash) external view returns (bool) {
        return _isHeirUaHash[vaultId][heirUaHash];
    }

    function isTrustee(bytes32 vaultId, address trustee) external view returns (bool) {
        return _isTrustee[vaultId][trustee];
    }

    function noteTaken(bytes32 noteCommitment) external view returns (bool) {
        return _noteTaken[noteCommitment];
    }

    function checkInDue(bytes32 vaultId) external view returns (bool) {
        Vault storage v = _vaults[vaultId];
        if (v.owner == address(0) || !v.active || !v.stakedToFinalizer) return false;
        return block.timestamp > uint256(v.lastCheckIn) + STAKING_CHECK_IN_INTERVAL;
    }

    function _release(bytes32 vaultId, Vault storage v, bool early) internal {
        if (v.stakedToFinalizer) {
            v.stakedToFinalizer = false;
            emit RecalledFromFinalizer(vaultId, v.finalizer, msg.sender);
        }
        v.active = false;
        v.released = true;
        v.earlyRelease = early;
        uint16 penalty = early ? uint16(EARLY_PENALTY_BPS) : 0;
        emit VaultReleased(vaultId, msg.sender, v.noteCommitment, early, penalty);
    }

    function _requireActive(bytes32 vaultId) internal view returns (Vault storage v) {
        v = _vaults[vaultId];
        if (v.owner == address(0)) revert UnknownVault();
        if (!v.active) revert Inactive();
        if (v.released) revert AlreadyReleased();
    }

    function _requireActiveOwner(bytes32 vaultId) internal view returns (Vault storage v) {
        v = _requireActive(vaultId);
        if (msg.sender != v.owner) revert NotAuthorized();
    }

    function _requireOwnerOrManager(Vault storage v) internal view {
        if (msg.sender != v.owner && msg.sender != v.manager) revert NotAuthorized();
    }

    function _isOwnerManagerOrTrustee(
        bytes32 vaultId,
        Vault storage v,
        address actor
    ) internal view returns (bool) {
        return actor == v.owner || actor == v.manager || _isTrustee[vaultId][actor];
    }

    function _hashIronwoodUa(string memory ua) internal pure returns (bytes32) {
        bytes memory b = bytes(ua);
        uint256 n = b.length;
        if (n < UA_MIN_LEN || n > UA_MAX_LEN) revert InvalidIronwoodAddress();
        if (b[0] == "0" && b[1] == "x") revert InvalidIronwoodAddress();
        bool testnet = n >= 6 &&
            b[0] == "u" &&
            b[1] == "t" &&
            b[2] == "e" &&
            b[3] == "s" &&
            b[4] == "t" &&
            b[5] == "1";
        bool mainnet = b[0] == "u" && b[1] == "1";
        if (!testnet && !mainnet) revert InvalidIronwoodAddress();
        return keccak256(b);
    }
}
