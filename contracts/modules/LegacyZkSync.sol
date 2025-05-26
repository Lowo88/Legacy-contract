// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@matterlabs/zksync-contracts/contracts/interfaces/IZkSync.sol";
import "@matterlabs/zksync-contracts/contracts/interfaces/IL1Bridge.sol";
import "@matterlabs/zksync-contracts/contracts/interfaces/IL2Bridge.sol";
import "../libraries/LegacyTypes.sol";
import "../verifiers/Halo2Verifier.sol";

contract LegacyZkSync is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Constants
    uint256 public constant MIN_DEPOSIT = 0.01 ether;
    uint256 public constant MAX_DEPOSIT = 100 ether;
    uint256 public constant OPERATION_COOLDOWN = 1 hours;
    uint256 public constant MIN_LGC_REQUIRED = 1 * 10**18; // 1 LGC required
    uint256 public constant WITHDRAWAL_DELAY = 1 days;

    // State variables
    IERC20 public immutable lgcToken;
    IZkSync public immutable zkSync;
    IL1Bridge public immutable l1Bridge;
    IL2Bridge public immutable l2Bridge;
    Halo2Verifier public immutable halo2Verifier;
    address public owner;

    // Mappings
    mapping(address => uint256) public lastOperationTime;
    mapping(bytes32 => bool) public usedProofs;
    mapping(address => bool) public isRegistered;
    mapping(address => uint256) public l2Balances;
    mapping(address => uint256) public pendingWithdrawals;
    mapping(address => uint256) public withdrawalTimestamps;

    // Events
    event ZkSyncDeposit(
        address indexed user,
        uint256 amount,
        bytes32 indexed proofId
    );
    event ZkSyncWithdrawal(
        address indexed user,
        uint256 amount,
        bytes32 indexed proofId
    );
    event ZkSyncTransfer(
        address indexed from,
        address indexed to,
        uint256 amount,
        bytes32 indexed proofId
    );
    event UserRegistered(
        address indexed user,
        bytes32 indexed proofId
    );
    event WithdrawalFinalized(
        address indexed user,
        uint256 amount
    );
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(
        address _zkSync,
        address _l1Bridge,
        address _l2Bridge,
        address _lgcToken,
        address _halo2Verifier
    ) {
        require(_zkSync != address(0), "Invalid zkSync address");
        require(_l1Bridge != address(0), "Invalid L1 bridge address");
        require(_l2Bridge != address(0), "Invalid L2 bridge address");
        require(_lgcToken != address(0), "Invalid LGC token address");
        require(_halo2Verifier != address(0), "Invalid verifier address");

        zkSync = IZkSync(_zkSync);
        l1Bridge = IL1Bridge(_l1Bridge);
        l2Bridge = IL2Bridge(_l2Bridge);
        lgcToken = IERC20(_lgcToken);
        halo2Verifier = Halo2Verifier(_halo2Verifier);
        owner = msg.sender;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function registerUser(
        bytes32[] calldata publicInputs,
        bytes calldata proof
    ) external nonReentrant {
        require(!isRegistered[msg.sender], "Already registered");
        require(lgcToken.balanceOf(msg.sender) >= MIN_LGC_REQUIRED, "Insufficient LGC");
        
        bytes32 proofId = keccak256(abi.encodePacked(
            msg.sender,
            block.timestamp,
            publicInputs
        ));
        
        require(halo2Verifier.verifyProof(proofId, publicInputs, proof), "Invalid proof");
        require(!usedProofs[proofId], "Proof already used");
        
        usedProofs[proofId] = true;
        isRegistered[msg.sender] = true;
        
        emit UserRegistered(msg.sender, proofId);
    }

    function depositToZkSync(
        uint256 amount,
        bytes32[] calldata publicInputs,
        bytes calldata proof
    ) external payable nonReentrant {
        require(isRegistered[msg.sender], "Not registered");
        require(amount >= MIN_DEPOSIT && amount <= MAX_DEPOSIT, "Invalid amount");
        require(block.timestamp >= lastOperationTime[msg.sender] + OPERATION_COOLDOWN, "Cooldown active");
        require(msg.value >= amount, "Insufficient ETH for gas");
        
        bytes32 proofId = keccak256(abi.encodePacked(
            msg.sender,
            block.timestamp,
            amount,
            publicInputs
        ));
        
        require(halo2Verifier.verifyProof(proofId, publicInputs, proof), "Invalid proof");
        require(!usedProofs[proofId], "Proof already used");
        
        usedProofs[proofId] = true;
        lastOperationTime[msg.sender] = block.timestamp;
        
        // Transfer LGC tokens to the contract
        lgcToken.safeTransferFrom(msg.sender, address(this), amount);
        
        // Approve L1 bridge to spend tokens
        lgcToken.safeApprove(address(l1Bridge), amount);
        
        // Deposit to zkSync
        l1Bridge.deposit{value: msg.value}(
            msg.sender,
            address(lgcToken),
            amount,
            abi.encodePacked(msg.sender)
        );
        
        // Update L2 balance
        l2Balances[msg.sender] += amount;
        
        emit ZkSyncDeposit(msg.sender, amount, proofId);
    }

    function withdrawFromZkSync(
        uint256 amount,
        bytes32[] calldata publicInputs,
        bytes calldata proof
    ) external nonReentrant {
        require(isRegistered[msg.sender], "Not registered");
        require(amount > 0, "Invalid amount");
        require(block.timestamp >= lastOperationTime[msg.sender] + OPERATION_COOLDOWN, "Cooldown active");
        require(l2Balances[msg.sender] >= amount, "Insufficient L2 balance");
        
        bytes32 proofId = keccak256(abi.encodePacked(
            msg.sender,
            block.timestamp,
            amount,
            publicInputs
        ));
        
        require(halo2Verifier.verifyProof(proofId, publicInputs, proof), "Invalid proof");
        require(!usedProofs[proofId], "Proof already used");
        
        usedProofs[proofId] = true;
        lastOperationTime[msg.sender] = block.timestamp;
        
        // Update L2 balance
        l2Balances[msg.sender] -= amount;
        
        // Initiate withdrawal from zkSync
        l2Bridge.withdraw(
            msg.sender,
            address(lgcToken),
            amount
        );
        
        pendingWithdrawals[msg.sender] += amount;
        withdrawalTimestamps[msg.sender] = block.timestamp;
        
        emit ZkSyncWithdrawal(msg.sender, amount, proofId);
    }

    function transferOnZkSync(
        address to,
        uint256 amount,
        bytes32[] calldata publicInputs,
        bytes calldata proof
    ) external nonReentrant {
        require(isRegistered[msg.sender] && isRegistered[to], "Not registered");
        require(amount > 0, "Invalid amount");
        require(block.timestamp >= lastOperationTime[msg.sender] + OPERATION_COOLDOWN, "Cooldown active");
        require(l2Balances[msg.sender] >= amount, "Insufficient L2 balance");
        
        bytes32 proofId = keccak256(abi.encodePacked(
            msg.sender,
            to,
            block.timestamp,
            amount,
            publicInputs
        ));
        
        require(halo2Verifier.verifyProof(proofId, publicInputs, proof), "Invalid proof");
        require(!usedProofs[proofId], "Proof already used");
        
        usedProofs[proofId] = true;
        lastOperationTime[msg.sender] = block.timestamp;
        
        // Update L2 balances
        l2Balances[msg.sender] -= amount;
        l2Balances[to] += amount;
        
        // Transfer on zkSync
        zkSync.transfer(
            to,
            amount,
            abi.encodePacked(msg.sender)
        );
        
        emit ZkSyncTransfer(msg.sender, to, amount, proofId);
    }

    function finalizeWithdrawal(
        address user,
        uint256 amount,
        bytes32[] calldata publicInputs,
        bytes calldata proof
    ) external nonReentrant {
        require(pendingWithdrawals[user] >= amount, "Insufficient pending withdrawal");
        require(block.timestamp >= withdrawalTimestamps[user] + WITHDRAWAL_DELAY, "Withdrawal delay not met");
        
        bytes32 proofId = keccak256(abi.encodePacked(
            user,
            block.timestamp,
            amount,
            publicInputs
        ));
        
        require(halo2Verifier.verifyProof(proofId, publicInputs, proof), "Invalid proof");
        require(!usedProofs[proofId], "Proof already used");
        
        usedProofs[proofId] = true;
        pendingWithdrawals[user] -= amount;
        
        // Transfer LGC tokens back to user
        lgcToken.safeTransfer(user, amount);
        
        emit WithdrawalFinalized(user, amount);
    }

    // View functions
    function getPendingWithdrawal(address user) external view returns (uint256) {
        return pendingWithdrawals[user];
    }

    function getL2Balance(address user) external view returns (uint256) {
        return l2Balances[user];
    }

    function isUserRegistered(address user) external view returns (bool) {
        return isRegistered[user];
    }

    function getWithdrawalTimestamp(address user) external view returns (uint256) {
        return withdrawalTimestamps[user];
    }

    // Emergency functions
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        require(token != address(lgcToken), "Cannot withdraw LGC");
        IERC20(token).safeTransfer(owner, amount);
    }

    function emergencyPause() external onlyOwner {
        // Implement emergency pause logic
    }
} 