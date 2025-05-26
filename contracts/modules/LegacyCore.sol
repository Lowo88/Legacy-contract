// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../libraries/LegacyTypes.sol";

contract LegacyCore is ERC20, Ownable, ReentrancyGuard {
    // Constants
    uint256 public constant TOTAL_SUPPLY = 13_088_000 * 10**18; // 13,088,000 LGC with 18 decimals
    uint256 private constant PRICE_PEG = 1 ether;
    
    // Asset backing
    LegacyTypes.AssetBacking[] private _backingAssets;
    
    // Events
    event AssetAdded(
        uint8 assetType,
        uint256 amount,
        uint256 price
    );

    constructor() ERC20("Legacy", "LGC") {
        _mint(msg.sender, TOTAL_SUPPLY);
        _transferOwnership(msg.sender);
    }

    // External functions
    function transfer(address to, uint256 value) public virtual override nonReentrant returns (bool) {
        return super.transfer(to, value);
    }

    function addAsset(string calldata assetType, uint256 amount, uint256 price) external {
        _backingAssets.push(LegacyTypes.AssetBacking({
            assetType: assetType,
            amount: amount,
            price: price
        }));
        emit AssetAdded(1, amount, price);
    }

    // View functions
    function getBackingAssets() external view returns (LegacyTypes.AssetBacking[] memory) {
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