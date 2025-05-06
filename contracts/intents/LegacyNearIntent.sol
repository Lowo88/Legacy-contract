// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";
import "../utils/LegacyTypes.sol";
import "../utils/LegacyUtils.sol";
import "../utils/LegacyHalo2Verifier.sol";
import "../modules/LegacyVault.sol";

contract LegacyNearIntent is ReentrancyGuard, Ownable, KeeperCompatibleInterface {
    // Constants
    uint256 public constant INTENT_EXPIRY = 1 hours;
    uint256 public constant MAX_INTENTS_PER_USER = 10;
    uint256 public constant MIN_INTENT_AMOUNT = 1 * 1e18; // 1 LGC
    uint256 public constant PRICE_PRECISION = 1e18;
    uint256 public constant MAX_PRICE_DEVIATION = 5; // 5% maximum price deviation
    uint256 public constant EXECUTION_INTERVAL = 5 minutes;

    // Intent types
    enum IntentType {
        MARKET,     // Market order - executes immediately at current price
        LIMIT,      // Limit order - executes only at specified price or better
        STOP_LOSS,  // Stop-loss - executes when price falls below trigger
        TRAILING_STOP // Trailing stop - follows price up/down
    }

    // State variables
    IERC20 public immutable lgcToken;
    IERC20 public immutable lusd;
    LegacyVault public immutable vault;
    LegacyHalo2Verifier public immutable verifier;
    AggregatorV3Interface public immutable priceFeed;
    
    uint256 public lastExecutionTime;
    uint256 public minExecutionDelay;
    uint256 public maxExecutionDelay;
    bool public automationEnabled;

    struct Intent {
        address user;
        uint256 amount;
        uint256 price;
        uint256 triggerPrice;    // For stop-loss and trailing stop
        uint256 trailingDistance; // For trailing stop
        bool isBuy;
        uint256 expiry;
        bool isFilled;
        bytes32 proofId;
        IntentType intentType;
        uint256 lastPrice;       // For trailing stop
        uint256 lastUpdateTime;  // For tracking price updates
    }

    mapping(uint256 => Intent) public intents;
    mapping(address => uint256[]) public userIntents;
    mapping(address => uint256) public intentCount;
    mapping(bytes32 => bool) public usedProofs;
    mapping(address => uint256) public lastOperationTime;

    // Events
    event IntentCreated(
        uint256 indexed intentId,
        address indexed user,
        uint256 amount,
        uint256 price,
        uint256 triggerPrice,
        bool isBuy,
        uint256 expiry,
        IntentType intentType
    );
    event IntentFilled(
        uint256 indexed intentId,
        address indexed filler,
        uint256 amount,
        uint256 price,
        IntentType intentType
    );
    event IntentCancelled(
        uint256 indexed intentId,
        address indexed user
    );
    event IntentUpdated(
        uint256 indexed intentId,
        uint256 newPrice,
        uint256 newTriggerPrice
    );
    event AutomationExecuted(
        uint256 timestamp,
        uint256 intentsProcessed,
        uint256 currentPrice
    );

    constructor(
        address _lgcToken,
        address _lusd,
        address _vault,
        address _verifier,
        address _priceFeed
    ) Ownable(msg.sender) {
        lgcToken = IERC20(_lgcToken);
        lusd = IERC20(_lusd);
        vault = LegacyVault(_vault);
        verifier = LegacyHalo2Verifier(_verifier);
        priceFeed = AggregatorV3Interface(_priceFeed);
        automationEnabled = true;
        minExecutionDelay = 1 minutes;
        maxExecutionDelay = 10 minutes;
    }

    function createIntent(
        uint256 amount,
        uint256 price,
        uint256 triggerPrice,
        uint256 trailingDistance,
        bool isBuy,
        IntentType intentType,
        bytes calldata proof,
        LegacyTypes.ProofInput calldata input
    ) external nonReentrant {
        require(vault.isVaultOwner(msg.sender, input.vaultId), "Not vault owner");
        require(amount >= MIN_INTENT_AMOUNT, "Amount too small");
        require(intentCount[msg.sender] < MAX_INTENTS_PER_USER, "Too many intents");
        require(block.timestamp < input.expiry, "Intent expired");
        require(block.timestamp >= lastOperationTime[msg.sender] + 1 hours, "Cooldown active");
        
        // Verify proof
        require(verifier.verifyProof(proof, input), "Invalid proof");
        require(!usedProofs[input.proofId], "Proof already used");
        usedProofs[input.proofId] = true;

        // Validate intent type specific parameters
        if (intentType == IntentType.STOP_LOSS) {
            require(triggerPrice > 0, "Invalid trigger price");
            if (isBuy) {
                require(triggerPrice <= price, "Invalid stop-loss price");
            } else {
                require(triggerPrice >= price, "Invalid stop-loss price");
            }
        } else if (intentType == IntentType.TRAILING_STOP) {
            require(trailingDistance > 0, "Invalid trailing distance");
            require(triggerPrice > 0, "Invalid trigger price");
        }

        uint256 intentId = uint256(keccak256(abi.encodePacked(
            msg.sender,
            block.timestamp,
            amount,
            price,
            input.proofId
        )));

        intents[intentId] = Intent({
            user: msg.sender,
            amount: amount,
            price: price,
            triggerPrice: triggerPrice,
            trailingDistance: trailingDistance,
            isBuy: isBuy,
            expiry: block.timestamp + INTENT_EXPIRY,
            isFilled: false,
            proofId: input.proofId,
            intentType: intentType,
            lastPrice: 0,
            lastUpdateTime: block.timestamp
        });

        userIntents[msg.sender].push(intentId);
        intentCount[msg.sender]++;
        lastOperationTime[msg.sender] = block.timestamp;

        emit IntentCreated(
            intentId,
            msg.sender,
            amount,
            price,
            triggerPrice,
            isBuy,
            block.timestamp + INTENT_EXPIRY,
            intentType
        );
    }

    function updateTrailingStop(
        uint256 intentId,
        uint256 currentPrice,
        bytes calldata proof,
        LegacyTypes.ProofInput calldata input
    ) external nonReentrant {
        Intent storage intent = intents[intentId];
        require(intent.intentType == IntentType.TRAILING_STOP, "Not a trailing stop");
        require(!intent.isFilled, "Intent already filled");
        require(block.timestamp <= intent.expiry, "Intent expired");
        
        // Verify proof
        require(verifier.verifyProof(proof, input), "Invalid proof");
        require(!usedProofs[input.proofId], "Proof already used");
        usedProofs[input.proofId] = true;

        if (intent.isBuy) {
            if (currentPrice < intent.lastPrice) {
                intent.triggerPrice = currentPrice + intent.trailingDistance;
            }
        } else {
            if (currentPrice > intent.lastPrice) {
                intent.triggerPrice = currentPrice - intent.trailingDistance;
            }
        }

        intent.lastPrice = currentPrice;
        intent.lastUpdateTime = block.timestamp;
        emit IntentUpdated(intentId, intent.price, intent.triggerPrice);
    }

    function fillIntent(
        uint256 intentId,
        uint256 currentPrice,
        bytes calldata proof,
        LegacyTypes.ProofInput calldata input
    ) external nonReentrant {
        Intent storage intent = intents[intentId];
        require(!intent.isFilled, "Intent already filled");
        require(block.timestamp <= intent.expiry, "Intent expired");
        require(vault.isVaultOwner(msg.sender, input.vaultId), "Not vault owner");
        
        // Verify proof
        require(verifier.verifyProof(proof, input), "Invalid proof");
        require(!usedProofs[input.proofId], "Proof already used");
        usedProofs[input.proofId] = true;

        // Check if intent conditions are met
        if (intent.intentType == IntentType.LIMIT) {
            if (intent.isBuy) {
                require(currentPrice <= intent.price, "Price too high");
            } else {
                require(currentPrice >= intent.price, "Price too low");
            }
        } else if (intent.intentType == IntentType.STOP_LOSS) {
            if (intent.isBuy) {
                require(currentPrice >= intent.triggerPrice, "Stop-loss not triggered");
            } else {
                require(currentPrice <= intent.triggerPrice, "Stop-loss not triggered");
            }
        } else if (intent.intentType == IntentType.TRAILING_STOP) {
            if (intent.isBuy) {
                require(currentPrice >= intent.triggerPrice, "Trailing stop not triggered");
            } else {
                require(currentPrice <= intent.triggerPrice, "Trailing stop not triggered");
            }
        }

        uint256 totalAmount = (intent.amount * intent.price) / PRICE_PRECISION;

        if (intent.isBuy) {
            require(
                lgcToken.transferFrom(msg.sender, intent.user, intent.amount),
                "LGC transfer failed"
            );
            require(
                lusd.transferFrom(intent.user, msg.sender, totalAmount),
                "LUSD transfer failed"
            );
        } else {
            require(
                lgcToken.transferFrom(intent.user, msg.sender, intent.amount),
                "LGC transfer failed"
            );
            require(
                lusd.transferFrom(msg.sender, intent.user, totalAmount),
                "LUSD transfer failed"
            );
        }

        intent.isFilled = true;
        emit IntentFilled(intentId, msg.sender, intent.amount, intent.price, intent.intentType);
    }

    function cancelIntent(
        uint256 intentId,
        bytes calldata proof,
        LegacyTypes.ProofInput calldata input
    ) external nonReentrant {
        Intent storage intent = intents[intentId];
        require(msg.sender == intent.user, "Not intent owner");
        require(!intent.isFilled, "Intent already filled");
        
        // Verify proof
        require(verifier.verifyProof(proof, input), "Invalid proof");
        require(!usedProofs[input.proofId], "Proof already used");
        usedProofs[input.proofId] = true;

        intent.isFilled = true;
        intentCount[msg.sender]--;

        emit IntentCancelled(intentId, msg.sender);
    }

    function getIntent(uint256 intentId) external view returns (
        address user,
        uint256 amount,
        uint256 price,
        bool isBuy,
        uint256 expiry,
        bool isFilled
    ) {
        Intent storage intent = intents[intentId];
        return (
            intent.user,
            intent.amount,
            intent.price,
            intent.isBuy,
            intent.expiry,
            intent.isFilled
        );
    }

    function getUserIntents(address user) external view returns (uint256[] memory) {
        return userIntents[user];
    }

    // Chainlink Keeper functions
    function checkUpkeep(bytes calldata) external view override returns (bool, bytes memory) {
        if (!automationEnabled) return (false, bytes("Automation disabled"));
        if (block.timestamp < lastExecutionTime + minExecutionDelay) return (false, bytes("Too early"));
        if (block.timestamp > lastExecutionTime + maxExecutionDelay) return (true, bytes("Time to execute"));
        
        // Check if there are any executable intents
        uint256 currentPrice = getCurrentPrice();
        if (currentPrice == 0) return (false, bytes("Invalid price"));
        
        return (true, bytes("Ready to execute"));
    }

    function performUpkeep(bytes calldata) external override {
        require(automationEnabled, "Automation disabled");
        require(block.timestamp >= lastExecutionTime + minExecutionDelay, "Too early");
        
        uint256 currentPrice = getCurrentPrice();
        require(currentPrice > 0, "Invalid price");
        
        uint256 intentsProcessed = 0;
        uint256[] memory activeIntents = getActiveIntents();
        
        for (uint256 i = 0; i < activeIntents.length; i++) {
            uint256 intentId = activeIntents[i];
            Intent storage intent = intents[intentId];
            
            if (shouldExecuteIntent(intent, currentPrice)) {
                executeIntent(intentId, currentPrice);
                intentsProcessed++;
            }
        }
        
        lastExecutionTime = block.timestamp;
        emit AutomationExecuted(block.timestamp, intentsProcessed, currentPrice);
    }

    function getCurrentPrice() public view returns (uint256) {
        (
            uint80 roundId,
            int256 price,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();
        
        require(price > 0, "Invalid price");
        require(updatedAt > 0, "Round not complete");
        require(answeredInRound >= roundId, "Stale price");
        
        return uint256(price);
    }

    function shouldExecuteIntent(Intent storage intent, uint256 currentPrice) internal view returns (bool) {
        if (intent.isFilled || block.timestamp > intent.expiry) return false;
        
        if (intent.intentType == IntentType.MARKET) return true;
        
        if (intent.intentType == IntentType.LIMIT) {
            if (intent.isBuy) {
                return currentPrice <= intent.price;
            } else {
                return currentPrice >= intent.price;
            }
        }
        
        if (intent.intentType == IntentType.STOP_LOSS) {
            if (intent.isBuy) {
                return currentPrice >= intent.triggerPrice;
            } else {
                return currentPrice <= intent.triggerPrice;
            }
        }
        
        if (intent.intentType == IntentType.TRAILING_STOP) {
            if (intent.isBuy) {
                return currentPrice >= intent.triggerPrice;
            } else {
                return currentPrice <= intent.triggerPrice;
            }
        }
        
        return false;
    }

    function executeIntent(uint256 intentId, uint256 currentPrice) internal {
        Intent storage intent = intents[intentId];
        require(!intent.isFilled, "Intent already filled");
        
        uint256 totalAmount = (intent.amount * intent.price) / PRICE_PRECISION;
        
        if (intent.isBuy) {
            require(
                lgcToken.transferFrom(address(this), intent.user, intent.amount),
                "LGC transfer failed"
            );
            require(
                lusd.transferFrom(intent.user, address(this), totalAmount),
                "LUSD transfer failed"
            );
        } else {
            require(
                lgcToken.transferFrom(intent.user, address(this), intent.amount),
                "LGC transfer failed"
            );
            require(
                lusd.transferFrom(address(this), intent.user, totalAmount),
                "LUSD transfer failed"
            );
        }
        
        intent.isFilled = true;
        emit IntentFilled(intentId, address(this), intent.amount, currentPrice, intent.intentType);
    }

    function getActiveIntents() public view returns (uint256[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < userIntents[msg.sender].length; i++) {
            uint256 intentId = userIntents[msg.sender][i];
            if (!intents[intentId].isFilled && block.timestamp <= intents[intentId].expiry) {
                count++;
            }
        }
        
        uint256[] memory activeIntents = new uint256[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < userIntents[msg.sender].length; i++) {
            uint256 intentId = userIntents[msg.sender][i];
            if (!intents[intentId].isFilled && block.timestamp <= intents[intentId].expiry) {
                activeIntents[index] = intentId;
                index++;
            }
        }
        
        return activeIntents;
    }

    // Admin functions
    function setAutomationEnabled(bool enabled) external onlyOwner {
        automationEnabled = enabled;
    }

    function setExecutionDelays(uint256 minDelay, uint256 maxDelay) external onlyOwner {
        require(minDelay > 0 && maxDelay > minDelay, "Invalid delays");
        minExecutionDelay = minDelay;
        maxExecutionDelay = maxDelay;
    }

    function setIntentExpiry(uint256 newExpiry) external onlyOwner {
        require(newExpiry > 0, "Invalid expiry");
        INTENT_EXPIRY = newExpiry;
    }

    function setMaxIntentsPerUser(uint256 newMax) external onlyOwner {
        require(newMax > 0, "Invalid max");
        MAX_INTENTS_PER_USER = newMax;
    }

    function setMinIntentAmount(uint256 newAmount) external onlyOwner {
        require(newAmount > 0, "Invalid amount");
        MIN_INTENT_AMOUNT = newAmount;
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