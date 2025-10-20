// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title StakingPool
 * @notice A production-ready staking contract with RBAC, pausability, and time-based rewards
 * @dev Users stake tokens to earn rewards over time. Supports multi-role access control.
 */
contract StakingPool is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    // ============ Roles ============

    /// @notice Role for operators who can manage rewards and parameters
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    /// @notice Role for pausers who can pause/unpause the contract in emergencies
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // ============ State Variables ============

    /// @notice The token users stake
    IERC20 public immutable stakingToken;

    /// @notice The token users receive as rewards
    IERC20 public immutable rewardToken;

    /// @notice Reward rate per second (in reward token wei)
    uint256 public rewardRate;

    /// @notice Timestamp when rewards period ends
    uint256 public periodFinish;

    /// @notice Last time rewards were updated
    uint256 public lastUpdateTime;

    /// @notice Accumulated reward per token stored
    uint256 public rewardPerTokenStored;

    /// @notice Total amount of tokens staked
    uint256 public totalStaked;

    /// @notice Minimum amount required to stake
    uint256 public minStakeAmount;

    /// @notice User's reward per token paid
    mapping(address => uint256) public userRewardPerTokenPaid;

    /// @notice User's pending rewards
    mapping(address => uint256) public rewards;

    /// @notice User's staked balance
    mapping(address => uint256) public balanceOf;

    // ============ Events ============

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 reward);
    event RewardAdded(uint256 reward, uint256 duration);
    event RewardRateUpdated(uint256 newRate);
    event MinStakeAmountUpdated(uint256 newAmount);
    event EmergencyWithdraw(address indexed token, uint256 amount);

    // ============ Errors ============

    error ZeroAmount();
    error ZeroDuration();
    error InsufficientBalance();
    error BelowMinimumStake();
    error RewardPeriodNotFinished();
    error InvalidRewardAmount();

    // ============ Constructor ============

    /**
     * @notice Initialize the staking pool
     * @param _stakingToken Address of the token to be staked
     * @param _rewardToken Address of the reward token
     * @param _minStakeAmount Minimum amount required to stake
     */
    constructor(
        address _stakingToken,
        address _rewardToken,
        uint256 _minStakeAmount
    ) {
        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
        minStakeAmount = _minStakeAmount;

        // Grant roles to deployer
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
    }

    // ============ Modifiers ============

    /**
     * @notice Updates reward state before executing function
     * @param account Address to update rewards for
     */
    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();

        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    // ============ View Functions ============

    /**
     * @notice Get the last time rewards are applicable
     * @return Timestamp of last applicable reward time
     */
    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    /**
     * @notice Calculate accumulated reward per token
     * @return Reward per token value
     */
    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }

        return rewardPerTokenStored +
            (((lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * 1e18) / totalStaked);
    }

    /**
     * @notice Calculate earned rewards for an account
     * @param account Address to check rewards for
     * @return Amount of rewards earned
     */
    function earned(address account) public view returns (uint256) {
        return ((balanceOf[account] * (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18) +
            rewards[account];
    }

    /**
     * @notice Get remaining reward duration
     * @return Time remaining in seconds
     */
    function getRewardDuration() external view returns (uint256) {
        if (block.timestamp >= periodFinish) {
            return 0;
        }
        return periodFinish - block.timestamp;
    }

    // ============ User Functions ============

    /**
     * @notice Stake tokens to earn rewards
     * @param amount Amount of tokens to stake
     */
    function stake(uint256 amount)
        external
        nonReentrant
        whenNotPaused
        updateReward(msg.sender)
    {
        if (amount == 0) revert ZeroAmount();
        if (amount < minStakeAmount) revert BelowMinimumStake();

        totalStaked += amount;
        balanceOf[msg.sender] += amount;

        stakingToken.safeTransferFrom(msg.sender, address(this), amount);

        emit Staked(msg.sender, amount);
    }

    /**
     * @notice Unstake tokens
     * @param amount Amount of tokens to unstake
     */
    function unstake(uint256 amount)
        external
        nonReentrant
        updateReward(msg.sender)
    {
        _unstake(msg.sender, amount);
    }

    /**
     * @notice Claim accumulated rewards
     */
    function claimRewards()
        external
        nonReentrant
        updateReward(msg.sender)
    {
        _claimRewards(msg.sender);
    }

    /**
     * @notice Unstake all tokens and claim all rewards
     */
    function exit() external nonReentrant updateReward(msg.sender) {
        uint256 stakedBalance = balanceOf[msg.sender];
        uint256 pendingRewards = rewards[msg.sender];

        if (stakedBalance > 0) {
            _unstake(msg.sender, stakedBalance);
        }
        if (pendingRewards > 0) {
            _claimRewards(msg.sender);
        }
    }

    /**
     * @dev Internal unstake logic
     */
    function _unstake(address account, uint256 amount) internal {
        if (amount == 0) revert ZeroAmount();
        if (balanceOf[account] < amount) revert InsufficientBalance();

        totalStaked -= amount;
        balanceOf[account] -= amount;

        stakingToken.safeTransfer(account, amount);

        emit Unstaked(account, amount);
    }

    /**
     * @dev Internal claim rewards logic
     */
    function _claimRewards(address account) internal {
        uint256 reward = rewards[account];
        if (reward == 0) revert ZeroAmount();

        rewards[account] = 0;
        rewardToken.safeTransfer(account, reward);

        emit RewardClaimed(account, reward);
    }

    // ============ Operator Functions ============

    /**
     * @notice Add rewards and set duration for distribution
     * @param reward Amount of reward tokens to add
     * @param duration Duration in seconds to distribute rewards over
     */
    function notifyRewardAmount(uint256 reward, uint256 duration)
        external
        onlyRole(OPERATOR_ROLE)
        updateReward(address(0))
    {
        if (reward == 0) revert ZeroAmount();
        if (duration == 0) revert ZeroDuration();

        // Transfer reward tokens to contract
        rewardToken.safeTransferFrom(msg.sender, address(this), reward);

        if (block.timestamp >= periodFinish) {
            // Start new reward period
            rewardRate = reward / duration;
        } else {
            // Add to existing reward period
            uint256 remaining = periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardRate;
            rewardRate = (reward + leftover) / duration;
        }

        // Ensure reward rate is valid
        if (rewardRate == 0) revert InvalidRewardAmount();
        if (rewardRate * duration > rewardToken.balanceOf(address(this))) {
            revert InvalidRewardAmount();
        }

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + duration;

        emit RewardAdded(reward, duration);
    }

    /**
     * @notice Update the minimum stake amount
     * @param _minStakeAmount New minimum stake amount
     */
    function setMinStakeAmount(uint256 _minStakeAmount)
        external
        onlyRole(OPERATOR_ROLE)
    {
        minStakeAmount = _minStakeAmount;
        emit MinStakeAmountUpdated(_minStakeAmount);
    }

    /**
     * @notice Recover ERC20 tokens accidentally sent to contract (except staking/reward tokens)
     * @param tokenAddress Address of token to recover
     * @param tokenAmount Amount of tokens to recover
     */
    function recoverERC20(address tokenAddress, uint256 tokenAmount)
        external
        onlyRole(OPERATOR_ROLE)
    {
        require(
            tokenAddress != address(stakingToken) && tokenAddress != address(rewardToken),
            "Cannot withdraw staking or reward tokens"
        );
        IERC20(tokenAddress).safeTransfer(msg.sender, tokenAmount);
    }

    // ============ Pauser Functions ============

    /**
     * @notice Pause the contract (stops staking)
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause the contract
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // ============ Admin Functions ============

    /**
     * @notice Emergency withdrawal of tokens (ADMIN only, use with caution)
     * @param tokenAddress Address of token to withdraw
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(address tokenAddress, uint256 amount)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        IERC20(tokenAddress).safeTransfer(msg.sender, amount);
        emit EmergencyWithdraw(tokenAddress, amount);
    }
}
