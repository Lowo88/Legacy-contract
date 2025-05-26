// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "../interfaces/ILegacyNearIntent.sol";
import "../interfaces/ILegacySavingsVault.sol";

contract LegacyNearAIAgent is Ownable, ReentrancyGuard {
    // Constants
    uint256 public constant MIN_INVESTMENT = 100 ether; // Minimum investment for AI management
    uint256 public constant MAX_INVESTMENT = 1000000 ether; // Maximum investment per user
    uint256 public constant PERFORMANCE_FEE = 20; // 20% performance fee
    uint256 public constant MANAGEMENT_FEE = 2; // 2% annual management fee
    uint256 public constant COOLDOWN_PERIOD = 1 days;
    uint256 public constant MAX_SLIPPAGE = 50; // 0.5% max slippage

    // State variables
    IERC20 public lgcToken;
    ILegacyNearIntent public nearIntent;
    ILegacySavingsVault public savingsVault;
    AggregatorV3Interface public priceFeed;

    struct UserPortfolio {
        uint256 totalInvestment;
        uint256 lastRebalance;
        uint256 lastPerformanceFee;
        uint256[] activeIntents;
        bool isActive;
    }

    struct AISettings {
        uint256 riskTolerance; // 1-100
        uint256 rebalanceThreshold; // Percentage to trigger rebalance
        uint256 maxDrawdown; // Maximum allowed drawdown
        bool autoCompound;
        bool stopLossEnabled;
        // New AI settings
        uint256 mlModelVersion; // Version of ML model to use
        uint256 predictionConfidence; // Minimum confidence threshold
        uint256[] assetWeights; // Custom asset weights
        bool useReinforcementLearning; // Enable RL for dynamic adjustment
    }

    struct MLPrediction {
        uint256 timestamp;
        uint256 predictedPrice;
        uint256 confidence;
        uint256[] featureVector;
    }

    struct RiskMetrics {
        uint256 var95; // Value at Risk (95%)
        uint256 sharpeRatio;
        uint256 maxDrawdown;
        uint256 volatility;
        uint256 correlation;
    }

    struct RLState {
        uint256 marketCondition;
        uint256 portfolioValue;
        uint256 riskLevel;
        uint256[] assetPrices;
        uint256 timestamp;
    }

    struct RLAction {
        uint256[] allocationChanges;
        uint256 riskAdjustment;
        bool rebalance;
    }

    struct RLExperience {
        RLState state;
        RLAction action;
        uint256 reward;
        RLState nextState;
        uint256 timestamp;
    }

    struct RLPolicy {
        uint256 learningRate;
        uint256 discountFactor;
        uint256 explorationRate;
        uint256[] actionSpace;
        mapping(bytes32 => uint256) qValues;
    }

    mapping(address => UserPortfolio) public userPortfolios;
    mapping(address => AISettings) public userSettings;
    mapping(address => MLPrediction[]) public userPredictions;
    mapping(address => RiskMetrics) public userRiskMetrics;
    mapping(uint256 => uint256) public modelVersions; // ML model versions and their accuracy
    mapping(uint256 => bool) public processedIntents;
    mapping(address => RLPolicy) public userPolicies;
    mapping(address => RLExperience[]) public experienceBuffer;
    mapping(address => uint256) public lastPolicyUpdate;

    // Events
    event PortfolioCreated(address indexed user, uint256 amount);
    event PortfolioRebalanced(address indexed user, uint256 timestamp);
    event PerformanceFeeCollected(address indexed user, uint256 amount);
    event AISettingsUpdated(address indexed user, AISettings settings);
    event IntentExecuted(address indexed user, uint256 intentId, uint256 amount);
    event EmergencyStop(address indexed user, uint256 timestamp);
    event MLPredictionUpdated(address indexed user, uint256 timestamp, uint256 confidence);
    event RiskMetricsUpdated(address indexed user, RiskMetrics metrics);
    event ModelVersionUpdated(uint256 version, uint256 accuracy);
    event PortfolioOptimized(address indexed user, uint256[] newWeights);
    event PolicyUpdated(address indexed user, uint256 learningRate, uint256 explorationRate);
    event ExperienceAdded(address indexed user, uint256 reward);
    event ActionTaken(address indexed user, RLAction action);

    constructor(
        address _lgcToken,
        address _nearIntent,
        address _savingsVault,
        address _priceFeed
    ) {
        lgcToken = IERC20(_lgcToken);
        nearIntent = ILegacyNearIntent(_nearIntent);
        savingsVault = ILegacySavingsVault(_savingsVault);
        priceFeed = AggregatorV3Interface(_priceFeed);
    }

    // User functions
    function createPortfolio(uint256 amount, AISettings calldata settings) external nonReentrant {
        require(amount >= MIN_INVESTMENT, "Amount below minimum");
        require(amount <= MAX_INVESTMENT, "Amount above maximum");
        require(!userPortfolios[msg.sender].isActive, "Portfolio already exists");

        // Transfer tokens
        require(lgcToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        // Initialize portfolio
        userPortfolios[msg.sender] = UserPortfolio({
            totalInvestment: amount,
            lastRebalance: block.timestamp,
            lastPerformanceFee: block.timestamp,
            activeIntents: new uint256[](0),
            isActive: true
        });

        userSettings[msg.sender] = settings;

        emit PortfolioCreated(msg.sender, amount);
    }

    function updateAISettings(AISettings calldata settings) external {
        require(userPortfolios[msg.sender].isActive, "No active portfolio");
        userSettings[msg.sender] = settings;
        emit AISettingsUpdated(msg.sender, settings);
    }

    function emergencyStop() external nonReentrant {
        UserPortfolio storage portfolio = userPortfolios[msg.sender];
        require(portfolio.isActive, "No active portfolio");

        // Cancel all active intents
        for (uint256 i = 0; i < portfolio.activeIntents.length; i++) {
            nearIntent.cancelIntent(portfolio.activeIntents[i]);
        }

        // Transfer remaining balance
        uint256 balance = lgcToken.balanceOf(address(this));
        if (balance > 0) {
            require(lgcToken.transfer(msg.sender, balance), "Transfer failed");
        }

        portfolio.isActive = false;
        emit EmergencyStop(msg.sender, block.timestamp);
    }

    // AI Management functions
    function rebalancePortfolio(address user) external onlyOwner {
        UserPortfolio storage portfolio = userPortfolios[user];
        require(portfolio.isActive, "No active portfolio");
        require(block.timestamp >= portfolio.lastRebalance + COOLDOWN_PERIOD, "Cooldown active");

        AISettings storage settings = userSettings[user];
        
        // Get current market conditions
        (uint256 currentPrice, uint256 volatility) = getMarketConditions();
        
        // Calculate optimal allocation based on risk tolerance
        uint256[] memory allocations = calculateOptimalAllocation(
            settings.riskTolerance,
            currentPrice,
            volatility
        );

        // Execute rebalancing intents
        executeRebalancingIntents(user, allocations);

        portfolio.lastRebalance = block.timestamp;
        emit PortfolioRebalanced(user, block.timestamp);
    }

    function collectPerformanceFee(address user) external onlyOwner {
        UserPortfolio storage portfolio = userPortfolios[user];
        require(portfolio.isActive, "No active portfolio");
        require(block.timestamp >= portfolio.lastPerformanceFee + 30 days, "Fee collection too early");

        uint256 currentValue = calculatePortfolioValue(user);
        uint256 initialValue = portfolio.totalInvestment;
        
        if (currentValue > initialValue) {
            uint256 profit = currentValue - initialValue;
            uint256 fee = (profit * PERFORMANCE_FEE) / 100;
            
            // Transfer fee to owner
            require(lgcToken.transfer(owner(), fee), "Fee transfer failed");
            
            portfolio.lastPerformanceFee = block.timestamp;
            emit PerformanceFeeCollected(user, fee);
        }
    }

    // Internal functions
    function getMarketConditions() internal view returns (uint256 price, uint256 volatility) {
        (, int256 answer,,,) = priceFeed.latestRoundData();
        price = uint256(answer);
        
        // Calculate volatility (simplified)
        volatility = 0; // Implement volatility calculation
    }

    function calculateOptimalAllocation(
        uint256 riskTolerance,
        uint256 currentPrice,
        uint256 volatility
    ) internal view returns (uint256[] memory) {
        uint256[] memory allocations = new uint256[](3);
        
        // Get latest ML prediction
        MLPrediction memory latestPrediction = userPredictions[msg.sender][userPredictions[msg.sender].length - 1];
        
        // Calculate base allocation using Modern Portfolio Theory
        uint256 totalRisk = calculateTotalRisk(riskTolerance, volatility);
        
        // Apply ML-based adjustments
        if (latestPrediction.confidence > 70) {
            // Adjust allocations based on ML predictions
            allocations = adjustAllocationsWithML(
                allocations,
                latestPrediction,
                totalRisk
            );
        }
        
        // Apply reinforcement learning if enabled
        if (userSettings[msg.sender].useReinforcementLearning) {
            allocations = applyReinforcementLearning(
                allocations,
                latestPrediction,
                userRiskMetrics[msg.sender]
            );
        }
        
        // Ensure allocations sum to 100%
        normalizeAllocations(allocations);
        
        return allocations;
    }

    function calculateTotalRisk(
        uint256 riskTolerance,
        uint256 volatility
    ) internal pure returns (uint256) {
        // Implement risk calculation using VaR and other metrics
        return (riskTolerance * volatility) / 100;
    }

    function adjustAllocationsWithML(
        uint256[] memory baseAllocations,
        MLPrediction memory prediction,
        uint256 totalRisk
    ) internal pure returns (uint256[] memory) {
        // Adjust allocations based on ML predictions
        for (uint256 i = 0; i < baseAllocations.length; i++) {
            if (prediction.predictedPrice > prediction.featureVector[i]) {
                baseAllocations[i] = (baseAllocations[i] * 110) / 100; // Increase by 10%
            } else {
                baseAllocations[i] = (baseAllocations[i] * 90) / 100; // Decrease by 10%
            }
        }
        return baseAllocations;
    }

    function applyReinforcementLearning(
        uint256[] memory allocations,
        MLPrediction memory prediction,
        RiskMetrics memory metrics
    ) internal view returns (uint256[] memory) {
        RLPolicy storage policy = userPolicies[msg.sender];
        RLState memory currentState = getCurrentState(msg.sender);
        
        // Get action from policy
        RLAction memory action = getActionFromPolicy(currentState, policy);
        
        // Apply action to allocations
        allocations = applyActionToAllocations(allocations, action);
        
        // Update experience buffer
        updateExperienceBuffer(msg.sender, currentState, action);
        
        // Periodically update policy
        if (shouldUpdatePolicy(msg.sender)) {
            updatePolicy(msg.sender);
        }
        
        return allocations;
    }

    function normalizeAllocations(uint256[] memory allocations) internal pure {
        uint256 total = 0;
        for (uint256 i = 0; i < allocations.length; i++) {
            total += allocations[i];
        }
        
        for (uint256 i = 0; i < allocations.length; i++) {
            allocations[i] = (allocations[i] * 100) / total;
        }
    }

    function executeRebalancingIntents(
        address user,
        uint256[] memory allocations
    ) internal {
        UserPortfolio storage portfolio = userPortfolios[user];
        
        // Create and execute intents for each allocation
        for (uint256 i = 0; i < allocations.length; i++) {
            if (allocations[i] > 0) {
                uint256 intentId = nearIntent.createIntent(
                    user,
                    allocations[i],
                    block.timestamp + 1 hours,
                    MAX_SLIPPAGE
                );
                
                portfolio.activeIntents.push(intentId);
                emit IntentExecuted(user, intentId, allocations[i]);
            }
        }
    }

    function calculatePortfolioValue(address user) internal view returns (uint256) {
        UserPortfolio storage portfolio = userPortfolios[user];
        uint256 totalValue = portfolio.totalInvestment;
        
        // Add value from active intents
        for (uint256 i = 0; i < portfolio.activeIntents.length; i++) {
            totalValue += nearIntent.getIntentValue(portfolio.activeIntents[i]);
        }
        
        return totalValue;
    }

    // View functions
    function getPortfolioStatus(address user) external view returns (
        uint256 totalValue,
        uint256 lastRebalance,
        uint256[] memory activeIntents
    ) {
        UserPortfolio storage portfolio = userPortfolios[user];
        return (
            calculatePortfolioValue(user),
            portfolio.lastRebalance,
            portfolio.activeIntents
        );
    }

    function getAISettings(address user) external view returns (AISettings memory) {
        return userSettings[user];
    }

    function updateMLModel(uint256 version, uint256 accuracy) external onlyOwner {
        modelVersions[version] = accuracy;
        emit ModelVersionUpdated(version, accuracy);
    }

    function getMLPrediction(address user) external view returns (MLPrediction memory) {
        MLPrediction[] storage predictions = userPredictions[user];
        require(predictions.length > 0, "No predictions available");
        return predictions[predictions.length - 1];
    }

    function updateRiskMetrics(address user) external onlyOwner {
        RiskMetrics memory metrics;
        
        // Calculate Value at Risk (VaR)
        metrics.var95 = calculateVaR(user);
        
        // Calculate Sharpe Ratio
        metrics.sharpeRatio = calculateSharpeRatio(user);
        
        // Calculate Maximum Drawdown
        metrics.maxDrawdown = calculateMaxDrawdown(user);
        
        // Calculate Volatility
        metrics.volatility = calculateVolatility(user);
        
        // Calculate Correlation
        metrics.correlation = calculateCorrelation(user);
        
        userRiskMetrics[user] = metrics;
        emit RiskMetricsUpdated(user, metrics);
    }

    function calculateVaR(address user) internal view returns (uint256) {
        // Implement Value at Risk calculation
        // This would typically involve historical simulation or parametric methods
        return 0; // Placeholder
    }

    function calculateSharpeRatio(address user) internal view returns (uint256) {
        // Implement Sharpe Ratio calculation
        // (Return - Risk Free Rate) / Standard Deviation
        return 0; // Placeholder
    }

    function calculateMaxDrawdown(address user) internal view returns (uint256) {
        // Implement Maximum Drawdown calculation
        return 0; // Placeholder
    }

    function calculateVolatility(address user) internal view returns (uint256) {
        // Implement Volatility calculation
        return 0; // Placeholder
    }

    function calculateCorrelation(address user) internal view returns (uint256) {
        // Implement Correlation calculation
        return 0; // Placeholder
    }

    function getCurrentState(address user) internal view returns (RLState memory) {
        UserPortfolio storage portfolio = userPortfolios[user];
        RiskMetrics storage metrics = userRiskMetrics[user];
        
        return RLState({
            marketCondition: getMarketCondition(),
            portfolioValue: calculatePortfolioValue(user),
            riskLevel: metrics.var95,
            assetPrices: getAssetPrices(),
            timestamp: block.timestamp
        });
    }

    function getActionFromPolicy(
        RLState memory state,
        RLPolicy storage policy
    ) internal view returns (RLAction memory) {
        // Epsilon-greedy exploration
        if (shouldExplore(policy.explorationRate)) {
            return getRandomAction();
        }
        
        // Get best action from Q-values
        return getBestAction(state, policy);
    }

    function shouldExplore(uint256 explorationRate) internal view returns (bool) {
        return uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty))) % 100 < explorationRate;
    }

    function getRandomAction() internal pure returns (RLAction memory) {
        uint256[] memory changes = new uint256[](3);
        for (uint256 i = 0; i < changes.length; i++) {
            changes[i] = uint256(keccak256(abi.encodePacked(i, block.timestamp))) % 20 - 10; // -10% to +10%
        }
        
        return RLAction({
            allocationChanges: changes,
            riskAdjustment: uint256(keccak256(abi.encodePacked(block.timestamp))) % 20 - 10,
            rebalance: uint256(keccak256(abi.encodePacked(block.timestamp))) % 2 == 0
        });
    }

    function getBestAction(
        RLState memory state,
        RLPolicy storage policy
    ) internal view returns (RLAction memory) {
        bytes32 stateHash = keccak256(abi.encode(state));
        uint256 bestValue = 0;
        RLAction memory bestAction;
        
        // Evaluate all possible actions
        for (uint256 i = 0; i < policy.actionSpace.length; i++) {
            bytes32 actionHash = keccak256(abi.encode(stateHash, policy.actionSpace[i]));
            uint256 qValue = policy.qValues[actionHash];
            
            if (qValue > bestValue) {
                bestValue = qValue;
                bestAction = decodeAction(policy.actionSpace[i]);
            }
        }
        
        return bestAction;
    }

    function applyActionToAllocations(
        uint256[] memory allocations,
        RLAction memory action
    ) internal pure returns (uint256[] memory) {
        for (uint256 i = 0; i < allocations.length; i++) {
            if (i < action.allocationChanges.length) {
                allocations[i] = allocations[i] + action.allocationChanges[i];
            }
        }
        
        // Apply risk adjustment
        if (action.riskAdjustment != 0) {
            for (uint256 i = 0; i < allocations.length; i++) {
                allocations[i] = (allocations[i] * (100 + action.riskAdjustment)) / 100;
            }
        }
        
        return allocations;
    }

    function updateExperienceBuffer(
        address user,
        RLState memory state,
        RLAction memory action
    ) internal {
        RLExperience memory experience = RLExperience({
            state: state,
            action: action,
            reward: calculateReward(user, state, action),
            nextState: getCurrentState(user),
            timestamp: block.timestamp
        });
        
        experienceBuffer[user].push(experience);
        
        // Keep buffer size manageable
        if (experienceBuffer[user].length > 1000) {
            // Remove oldest experience
            for (uint256 i = 0; i < experienceBuffer[user].length - 1; i++) {
                experienceBuffer[user][i] = experienceBuffer[user][i + 1];
            }
            experienceBuffer[user].pop();
        }
        
        emit ExperienceAdded(user, experience.reward);
    }

    function calculateReward(
        address user,
        RLState memory state,
        RLAction memory action
    ) internal view returns (uint256) {
        uint256 reward = 0;
        
        // Portfolio value change
        uint256 valueChange = calculatePortfolioValue(user) - state.portfolioValue;
        reward += valueChange;
        
        // Risk adjustment reward
        if (action.riskAdjustment > 0) {
            reward += action.riskAdjustment;
        }
        
        // Rebalancing cost penalty
        if (action.rebalance) {
            reward -= 100; // Penalty for frequent rebalancing
        }
        
        return reward;
    }

    function shouldUpdatePolicy(address user) internal view returns (bool) {
        return block.timestamp >= lastPolicyUpdate[user] + 1 days;
    }

    function updatePolicy(address user) internal {
        RLPolicy storage policy = userPolicies[user];
        RLExperience[] storage experiences = experienceBuffer[user];
        
        // Experience replay
        for (uint256 i = 0; i < experiences.length; i++) {
            RLExperience memory exp = experiences[i];
            
            // Q-learning update
            bytes32 stateActionHash = keccak256(abi.encode(
                keccak256(abi.encode(exp.state)),
                encodeAction(exp.action)
            ));
            
            uint256 currentQ = policy.qValues[stateActionHash];
            uint256 nextStateMaxQ = getMaxQValue(exp.nextState, policy);
            
            // Q-learning formula: Q(s,a) = Q(s,a) + α[r + γ max Q(s',a') - Q(s,a)]
            uint256 newQ = currentQ + policy.learningRate * (
                exp.reward + policy.discountFactor * nextStateMaxQ - currentQ
            );
            
            policy.qValues[stateActionHash] = newQ;
        }
        
        lastPolicyUpdate[user] = block.timestamp;
    }

    function getMaxQValue(
        RLState memory state,
        RLPolicy storage policy
    ) internal view returns (uint256) {
        bytes32 stateHash = keccak256(abi.encode(state));
        uint256 maxQ = 0;
        
        for (uint256 i = 0; i < policy.actionSpace.length; i++) {
            bytes32 actionHash = keccak256(abi.encode(stateHash, policy.actionSpace[i]));
            uint256 qValue = policy.qValues[actionHash];
            
            if (qValue > maxQ) {
                maxQ = qValue;
            }
        }
        
        return maxQ;
    }

    function encodeAction(RLAction memory action) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(action)));
    }

    function decodeAction(uint256 encoded) internal pure returns (RLAction memory) {
        // Implement action decoding
        return RLAction({
            allocationChanges: new uint256[](3),
            riskAdjustment: 0,
            rebalance: false
        });
    }

    function getMarketCondition() internal view returns (uint256) {
        // Implement market condition calculation
        return 0;
    }

    function getAssetPrices() internal view returns (uint256[] memory) {
        // Implement asset price retrieval
        return new uint256[](3);
    }
} 