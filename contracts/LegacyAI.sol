// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./libraries/LegacyTypes.sol";
import "./Legacy.sol";

contract LegacyAI is Ownable {
    Legacy public legacyContract;
    
    struct EncryptedData {
        bytes encryptedContent;
        bytes encryptionKey;  // Encrypted with owner's public key
        uint256 timestamp;
        address[] authorizedViewers;
        mapping(address => bool) canView;
        mapping(address => bool) canShare;
    }

    struct PrivacySettings {
        bool encryptAllData;
        bool autoShareWithHeirs;
        bool allowKnowledgeTransfer;
        mapping(string => bool) encryptedCategories;
        mapping(address => bool) trustedParties;
    }

    struct KnowledgeBase {
        string category;
        EncryptedData content;
        uint256 lastUpdated;
        address[] contributors;
        mapping(address => uint256) contributionScores;
        string[] relatedTopics;
        bool isVerified;
        bool isEncrypted;
    }

    struct LearningSession {
        string topic;
        bytes encryptedQuestions;
        bytes encryptedAnswers;
        uint256 timestamp;
        address learner;
        uint256 comprehensionScore;
        bool isEncrypted;
        address[] authorizedViewers;
    }

    struct AIAgent {
        address owner;
        string name;
        string description;
        bool isActive;
        uint256 lastUpdate;
        uint256 updateInterval;
        string[] capabilities;
        mapping(string => string) preferences;
        mapping(address => bool) authorizedHeirs;
        mapping(string => uint256) assetThresholds;
        mapping(string => string) assetStrategies;
        mapping(string => KnowledgeBase) knowledgeBase;
        LearningSession[] learningHistory;
        uint256 totalLearningSessions;
        uint256 averageComprehensionScore;
        string[] expertiseAreas;
        mapping(string => uint256) expertiseLevels;
        PrivacySettings privacySettings;
        mapping(address => bytes) publicKeys;  // Store public keys for encryption
    }

    struct EstatePlan {
        string name;
        string description;
        uint256 creationDate;
        uint256 lastReviewDate;
        bool isActive;
        string[] goals;
        mapping(string => string) instructions;
        mapping(string => uint256) milestones;
        mapping(address => string) heirRoles;
    }

    struct AIRecommendation {
        string category;
        string description;
        uint256 priority;
        bool isImplemented;
        uint256 implementationDate;
        address[] affectedParties;
    }

    mapping(address => AIAgent) private agents;
    mapping(address => EstatePlan) private estatePlans;
    mapping(address => AIRecommendation[]) private recommendations;
    mapping(address => mapping(string => bool)) private implementedRecommendations;
    mapping(string => KnowledgeBase) private globalKnowledgeBase;

    event AIAgentCreated(address indexed owner, string name);
    event EstatePlanCreated(address indexed owner, string name);
    event RecommendationGenerated(address indexed owner, string category, string description);
    event RecommendationImplemented(address indexed owner, string category);
    event AssetThresholdUpdated(address indexed owner, string assetType, uint256 threshold);
    event HeirRoleUpdated(address indexed owner, address heir, string role);
    event EstatePlanReviewed(address indexed owner, uint256 reviewDate);
    event KnowledgeAdded(address indexed owner, string category, string content);
    event LearningSessionCompleted(address indexed learner, string topic, uint256 score);
    event ExpertiseUpdated(address indexed owner, string area, uint256 level);
    event KnowledgeVerified(address indexed verifier, string category);
    event LearningPathCreated(address indexed owner, string[] topics);
    event KnowledgeShared(address indexed from, address indexed to, string category);
    event PrivacySettingsUpdated(address indexed owner);
    event DataEncrypted(address indexed owner, string category);
    event AccessGranted(address indexed owner, address indexed viewer, string category);
    event AccessRevoked(address indexed owner, address indexed viewer, string category);
    event PublicKeyUpdated(address indexed owner, address indexed user);
    event LearningSessionCreated(address indexed owner, string topic);

    constructor(address _legacyContract) {
        legacyContract = Legacy(_legacyContract);
    }

    function createAIAgent(
        string memory name,
        string memory description,
        string[] memory capabilities,
        uint256 updateInterval
    ) external {
        require(agents[msg.sender].owner == address(0), "Agent already exists");
        
        AIAgent storage agent = agents[msg.sender];
        agent.owner = msg.sender;
        agent.name = name;
        agent.description = description;
        agent.isActive = true;
        agent.lastUpdate = block.timestamp;
        agent.updateInterval = updateInterval;
        agent.capabilities = capabilities;

        emit AIAgentCreated(msg.sender, name);
    }

    function createEstatePlan(
        string memory name,
        string memory description,
        string[] memory goals,
        string[] memory goalInstructions
    ) external {
        require(agents[msg.sender].isActive, "No active AI agent");
        require(estatePlans[msg.sender].creationDate == 0, "Estate plan already exists");
        
        EstatePlan storage plan = estatePlans[msg.sender];
        plan.name = name;
        plan.description = description;
        plan.creationDate = block.timestamp;
        plan.lastReviewDate = block.timestamp;
        plan.isActive = true;
        plan.goals = goals;
        
        for (uint256 i = 0; i < goals.length; i++) {
            plan.instructions[goals[i]] = goalInstructions[i];
        }

        emit EstatePlanCreated(msg.sender, name);
    }

    function addHeirRole(
        address heir,
        string memory role,
        string memory instructions
    ) external {
        require(estatePlans[msg.sender].isActive, "No active estate plan");
        estatePlans[msg.sender].heirRoles[heir] = role;
        estatePlans[msg.sender].instructions[role] = instructions;
        agents[msg.sender].authorizedHeirs[heir] = true;
        
        emit HeirRoleUpdated(msg.sender, heir, role);
    }

    function setAssetThreshold(
        string memory assetType,
        uint256 threshold,
        string memory strategy
    ) external {
        require(estatePlans[msg.sender].isActive, "No active estate plan");
        agents[msg.sender].assetThresholds[assetType] = threshold;
        agents[msg.sender].assetStrategies[assetType] = strategy;
        
        emit AssetThresholdUpdated(msg.sender, assetType, threshold);
    }

    function generateRecommendations() external {
        require(agents[msg.sender].isActive, "No active AI agent");
        require(estatePlans[msg.sender].isActive, "No active estate plan");
        
        // Check if it's time for an update
        AIAgent storage agent = agents[msg.sender];
        require(
            block.timestamp >= agent.lastUpdate + agent.updateInterval,
            "Too soon for update"
        );

        // Generate recommendations based on estate plan and current state
        _generateAssetRecommendations(msg.sender);
        _generateHeirRecommendations(msg.sender);
        _generateStrategyRecommendations(msg.sender);

        agent.lastUpdate = block.timestamp;
    }

    function implementRecommendation(
        string memory category
    ) external {
        require(agents[msg.sender].isActive, "Agent not active");
        
        // Mark recommendation as implemented
        implementedRecommendations[msg.sender][category] = true;
        
        emit RecommendationImplemented(msg.sender, category);
    }

    function reviewEstatePlan() external {
        require(estatePlans[msg.sender].isActive, "No active estate plan");
        estatePlans[msg.sender].lastReviewDate = block.timestamp;
        emit EstatePlanReviewed(msg.sender, block.timestamp);
    }

    function updatePrivacySettings(
        bool encryptAllData,
        bool autoShareWithHeirs,
        bool allowKnowledgeTransfer
    ) external {
        require(agents[msg.sender].isActive, "No active AI agent");
        
        AIAgent storage agent = agents[msg.sender];
        agent.privacySettings.encryptAllData = encryptAllData;
        agent.privacySettings.autoShareWithHeirs = autoShareWithHeirs;
        agent.privacySettings.allowKnowledgeTransfer = allowKnowledgeTransfer;
        
        emit PrivacySettingsUpdated(msg.sender);
    }

    function setPublicKey(
        bytes memory publicKey
    ) external {
        require(agents[msg.sender].isActive, "No active AI agent");
        agents[msg.sender].publicKeys[msg.sender] = publicKey;
        emit PublicKeyUpdated(msg.sender, msg.sender);
    }

    function addKnowledge(
        string memory category,
        bytes memory encryptedContent,
        bytes memory encryptionKey,
        string[] memory relatedTopics,
        bool encrypt
    ) external {
        require(agents[msg.sender].isActive, "No active AI agent");
        
        KnowledgeBase storage kb = agents[msg.sender].knowledgeBase[category];
        kb.category = category;
        kb.isEncrypted = encrypt;
        
        if (encrypt) {
            kb.content.encryptedContent = encryptedContent;
            kb.content.encryptionKey = encryptionKey;
            kb.content.timestamp = block.timestamp;
            kb.content.authorizedViewers.push(msg.sender);
            kb.content.canView[msg.sender] = true;
            kb.content.canShare[msg.sender] = true;
        }
        
        kb.relatedTopics = relatedTopics;
        kb.contributors.push(msg.sender);
        kb.contributionScores[msg.sender] += 1;
        
        emit KnowledgeAdded(msg.sender, category, "Encrypted Content");
        if (encrypt) {
            emit DataEncrypted(msg.sender, category);
        }
    }

    function grantAccess(
        address viewer,
        string memory category,
        bool canShare
    ) external {
        require(agents[msg.sender].isActive, "No active AI agent");
        require(agents[msg.sender].knowledgeBase[category].isEncrypted, "Data not encrypted");
        
        KnowledgeBase storage kb = agents[msg.sender].knowledgeBase[category];
        kb.content.authorizedViewers.push(viewer);
        kb.content.canView[viewer] = true;
        kb.content.canShare[viewer] = canShare;
        
        emit AccessGranted(msg.sender, viewer, category);
    }

    function revokeAccess(
        address viewer,
        string memory category
    ) external {
        require(agents[msg.sender].isActive, "No active AI agent");
        require(agents[msg.sender].knowledgeBase[category].isEncrypted, "Data not encrypted");
        
        KnowledgeBase storage kb = agents[msg.sender].knowledgeBase[category];
        kb.content.canView[viewer] = false;
        kb.content.canShare[viewer] = false;
        
        emit AccessRevoked(msg.sender, viewer, category);
    }

    function createLearningSession(
        string memory topic,
        bytes memory encryptedQuestions,
        bytes memory encryptedAnswers,
        address[] memory authorizedViewers
    ) external {
        require(agents[msg.sender].isActive, "Agent not active");
        
        // Create a new learning session
        LearningSession memory newSession = LearningSession({
            topic: topic,
            encryptedQuestions: encryptedQuestions,
            encryptedAnswers: encryptedAnswers,
            timestamp: block.timestamp,
            learner: msg.sender,
            comprehensionScore: 0,
            isEncrypted: true,
            authorizedViewers: authorizedViewers
        });
        
        // Add the session to the agent's learning history
        agents[msg.sender].learningHistory.push(newSession);
        agents[msg.sender].totalLearningSessions++;
        
        emit LearningSessionCreated(msg.sender, topic);
    }

    function updateExpertise(
        string memory area,
        uint256 level
    ) external {
        require(agents[msg.sender].isActive, "No active AI agent");
        require(level <= 100, "Invalid expertise level");
        
        AIAgent storage agent = agents[msg.sender];
        if (agent.expertiseLevels[area] == 0) {
            agent.expertiseAreas.push(area);
        }
        agent.expertiseLevels[area] = level;
        
        emit ExpertiseUpdated(msg.sender, area, level);
    }

    function verifyKnowledge(
        string memory category,
        bool isVerified
    ) external {
        require(agents[msg.sender].isActive, "No active AI agent");
        agents[msg.sender].knowledgeBase[category].isVerified = isVerified;
        
        emit KnowledgeVerified(msg.sender, category);
    }

    function createLearningPath(
        string[] memory topics
    ) external {
        require(agents[msg.sender].isActive, "No active AI agent");
        emit LearningPathCreated(msg.sender, topics);
    }

    function shareKnowledgeBase(
        string memory category,
        address recipient
    ) external {
        require(agents[msg.sender].isActive, "Agent not active");
        require(agents[recipient].isActive, "Recipient agent not active");
        
        KnowledgeBase storage sourceKB = agents[msg.sender].knowledgeBase[category];
        KnowledgeBase storage destKB = agents[recipient].knowledgeBase[category];
        
        // Copy non-mapping fields
        destKB.category = sourceKB.category;
        destKB.lastUpdated = block.timestamp;
        destKB.contributors = sourceKB.contributors;
        destKB.relatedTopics = sourceKB.relatedTopics;
        destKB.isVerified = sourceKB.isVerified;
        destKB.isEncrypted = sourceKB.isEncrypted;
        
        // Copy encrypted content
        bytes memory encryptedContent = sourceKB.content.encryptedContent;
        address[] memory authorizedViewers = sourceKB.content.authorizedViewers;
        
        destKB.content.encryptedContent = encryptedContent;
        destKB.content.timestamp = block.timestamp;
        destKB.content.authorizedViewers = authorizedViewers;
        
        // Add recipient to authorized viewers
        destKB.content.canView[recipient] = true;
        destKB.content.canShare[recipient] = true;
        
        emit KnowledgeShared(msg.sender, recipient, category);
    }

    function getLearningHistory(
        address owner
    ) external view returns (LearningSession[] memory) {
        require(agents[owner].isActive, "No active AI agent");
        return agents[owner].learningHistory;
    }

    function getExpertiseAreas(
        address owner
    ) external view returns (string[] memory, uint256[] memory) {
        AIAgent storage agent = agents[owner];
        uint256[] memory levels = new uint256[](agent.expertiseAreas.length);
        
        for (uint256 i = 0; i < agent.expertiseAreas.length; i++) {
            levels[i] = agent.expertiseLevels[agent.expertiseAreas[i]];
        }
        
        return (agent.expertiseAreas, levels);
    }

    function getKnowledgeBase(
        address owner,
        string memory category
    ) external view returns (
        bytes memory content,
        uint256 lastUpdated,
        address[] memory contributors,
        string[] memory relatedTopics,
        bool isVerified,
        bool isEncrypted
    ) {
        require(agents[owner].isActive, "No active AI agent");
        KnowledgeBase storage kb = agents[owner].knowledgeBase[category];
        
        if (kb.isEncrypted) {
            require(kb.content.canView[msg.sender], "Not authorized to view encrypted content");
        }
        
        return (
            kb.content.encryptedContent,
            kb.lastUpdated,
            kb.contributors,
            kb.relatedTopics,
            kb.isVerified,
            kb.isEncrypted
        );
    }

    // Enhanced recommendation generation with learning capabilities
    function _generateAssetRecommendations(address owner) internal view {
        AIAgent storage agent = agents[owner];
        require(agent.isActive, "Agent not active");
        
        // TODO: Implement asset recommendation logic
    }

    function _generateHeirRecommendations(address owner) internal view {
        AIAgent storage agent = agents[owner];
        require(agent.isActive, "Agent not active");
        
        // TODO: Implement heir recommendation logic
    }

    function _generateStrategyRecommendations(address owner) internal view {
        AIAgent storage agent = agents[owner];
        require(agent.isActive, "Agent not active");
        
        // TODO: Implement strategy recommendation logic
    }

    // View functions
    function getAIAgent(address owner) external view returns (
        string memory name,
        string memory description,
        bool isActive,
        uint256 lastUpdate,
        string[] memory capabilities
    ) {
        AIAgent storage agent = agents[owner];
        return (
            agent.name,
            agent.description,
            agent.isActive,
            agent.lastUpdate,
            agent.capabilities
        );
    }

    function getEstatePlan(address owner) external view returns (
        string memory name,
        string memory description,
        uint256 creationDate,
        uint256 lastReviewDate,
        bool isActive,
        string[] memory goals
    ) {
        EstatePlan storage plan = estatePlans[owner];
        return (
            plan.name,
            plan.description,
            plan.creationDate,
            plan.lastReviewDate,
            plan.isActive,
            plan.goals
        );
    }

    function getRecommendations(address owner) external view returns (AIRecommendation[] memory) {
        return recommendations[owner];
    }

    function getHeirRole(address owner, address heir) external view returns (string memory) {
        return estatePlans[owner].heirRoles[heir];
    }

    function getAssetThreshold(address owner, string memory assetType) external view returns (uint256) {
        return agents[owner].assetThresholds[assetType];
    }
} 