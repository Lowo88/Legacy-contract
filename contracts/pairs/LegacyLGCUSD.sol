// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "../LegacyStablecoin.sol";
import "../utils/LegacyTypes.sol";
import "../utils/LegacyUtils.sol";
import "../utils/LegacyHalo2Verifier.sol";
import "../modules/LegacyVault.sol";

contract LegacyLGCUSD is ReentrancyGuard, Ownable {
    // Constants
    uint256 public constant MIN_LIQUIDITY = 1000 * 1e18; // 1000 LGC
    uint256 public constant MIN_TRADE_AMOUNT = 10 * 1e18; // 10 LGC
    uint256 public constant MAX_SLIPPAGE = 5; // 5%
    uint256 public constant FEE_PERCENTAGE = 30; // 0.3%
    uint256 public constant PRECISION = 1e18;
    uint256 public constant OPERATION_COOLDOWN = 1 hours;

    // State variables
    IERC20 public immutable lusd;
    IERC20 public immutable lgcToken;
    AggregatorV3Interface public immutable lgcPriceFeed;
    LegacyHalo2Verifier public immutable verifier;
    LegacyVault public immutable vault;
    
    uint256 public totalLiquidity;
    uint256 public totalLUSD;
    uint256 public totalLGC;
    
    mapping(address => uint256) public userLiquidity;
    mapping(address => uint256) public userLUSD;
    mapping(address => uint256) public userLGC;
    mapping(address => bool) public isLiquidityProvider;
    mapping(address => uint256) public lastOperationTime;
    mapping(bytes32 => bool) public usedProofs;
    mapping(address => bool) public hasVault;

    // Events
    event LiquidityAdded(
        address indexed provider,
        uint256 lgcAmount,
        uint256 lusdAmount
    );
    event LiquidityRemoved(
        address indexed provider,
        uint256 lgcAmount,
        uint256 lusdAmount
    );
    event TradeExecuted(
        bytes32 indexed tradeId,
        bool isBuy,
        uint256 lgcAmount,
        uint256 lusdAmount,
        uint256 fee
    );
    event PriceUpdated(
        uint256 lgcPrice,
        uint256 timestamp
    );
    event VaultVerified(
        address indexed trader,
        uint256 vaultId
    );

    constructor(
        address _lusd,
        address _lgcToken,
        address _lgcPriceFeed,
        address _verifier,
        address _vault
    ) Ownable(msg.sender) {
        lusd = IERC20(_lusd);
        lgcToken = IERC20(_lgcToken);
        lgcPriceFeed = AggregatorV3Interface(_lgcPriceFeed);
        verifier = LegacyHalo2Verifier(_verifier);
        vault = LegacyVault(_vault);
    }

    function verifyVault(
        uint256 vaultId,
        bytes calldata proof,
        LegacyTypes.ProofInput calldata input
    ) external nonReentrant {
        require(!hasVault[msg.sender], "Vault already verified");
        require(vault.isVaultOwner(msg.sender, vaultId), "Not vault owner");
        
        // Verify proof
        require(verifier.verifyProof(proof, input), "Invalid proof");
        require(!usedProofs[input.proofId], "Proof already used");
        usedProofs[input.proofId] = true;
        
        hasVault[msg.sender] = true;
        emit VaultVerified(msg.sender, vaultId);
    }

    function addLiquidity(
        uint256 lgcAmount,
        bytes calldata proof,
        LegacyTypes.ProofInput calldata input
    ) external nonReentrant {
        require(hasVault[msg.sender], "Vault required");
        require(lgcAmount >= MIN_LIQUIDITY, "Insufficient LGC");
        require(block.timestamp >= lastOperationTime[msg.sender] + OPERATION_COOLDOWN, "Cooldown active");
        
        // Verify proof
        require(verifier.verifyProof(proof, input), "Invalid proof");
        require(!usedProofs[input.proofId], "Proof already used");
        usedProofs[input.proofId] = true;
        
        // Get current LGC price
        uint256 lgcPrice = getLGCPrice();
        uint256 requiredLUSD = (lgcAmount * lgcPrice) / PRECISION;
        
        // Transfer tokens from user
        require(
            lgcToken.transferFrom(msg.sender, address(this), lgcAmount),
            "LGC transfer failed"
        );
        require(
            lusd.transferFrom(msg.sender, address(this), requiredLUSD),
            "LUSD transfer failed"
        );

        // Update state
        totalLiquidity += lgcAmount;
        totalLUSD += requiredLUSD;
        totalLGC += lgcAmount;
        
        userLiquidity[msg.sender] += lgcAmount;
        userLUSD[msg.sender] += requiredLUSD;
        userLGC[msg.sender] += lgcAmount;
        isLiquidityProvider[msg.sender] = true;
        lastOperationTime[msg.sender] = block.timestamp;

        emit LiquidityAdded(msg.sender, lgcAmount, requiredLUSD);
    }

    function removeLiquidity(
        uint256 liquidityAmount,
        bytes calldata proof,
        LegacyTypes.ProofInput calldata input
    ) external nonReentrant {
        require(hasVault[msg.sender], "Vault required");
        require(liquidityAmount > 0, "Invalid amount");
        require(userLiquidity[msg.sender] >= liquidityAmount, "Insufficient liquidity");
        require(block.timestamp >= lastOperationTime[msg.sender] + OPERATION_COOLDOWN, "Cooldown active");
        
        // Verify proof
        require(verifier.verifyProof(proof, input), "Invalid proof");
        require(!usedProofs[input.proofId], "Proof already used");
        usedProofs[input.proofId] = true;
        
        // Calculate proportional amounts
        uint256 lgcAmount = (liquidityAmount * totalLGC) / totalLiquidity;
        uint256 lusdAmount = (liquidityAmount * totalLUSD) / totalLiquidity;
        
        // Update state
        totalLiquidity -= liquidityAmount;
        totalLUSD -= lusdAmount;
        totalLGC -= lgcAmount;
        
        userLiquidity[msg.sender] -= liquidityAmount;
        userLUSD[msg.sender] -= lusdAmount;
        userLGC[msg.sender] -= lgcAmount;

        if (userLiquidity[msg.sender] == 0) {
            isLiquidityProvider[msg.sender] = false;
        }

        lastOperationTime[msg.sender] = block.timestamp;

        // Transfer tokens
        require(
            lgcToken.transfer(msg.sender, lgcAmount),
            "LGC transfer failed"
        );
        require(
            lusd.transfer(msg.sender, lusdAmount),
            "LUSD transfer failed"
        );

        emit LiquidityRemoved(msg.sender, lgcAmount, lusdAmount);
    }

    function buyLGC(
        uint256 lusdAmount,
        bytes calldata proof,
        LegacyTypes.ProofInput calldata input
    ) external nonReentrant {
        require(hasVault[msg.sender], "Vault required");
        require(lusdAmount >= MIN_TRADE_AMOUNT, "Amount too small");
        require(block.timestamp >= lastOperationTime[msg.sender] + OPERATION_COOLDOWN, "Cooldown active");
        
        // Verify proof
        require(verifier.verifyProof(proof, input), "Invalid proof");
        require(!usedProofs[input.proofId], "Proof already used");
        usedProofs[input.proofId] = true;
        
        // Calculate fee
        uint256 fee = (lusdAmount * FEE_PERCENTAGE) / 10000;
        uint256 tradeAmount = lusdAmount - fee;
        
        // Calculate LGC amount based on current price
        uint256 lgcPrice = getLGCPrice();
        uint256 lgcAmount = (tradeAmount * PRECISION) / lgcPrice;
        
        // Check slippage
        require(lgcAmount <= (totalLGC * MAX_SLIPPAGE) / 100, "Slippage too high");
        
        // Transfer LUSD from user
        require(
            lusd.transferFrom(msg.sender, address(this), lusdAmount),
            "LUSD transfer failed"
        );
        
        // Update state
        totalLUSD += lusdAmount;
        totalLGC -= lgcAmount;
        lastOperationTime[msg.sender] = block.timestamp;
        
        // Transfer LGC to user
        require(
            lgcToken.transfer(msg.sender, lgcAmount),
            "LGC transfer failed"
        );

        bytes32 tradeId = keccak256(abi.encodePacked(
            msg.sender,
            block.timestamp,
            lgcAmount,
            lusdAmount,
            input.proofId
        ));

        emit TradeExecuted(tradeId, true, lgcAmount, lusdAmount, fee);
    }

    function sellLGC(
        uint256 lgcAmount,
        bytes calldata proof,
        LegacyTypes.ProofInput calldata input
    ) external nonReentrant {
        require(hasVault[msg.sender], "Vault required");
        require(lgcAmount >= MIN_TRADE_AMOUNT, "Amount too small");
        require(block.timestamp >= lastOperationTime[msg.sender] + OPERATION_COOLDOWN, "Cooldown active");
        
        // Verify proof
        require(verifier.verifyProof(proof, input), "Invalid proof");
        require(!usedProofs[input.proofId], "Proof already used");
        usedProofs[input.proofId] = true;
        
        // Calculate LUSD amount based on current price
        uint256 lgcPrice = getLGCPrice();
        uint256 lusdAmount = (lgcAmount * lgcPrice) / PRECISION;
        
        // Calculate fee
        uint256 fee = (lusdAmount * FEE_PERCENTAGE) / 10000;
        uint256 tradeAmount = lusdAmount - fee;
        
        // Check slippage
        require(tradeAmount <= (totalLUSD * MAX_SLIPPAGE) / 100, "Slippage too high");
        
        // Transfer LGC from user
        require(
            lgcToken.transferFrom(msg.sender, address(this), lgcAmount),
            "LGC transfer failed"
        );
        
        // Update state
        totalLGC += lgcAmount;
        totalLUSD -= tradeAmount;
        lastOperationTime[msg.sender] = block.timestamp;
        
        // Transfer LUSD to user
        require(
            lusd.transfer(msg.sender, tradeAmount),
            "LUSD transfer failed"
        );

        bytes32 tradeId = keccak256(abi.encodePacked(
            msg.sender,
            block.timestamp,
            lgcAmount,
            tradeAmount,
            input.proofId
        ));

        emit TradeExecuted(tradeId, false, lgcAmount, tradeAmount, fee);
    }

    function getLGCPrice() public view returns (uint256) {
        (
            uint80 roundId,
            int256 price,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = lgcPriceFeed.latestRoundData();
        
        require(price > 0, "Invalid price");
        require(updatedAt > 0, "Round not complete");
        require(answeredInRound >= roundId, "Stale price");
        
        return uint256(price);
    }

    function getReserves() external view returns (uint256 lgcReserve, uint256 lusdReserve) {
        return (totalLGC, totalLUSD);
    }

    function getLiquidity(address user) external view returns (
        uint256 userLiquidityAmount,
        uint256 userLUSDAmount,
        uint256 userLGCAmount,
        bool isProvider
    ) {
        return (
            userLiquidity[user],
            userLUSD[user],
            userLGC[user],
            isLiquidityProvider[user]
        );
    }

    function hasVerifiedVault(address user) external view returns (bool) {
        return hasVault[user];
    }

    // Admin functions
    function setFeePercentage(uint256 newFee) external onlyOwner {
        require(newFee <= 100, "Fee too high"); // Max 1%
        FEE_PERCENTAGE = newFee;
    }

    function setMinTradeAmount(uint256 newAmount) external onlyOwner {
        require(newAmount > 0, "Invalid amount");
        MIN_TRADE_AMOUNT = newAmount;
    }

    function setMaxSLIPPAGE(uint256 newSlippage) external onlyOwner {
        require(newSlippage <= 10, "Slippage too high"); // Max 10%
        MAX_SLIPPAGE = newSlippage;
    }

    // Emergency functions
    function emergencyWithdraw() external onlyOwner {
        uint256 lgcBalance = lgcToken.balanceOf(address(this));
        uint256 lusdBalance = lusd.balanceOf(address(this));
        
        if (lgcBalance > 0) {
            require(
                lgcToken.transfer(owner(), lgcBalance),
                "LGC transfer failed"
            );
        }
        
        if (lusdBalance > 0) {
            require(
                lusd.transfer(owner(), lusdBalance),
                "LUSD transfer failed"
            );
        }
    }
} 