// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../libraries/LegacyTypes.sol";
import "../verifiers/Halo2Verifier.sol";

contract LegacyEmergency is ReentrancyGuard {
    // Constants
    uint256 private constant MAX_EMERGENCY_CONTACTS = 5;
    uint256 private constant OPERATION_COOLDOWN = 1 hours;

    // Storage
    mapping(address => LegacyTypes.EmergencyContact[]) private _emergencyContacts;
    mapping(address => uint256) private _lastOperationTime;

    // Halo2 verifier
    Halo2Verifier public halo2Verifier;

    // Events
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

    constructor(address _halo2Verifier) {
        halo2Verifier = Halo2Verifier(_halo2Verifier);
    }

    function addEmergencyContact(
        address contact,
        uint256 delayPeriod,
        uint256 accessLevel,
        bytes32[] calldata publicInputs,
        bytes calldata proof
    ) external nonReentrant {
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

    function getEmergencyContacts(address owner) external view returns (LegacyTypes.EmergencyContact[] memory) {
        return _emergencyContacts[owner];
    }

    function isEmergencyContact(address owner, address contact) external view returns (bool) {
        LegacyTypes.EmergencyContact[] storage contacts = _emergencyContacts[owner];
        for (uint256 i = 0; i < contacts.length; i++) {
            if (contacts[i].contact == contact && contacts[i].isActive) {
                return true;
            }
        }
        return false;
    }
} 