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

contract LegacyETHUSD is ReentrancyGuard, Ownable {
    // Constants
    uint256 public constant MIN_LIQUIDITY = 1 ether;
    uint256 public constant MIN_TRADE_AMOUNT = 0.01 ether;
    uint256 public constant MAX_SLIPPAGE = 5; // 5%
    uint256 public constant FEE_PERCENTAGE = 30; // 0.3%
    uint256 public constant PRECISION = 1e18;
    uint256 public constant MIN_LGC_FOR_LIQUIDITY = 1; // 1 LGC required for liquidity provision
    uint256 public constant OPERATION_COOLDOWN = 1 hours;

    // State variables
    IERC20 public immutable lusd;
    IERC20 public immutable lgcToken;
    AggregatorV3Interface public immutable ethPriceFeed;
    LegacyHalo2Verifier public immutable verifier;
    
    uint256 public totalLiquidity;
    uint256 public totalLUSD;
    uint256 public totalETH;
    
    mapping(address => uint256) public userLiquidity;
    mapping(address => uint256) public userLUSD;
    mapping(address => uint256) public userETH;
    mapping(address => bool) public isLiquidityProvider;
    mapping(address => uint256) public lastOperationTime;
    mapping(bytes32 => bool) public usedProofs;

    // Events
    event LiquidityAdded(
        address indexed provider,
        uint256 ethAmount,
        uint256 lusdAmount
    );
    event LiquidityRemoved(
        address indexed provider,
        uint256 ethAmount,
        uint256 lusdAmount
    );
    event TradeExecuted(
        bytes32 indexed tradeId,
        bool isBuy,
        uint256 ethAmount,
        uint256 lusdAmount,
        uint256 fee
    );
    event PriceUpdated(
        uint256 ethPrice,
        uint256 timestamp
    );

    constructor(
        address _lusd,
        address _lgcToken,
        address _ethPriceFeed,
        address _verifier
    ) Ownable(msg.sender) {
        lusd = IERC20(_lusd);
        lgcToken = IERC20(_lgcToken);
        ethPriceFeed = AggregatorV3Interface(_ethPriceFeed);
        verifier = LegacyHalo2Verifier(_verifier);
    }

    function addLiquidity(
        bytes calldata proof,
        LegacyTypes.ProofInput calldata input
    ) external payable nonReentrant {
        require(msg.value >= MIN_LIQUIDITY, "Insufficient ETH");
        require(block.timestamp >= lastOperationTime[msg.sender] + OPERATION_COOLDOWN, "Cooldown active");
        
        // Verify proof
        require(verifier.verifyProof(proof, input), "Invalid proof");
        require(!usedProofs[input.proofId], "Proof already used");
        usedProofs[input.proofId] = true;
        
        // Check LGC balance for liquidity providers
        uint256 lgcBalance = lgcToken.balanceOf(msg.sender);
        require(lgcBalance >= MIN_LGC_FOR_LIQUIDITY, "Insufficient LGC for liquidity provision");
        
        // Get current ETH price
        uint256 ethPrice = getETHPrice();
        uint256 requiredLUSD = (msg.value * ethPrice) / PRECISION;
        
        // Transfer LUSD from user
        require(
            lusd.transferFrom(msg.sender, address(this), requiredLUSD),
            "LUSD transfer failed"
        );

        // Update state
        totalLiquidity += msg.value;
        totalLUSD += requiredLUSD;
        totalETH += msg.value;
        
        userLiquidity[msg.sender] += msg.value;
        userLUSD[msg.sender] += requiredLUSD;
        userETH[msg.sender] += msg.value;
        isLiquidityProvider[msg.sender] = true;
        lastOperationTime[msg.sender] = block.timestamp;

        emit LiquidityAdded(msg.sender, msg.value, requiredLUSD);
    }

    function removeLiquidity(
        uint256 liquidityAmount,
        bytes calldata proof,
        LegacyTypes.ProofInput calldata input
    ) external nonReentrant {
        require(liquidityAmount > 0, "Invalid amount");
        require(userLiquidity[msg.sender] >= liquidityAmount, "Insufficient liquidity");
        require(block.timestamp >= lastOperationTime[msg.sender] + OPERATION_COOLDOWN, "Cooldown active");
        
        // Verify proof
        require(verifier.verifyProof(proof, input), "Invalid proof");
        require(!usedProofs[input.proofId], "Proof already used");
        usedProofs[input.proofId] = true;
        
        // Calculate proportional amounts
        uint256 ethAmount = (liquidityAmount * totalETH) / totalLiquidity;
        uint256 lusdAmount = (liquidityAmount * totalLUSD) / totalLiquidity;
        
        // Update state
        totalLiquidity -= liquidityAmount;
        totalLUSD -= lusdAmount;
        totalETH -= ethAmount;
        
        userLiquidity[msg.sender] -= liquidityAmount;
        userLUSD[msg.sender] -= lusdAmount;
        userETH[msg.sender] -= ethAmount;

        if (userLiquidity[msg.sender] == 0) {
            isLiquidityProvider[msg.sender] = false;
        }

        lastOperationTime[msg.sender] = block.timestamp;

        // Transfer tokens
        (bool success, ) = msg.sender.call{value: ethAmount}("");
        require(success, "ETH transfer failed");
        require(
            lusd.transfer(msg.sender, lusdAmount),
            "LUSD transfer failed"
        );

        emit LiquidityRemoved(msg.sender, ethAmount, lusdAmount);
    }

    function buyETH(
        uint256 lusdAmount,
        bytes calldata proof,
        LegacyTypes.ProofInput calldata input
    ) external nonReentrant {
        require(lusdAmount >= MIN_TRADE_AMOUNT, "Amount too small");
        require(block.timestamp >= lastOperationTime[msg.sender] + OPERATION_COOLDOWN, "Cooldown active");
        
        // Verify proof
        require(verifier.verifyProof(proof, input), "Invalid proof");
        require(!usedProofs[input.proofId], "Proof already used");
        usedProofs[input.proofId] = true;
        
        // Calculate fee
        uint256 fee = (lusdAmount * FEE_PERCENTAGE) / 10000;
        uint256 tradeAmount = lusdAmount - fee;
        
        // Calculate ETH amount based on current price
        uint256 ethPrice = getETHPrice();
        uint256 ethAmount = (tradeAmount * PRECISION) / ethPrice;
        
        // Check slippage
        require(ethAmount <= (totalETH * MAX_SLIPPAGE) / 100, "Slippage too high");
        
        // Transfer LUSD from user
        require(
            lusd.transferFrom(msg.sender, address(this), lusdAmount),
            "LUSD transfer failed"
        );
        
        // Update state
        totalLUSD += lusdAmount;
        totalETH -= ethAmount;
        lastOperationTime[msg.sender] = block.timestamp;
        
        // Transfer ETH to user
        (bool success, ) = msg.sender.call{value: ethAmount}("");
        require(success, "ETH transfer failed");

        bytes32 tradeId = keccak256(abi.encodePacked(
            msg.sender,
            block.timestamp,
            ethAmount,
            lusdAmount,
            input.proofId
        ));

        emit TradeExecuted(tradeId, true, ethAmount, lusdAmount, fee);
    }

    function sellETH(
        bytes calldata proof,
        LegacyTypes.ProofInput calldata input
    ) external payable nonReentrant {
        require(msg.value >= MIN_TRADE_AMOUNT, "Amount too small");
        require(block.timestamp >= lastOperationTime[msg.sender] + OPERATION_COOLDOWN, "Cooldown active");
        
        // Verify proof
        require(verifier.verifyProof(proof, input), "Invalid proof");
        require(!usedProofs[input.proofId], "Proof already used");
        usedProofs[input.proofId] = true;
        
        // Calculate LUSD amount based on current price
        uint256 ethPrice = getETHPrice();
        uint256 lusdAmount = (msg.value * ethPrice) / PRECISION;
        
        // Calculate fee
        uint256 fee = (lusdAmount * FEE_PERCENTAGE) / 10000;
        uint256 tradeAmount = lusdAmount - fee;
        
        // Check slippage
        require(tradeAmount <= (totalLUSD * MAX_SLIPPAGE) / 100, "Slippage too high");
        
        // Update state
        totalETH += msg.value;
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
            msg.value,
            tradeAmount,
            input.proofId
        ));

        emit TradeExecuted(tradeId, false, msg.value, tradeAmount, fee);
    }

    function getETHPrice() public view returns (uint256) {
        (
            uint80 roundId,
            int256 price,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = ethPriceFeed.latestRoundData();
        
        require(price > 0, "Invalid price");
        require(updatedAt > 0, "Round not complete");
        require(answeredInRound >= roundId, "Stale price");
        
        return uint256(price);
    }

    function getReserves() external view returns (uint256 ethReserve, uint256 lusdReserve) {
        return (totalETH, totalLUSD);
    }

    function getLiquidity(address user) external view returns (
        uint256 userLiquidityAmount,
        uint256 userLUSDAmount,
        uint256 userETHAmount,
        bool isProvider
    ) {
        return (
            userLiquidity[user],
            userLUSD[user],
            userETH[user],
            isLiquidityProvider[user]
        );
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

    function setMinLGCForLiquidity(uint256 newAmount) external onlyOwner {
        require(newAmount > 0, "Invalid amount");
        MIN_LGC_FOR_LIQUIDITY = newAmount;
    }

    // Emergency functions
    function emergencyWithdraw() external onlyOwner {
        uint256 ethBalance = address(this).balance;
        uint256 lusdBalance = lusd.balanceOf(address(this));
        
        if (ethBalance > 0) {
            (bool success, ) = owner().call{value: ethBalance}("");
            require(success, "ETH transfer failed");
        }
        
        if (lusdBalance > 0) {
            require(
                lusd.transfer(owner(), lusdBalance),
                "LUSD transfer failed"
            );
        }
    }
} 