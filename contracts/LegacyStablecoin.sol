// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./modules/LegacyVault.sol";

contract LegacyStablecoin is ERC20, ReentrancyGuard, Ownable {
    // Constants
    uint256 public constant MINIMUM_COLLATERAL_RATIO = 150; // 150% collateralization
    uint256 public constant LIQUIDATION_RATIO = 130; // 130% collateralization
    uint256 public constant LIQUIDATION_PENALTY = 10; // 10% penalty
    uint256 public constant STABILITY_FEE = 2; // 2% annual stability fee

    // State variables
    LegacyVault public immutable vault;
    IERC20 public immutable lgcToken;
    uint256 public totalCollateral;
    uint256 public lastUpdateTime;
    uint256 public accumulatedStabilityFee;

    // Mappings
    mapping(address => uint256) public collateral;
    mapping(address => uint256) public debt;
    mapping(address => uint256) public lastStabilityFeeUpdate;

    // Events
    event CollateralDeposited(address indexed user, uint256 amount);
    event CollateralWithdrawn(address indexed user, uint256 amount);
    event StablecoinMinted(address indexed user, uint256 amount);
    event StablecoinBurned(address indexed user, uint256 amount);
    event LiquidationExecuted(
        address indexed liquidated,
        address indexed liquidator,
        uint256 collateralAmount,
        uint256 debtAmount
    );
    event StabilityFeeCollected(address indexed user, uint256 amount);

    constructor(
        address _vault,
        address _lgcToken,
        string memory name,
        string memory symbol
    ) ERC20(name, symbol) Ownable(msg.sender) {
        vault = LegacyVault(_vault);
        lgcToken = IERC20(_lgcToken);
        lastUpdateTime = block.timestamp;
    }

    function depositCollateral(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        
        // Transfer LGC tokens from user
        require(
            lgcToken.transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );

        // Update collateral
        collateral[msg.sender] += amount;
        totalCollateral += amount;

        emit CollateralDeposited(msg.sender, amount);
    }

    function withdrawCollateral(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        require(collateral[msg.sender] >= amount, "Insufficient collateral");
        
        // Check if withdrawal would make position unsafe
        uint256 newCollateral = collateral[msg.sender] - amount;
        require(
            _calculateCollateralRatio(newCollateral, debt[msg.sender]) >= MINIMUM_COLLATERAL_RATIO,
            "Would make position unsafe"
        );

        // Update collateral
        collateral[msg.sender] = newCollateral;
        totalCollateral -= amount;

        // Transfer LGC tokens back to user
        require(
            lgcToken.transfer(msg.sender, amount),
            "Transfer failed"
        );

        emit CollateralWithdrawn(msg.sender, amount);
    }

    function mintStablecoin(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        
        // Calculate required collateral
        uint256 requiredCollateral = (amount * MINIMUM_COLLATERAL_RATIO) / 100;
        require(
            collateral[msg.sender] >= requiredCollateral,
            "Insufficient collateral"
        );

        // Update debt
        debt[msg.sender] += amount;
        lastStabilityFeeUpdate[msg.sender] = block.timestamp;

        // Mint stablecoin
        _mint(msg.sender, amount);

        emit StablecoinMinted(msg.sender, amount);
    }

    function burnStablecoin(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");

        // Calculate stability fee
        uint256 fee = _calculateStabilityFee(msg.sender);
        if (fee > 0) {
            _mint(address(this), fee);
            accumulatedStabilityFee += fee;
        }

        // Update debt
        debt[msg.sender] -= amount;
        lastStabilityFeeUpdate[msg.sender] = block.timestamp;

        // Burn stablecoin
        _burn(msg.sender, amount);

        emit StablecoinBurned(msg.sender, amount);
    }

    function liquidate(address user) external nonReentrant {
        require(
            _calculateCollateralRatio(collateral[user], debt[user]) < LIQUIDATION_RATIO,
            "Position not liquidatable"
        );

        uint256 debtAmount = debt[user];
        uint256 collateralAmount = collateral[user];
        
        // Calculate liquidation penalty
        uint256 penalty = (collateralAmount * LIQUIDATION_PENALTY) / 100;
        uint256 liquidatorReward = collateralAmount - penalty;

        // Update state
        collateral[user] = 0;
        debt[user] = 0;
        totalCollateral -= collateralAmount;

        // Transfer collateral to liquidator
        require(
            lgcToken.transfer(msg.sender, liquidatorReward),
            "Transfer failed"
        );

        // Transfer penalty to protocol
        require(
            lgcToken.transfer(owner(), penalty),
            "Transfer failed"
        );

        // Burn liquidated debt
        _burn(user, debtAmount);

        emit LiquidationExecuted(user, msg.sender, collateralAmount, debtAmount);
    }

    function _calculateCollateralRatio(uint256 collateralAmount, uint256 debtAmount) internal pure returns (uint256) {
        if (debtAmount == 0) return type(uint256).max;
        return (collateralAmount * 100) / debtAmount;
    }

    function _calculateStabilityFee(address user) internal view returns (uint256) {
        if (debt[user] == 0) return 0;
        
        uint256 timeElapsed = block.timestamp - lastStabilityFeeUpdate[user];
        return (debt[user] * STABILITY_FEE * timeElapsed) / (365 days * 100);
    }

    function getCollateralRatio(address user) external view returns (uint256) {
        return _calculateCollateralRatio(collateral[user], debt[user]);
    }

    function getStabilityFee(address user) external view returns (uint256) {
        return _calculateStabilityFee(user);
    }

    // Admin functions
    function setStabilityFee(uint256 newFee) external onlyOwner {
        require(newFee <= 10, "Fee too high"); // Max 10%
        STABILITY_FEE = newFee;
    }

    function setLiquidationRatio(uint256 newRatio) external onlyOwner {
        require(newRatio >= 110 && newRatio <= 150, "Invalid ratio");
        LIQUIDATION_RATIO = newRatio;
    }

    function setMinimumCollateralRatio(uint256 newRatio) external onlyOwner {
        require(newRatio >= 120 && newRatio <= 200, "Invalid ratio");
        MINIMUM_COLLATERAL_RATIO = newRatio;
    }
} 