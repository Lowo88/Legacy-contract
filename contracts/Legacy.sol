// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/ILegacy.sol";
import "./libraries/LegacyTypes.sol";
import "./verifiers/Halo2Verifier.sol";
import "./modules/LegacyCore.sol";
import "./modules/LegacyVault.sol";
import "./modules/LegacyPrivacy.sol";
import "./modules/LegacyEmergency.sol";
import "./modules/LegacyAdmin.sol";

contract Legacy is ILegacy, LegacyCore, LegacyVault, LegacyPrivacy, LegacyEmergency, LegacyAdmin {
    constructor(address _halo2Verifier) 
        LegacyCore()
        LegacyVault(_halo2Verifier)
        LegacyPrivacy(_halo2Verifier)
        LegacyEmergency(_halo2Verifier)
        LegacyAdmin(_halo2Verifier)
    {}
} 