// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../libraries/LegacyTypes.sol";
import "../verifiers/Halo2Verifier.sol";

contract LegacyAdmin is Ownable, ReentrancyGuard {
    // Storage
    mapping(address => bool) private _blacklistedAddresses;
    mapping(bytes32 => LegacyTypes.AdminRequest) private _adminRequests;
    mapping(bytes32 => LegacyTypes.SuccessorRequest) private _successorRequests;

    // Halo2 verifier
    Halo2Verifier public halo2Verifier;

    // Events
    event BlacklistUpdated(
        address indexed blacklistedAddress,
        bool isBlacklisted
    );
    event AdminRequestCreated(
        bytes32 indexed vaultId,
        address requester,
        address newAdmin
    );
    event AdminRequestApproved(
        bytes32 indexed vaultId,
        address newAdmin
    );
    event AdminRequestRejected(
        bytes32 indexed vaultId
    );
    event AdminChanged(
        bytes32 indexed vaultId,
        address oldAdmin,
        address newAdmin
    );
    event SuccessorChanged(
        bytes32 indexed vaultId,
        address newSuccessor
    );
    event SuccessorChangeRejected(bytes32 indexed vaultId);
    event SuccessorChangeApproved(bytes32 indexed vaultId);

    constructor(address _halo2Verifier) {
        halo2Verifier = Halo2Verifier(_halo2Verifier);
    }

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

    function requestAdminChange(
        bytes32 vaultId,
        address newAdmin,
        bytes32[] calldata publicInputs,
        bytes calldata proof
    ) external nonReentrant {
        require(newAdmin != address(0), "Invalid admin");
        require(halo2Verifier.verifyProof(vaultId, publicInputs, proof), "Invalid proof");
        require(!_blacklistedAddresses[msg.sender], "Address is blacklisted");

        _adminRequests[vaultId] = LegacyTypes.AdminRequest({
            requester: msg.sender,
            newAdmin: newAdmin,
            timestamp: block.timestamp,
            isApproved: false
        });

        emit AdminRequestCreated(vaultId, msg.sender, newAdmin);
    }

    function approveAdminChange(
        bytes32 vaultId,
        bytes32[] calldata publicInputs,
        bytes calldata proof
    ) external {
        require(halo2Verifier.verifyProof(vaultId, publicInputs, proof), "Invalid proof");
        require(!_blacklistedAddresses[msg.sender], "Address is blacklisted");

        LegacyTypes.AdminRequest storage request = _adminRequests[vaultId];
        require(request.requester != address(0), "No request found");
        require(!request.isApproved, "Request already approved");

        request.isApproved = true;
        emit AdminRequestApproved(vaultId, request.newAdmin);
    }

    function rejectAdminChange(
        bytes32 vaultId,
        bytes32[] calldata publicInputs,
        bytes calldata proof
    ) external {
        require(halo2Verifier.verifyProof(vaultId, publicInputs, proof), "Invalid proof");
        require(!_blacklistedAddresses[msg.sender], "Address is blacklisted");

        LegacyTypes.AdminRequest storage request = _adminRequests[vaultId];
        require(request.requester != address(0), "No request found");
        require(!request.isApproved, "Request already approved");

        delete _adminRequests[vaultId];
        emit AdminRequestRejected(vaultId);
    }

    function requestSuccessorChange(
        bytes32 vaultId,
        address newSuccessor,
        bytes32[] calldata publicInputs,
        bytes calldata proof
    ) external {
        require(halo2Verifier.verifyProof(vaultId, publicInputs, proof), "Invalid proof");
        require(!_blacklistedAddresses[msg.sender], "Address is blacklisted");
        require(newSuccessor != address(0), "Invalid successor");

        _successorRequests[vaultId] = LegacyTypes.SuccessorRequest({
            requester: msg.sender,
            newSuccessor: newSuccessor,
            timestamp: block.timestamp,
            isApproved: false
        });

        emit SuccessorChanged(vaultId, newSuccessor);
    }

    function approveSuccessorChange(
        bytes32 vaultId,
        bytes32[] calldata publicInputs,
        bytes calldata proof
    ) external {
        require(halo2Verifier.verifyProof(vaultId, publicInputs, proof), "Invalid proof");
        require(!_blacklistedAddresses[msg.sender], "Address is blacklisted");

        LegacyTypes.SuccessorRequest storage request = _successorRequests[vaultId];
        require(request.requester != address(0), "No request found");
        require(!request.isApproved, "Request already approved");

        request.isApproved = true;
        emit SuccessorChangeApproved(vaultId);
    }

    function rejectSuccessorChange(
        bytes32 vaultId,
        bytes32[] calldata publicInputs,
        bytes calldata proof
    ) external {
        require(halo2Verifier.verifyProof(vaultId, publicInputs, proof), "Invalid proof");
        require(!_blacklistedAddresses[msg.sender], "Address is blacklisted");

        LegacyTypes.SuccessorRequest storage request = _successorRequests[vaultId];
        require(request.requester != address(0), "No request found");
        require(!request.isApproved, "Request already approved");

        delete _successorRequests[vaultId];
        emit SuccessorChangeRejected(vaultId);
    }

    function isBlacklisted(address account) external view returns (bool) {
        return _blacklistedAddresses[account];
    }
} 