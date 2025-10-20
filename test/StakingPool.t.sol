// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/StakingPool.sol";
import "../src/mocks/StakeToken.sol";
import "../src/mocks/RewardToken.sol";

contract StakingPoolTest is Test {
    StakingPool public stakingPool;
    StakeToken public stakeToken;
    RewardToken public rewardToken;

    address public admin = address(1);
    address public operator = address(2);
    address public pauser = address(3);
    address public user1 = address(4);
    address public user2 = address(5);

    uint256 constant INITIAL_SUPPLY = 1_000_000 * 1e18;
    uint256 constant MIN_STAKE_AMOUNT = 100 * 1e18;
    uint256 constant REWARD_DURATION = 7 days;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 reward);
    event RewardAdded(uint256 reward, uint256 duration);

    function setUp() public {
        // Deploy tokens
        vm.startPrank(admin);
        stakeToken = new StakeToken(INITIAL_SUPPLY);
        rewardToken = new RewardToken(INITIAL_SUPPLY);

        // Deploy staking pool
        stakingPool = new StakingPool(
            address(stakeToken),
            address(rewardToken),
            MIN_STAKE_AMOUNT
        );

        // Grant roles
        stakingPool.grantRole(stakingPool.OPERATOR_ROLE(), operator);
        stakingPool.grantRole(stakingPool.PAUSER_ROLE(), pauser);

        // Distribute tokens
        stakeToken.transfer(user1, 10_000 * 1e18);
        stakeToken.transfer(user2, 10_000 * 1e18);
        rewardToken.transfer(operator, 100_000 * 1e18);

        vm.stopPrank();
    }

    // ============ Basic Functionality Tests ============

    function testStake() public {
        uint256 stakeAmount = 1000 * 1e18;

        vm.startPrank(user1);
        stakeToken.approve(address(stakingPool), stakeAmount);

        vm.expectEmit(true, false, false, true);
        emit Staked(user1, stakeAmount);

        stakingPool.stake(stakeAmount);
        vm.stopPrank();

        assertEq(stakingPool.balanceOf(user1), stakeAmount);
        assertEq(stakingPool.totalStaked(), stakeAmount);
        assertEq(stakeToken.balanceOf(user1), 9000 * 1e18);
    }

    function testStakeRevertsOnZeroAmount() public {
        vm.startPrank(user1);
        stakeToken.approve(address(stakingPool), 1000 * 1e18);

        vm.expectRevert(StakingPool.ZeroAmount.selector);
        stakingPool.stake(0);
        vm.stopPrank();
    }

    function testStakeRevertsBelowMinimum() public {
        uint256 belowMin = MIN_STAKE_AMOUNT - 1;

        vm.startPrank(user1);
        stakeToken.approve(address(stakingPool), belowMin);

        vm.expectRevert(StakingPool.BelowMinimumStake.selector);
        stakingPool.stake(belowMin);
        vm.stopPrank();
    }

    function testUnstake() public {
        uint256 stakeAmount = 1000 * 1e18;
        uint256 unstakeAmount = 500 * 1e18;

        // First stake
        vm.startPrank(user1);
        stakeToken.approve(address(stakingPool), stakeAmount);
        stakingPool.stake(stakeAmount);

        // Then unstake
        vm.expectEmit(true, false, false, true);
        emit Unstaked(user1, unstakeAmount);

        stakingPool.unstake(unstakeAmount);
        vm.stopPrank();

        assertEq(stakingPool.balanceOf(user1), stakeAmount - unstakeAmount);
        assertEq(stakingPool.totalStaked(), stakeAmount - unstakeAmount);
        assertEq(stakeToken.balanceOf(user1), 9500 * 1e18);
    }

    function testUnstakeRevertsOnInsufficientBalance() public {
        uint256 stakeAmount = 1000 * 1e18;

        vm.startPrank(user1);
        stakeToken.approve(address(stakingPool), stakeAmount);
        stakingPool.stake(stakeAmount);

        vm.expectRevert(StakingPool.InsufficientBalance.selector);
        stakingPool.unstake(stakeAmount + 1);
        vm.stopPrank();
    }

    function testUnstakeRevertsOnZeroAmount() public {
        vm.startPrank(user1);
        vm.expectRevert(StakingPool.ZeroAmount.selector);
        stakingPool.unstake(0);
        vm.stopPrank();
    }

    // ============ Reward Tests ============

    function testNotifyRewardAmount() public {
        uint256 rewardAmount = 7000 * 1e18;

        vm.startPrank(operator);
        rewardToken.approve(address(stakingPool), rewardAmount);

        vm.expectEmit(false, false, false, true);
        emit RewardAdded(rewardAmount, REWARD_DURATION);

        stakingPool.notifyRewardAmount(rewardAmount, REWARD_DURATION);
        vm.stopPrank();

        assertEq(stakingPool.rewardRate(), rewardAmount / REWARD_DURATION);
        assertEq(stakingPool.periodFinish(), block.timestamp + REWARD_DURATION);
    }

    function testEarnRewards() public {
        uint256 stakeAmount = 1000 * 1e18;
        uint256 rewardAmount = 7000 * 1e18;

        // Setup rewards
        vm.startPrank(operator);
        rewardToken.approve(address(stakingPool), rewardAmount);
        stakingPool.notifyRewardAmount(rewardAmount, REWARD_DURATION);
        vm.stopPrank();

        // User stakes
        vm.startPrank(user1);
        stakeToken.approve(address(stakingPool), stakeAmount);
        stakingPool.stake(stakeAmount);
        vm.stopPrank();

        // Fast forward time
        vm.warp(block.timestamp + REWARD_DURATION);

        // Check earned rewards (should be approximately all rewards)
        uint256 earned = stakingPool.earned(user1);
        assertApproxEqAbs(earned, rewardAmount, 1e18); // Allow 1 token variance
    }

    function testClaimRewards() public {
        uint256 stakeAmount = 1000 * 1e18;
        uint256 rewardAmount = 7000 * 1e18;

        // Setup rewards
        vm.startPrank(operator);
        rewardToken.approve(address(stakingPool), rewardAmount);
        stakingPool.notifyRewardAmount(rewardAmount, REWARD_DURATION);
        vm.stopPrank();

        // User stakes
        vm.startPrank(user1);
        stakeToken.approve(address(stakingPool), stakeAmount);
        stakingPool.stake(stakeAmount);

        // Fast forward time
        vm.warp(block.timestamp + REWARD_DURATION);

        uint256 earnedRewards = stakingPool.earned(user1);
        uint256 balanceBefore = rewardToken.balanceOf(user1);

        vm.expectEmit(true, false, false, true);
        emit RewardClaimed(user1, earnedRewards);

        stakingPool.claimRewards();
        vm.stopPrank();

        assertEq(rewardToken.balanceOf(user1), balanceBefore + earnedRewards);
        assertEq(stakingPool.rewards(user1), 0);
    }

    function testClaimRewardsRevertsOnZeroRewards() public {
        vm.startPrank(user1);
        vm.expectRevert(StakingPool.ZeroAmount.selector);
        stakingPool.claimRewards();
        vm.stopPrank();
    }

    function testMultipleUsersEarnProportionalRewards() public {
        uint256 user1Stake = 1000 * 1e18;
        uint256 user2Stake = 3000 * 1e18; // 3x more than user1
        uint256 rewardAmount = 8000 * 1e18;

        // Setup rewards
        vm.startPrank(operator);
        rewardToken.approve(address(stakingPool), rewardAmount);
        stakingPool.notifyRewardAmount(rewardAmount, REWARD_DURATION);
        vm.stopPrank();

        // User1 stakes
        vm.startPrank(user1);
        stakeToken.approve(address(stakingPool), user1Stake);
        stakingPool.stake(user1Stake);
        vm.stopPrank();

        // User2 stakes
        vm.startPrank(user2);
        stakeToken.approve(address(stakingPool), user2Stake);
        stakingPool.stake(user2Stake);
        vm.stopPrank();

        // Fast forward time
        vm.warp(block.timestamp + REWARD_DURATION);

        uint256 user1Earned = stakingPool.earned(user1);
        uint256 user2Earned = stakingPool.earned(user2);

        // User2 should earn approximately 3x more (with some rounding variance)
        assertApproxEqRel(user2Earned, user1Earned * 3, 0.01e18); // 1% tolerance
    }

    function testExit() public {
        uint256 stakeAmount = 1000 * 1e18;
        uint256 rewardAmount = 7000 * 1e18;

        // Setup rewards
        vm.startPrank(operator);
        rewardToken.approve(address(stakingPool), rewardAmount);
        stakingPool.notifyRewardAmount(rewardAmount, REWARD_DURATION);
        vm.stopPrank();

        // User stakes
        vm.startPrank(user1);
        stakeToken.approve(address(stakingPool), stakeAmount);
        stakingPool.stake(stakeAmount);

        // Fast forward time
        vm.warp(block.timestamp + REWARD_DURATION);

        uint256 stakeBalanceBefore = stakeToken.balanceOf(user1);
        uint256 rewardBalanceBefore = rewardToken.balanceOf(user1);
        uint256 earnedRewards = stakingPool.earned(user1);

        // Exit (unstake all + claim rewards)
        stakingPool.exit();
        vm.stopPrank();

        assertEq(stakingPool.balanceOf(user1), 0);
        assertEq(stakeToken.balanceOf(user1), stakeBalanceBefore + stakeAmount);
        assertEq(rewardToken.balanceOf(user1), rewardBalanceBefore + earnedRewards);
    }

    // ============ Access Control Tests ============

    function testOnlyOperatorCanNotifyReward() public {
        uint256 rewardAmount = 7000 * 1e18;

        vm.startPrank(user1);
        rewardToken.approve(address(stakingPool), rewardAmount);

        vm.expectRevert();
        stakingPool.notifyRewardAmount(rewardAmount, REWARD_DURATION);
        vm.stopPrank();
    }

    function testOnlyOperatorCanSetMinStakeAmount() public {
        vm.startPrank(user1);
        vm.expectRevert();
        stakingPool.setMinStakeAmount(50 * 1e18);
        vm.stopPrank();
    }

    function testOperatorCanSetMinStakeAmount() public {
        uint256 newMinStake = 50 * 1e18;

        vm.prank(operator);
        stakingPool.setMinStakeAmount(newMinStake);

        assertEq(stakingPool.minStakeAmount(), newMinStake);
    }

    function testOnlyPauserCanPause() public {
        vm.startPrank(user1);
        vm.expectRevert();
        stakingPool.pause();
        vm.stopPrank();
    }

    function testPauserCanPauseAndUnpause() public {
        vm.startPrank(pauser);
        stakingPool.pause();
        assertTrue(stakingPool.paused());

        stakingPool.unpause();
        assertFalse(stakingPool.paused());
        vm.stopPrank();
    }

    function testStakingPausedWhenContractPaused() public {
        uint256 stakeAmount = 1000 * 1e18;

        vm.prank(pauser);
        stakingPool.pause();

        vm.startPrank(user1);
        stakeToken.approve(address(stakingPool), stakeAmount);

        vm.expectRevert();
        stakingPool.stake(stakeAmount);
        vm.stopPrank();
    }

    function testOnlyAdminCanEmergencyWithdraw() public {
        vm.startPrank(user1);
        vm.expectRevert();
        stakingPool.emergencyWithdraw(address(stakeToken), 1000 * 1e18);
        vm.stopPrank();
    }

    function testAdminCanEmergencyWithdraw() public {
        // Send some tokens to the contract
        vm.prank(admin);
        stakeToken.transfer(address(stakingPool), 1000 * 1e18);

        uint256 balanceBefore = stakeToken.balanceOf(admin);

        vm.prank(admin);
        stakingPool.emergencyWithdraw(address(stakeToken), 1000 * 1e18);

        assertEq(stakeToken.balanceOf(admin), balanceBefore + 1000 * 1e18);
    }

    function testOperatorCannotWithdrawStakingOrRewardTokens() public {
        // User stakes
        vm.startPrank(user1);
        stakeToken.approve(address(stakingPool), 1000 * 1e18);
        stakingPool.stake(1000 * 1e18);
        vm.stopPrank();

        // Operator tries to recover staking tokens
        vm.startPrank(operator);
        vm.expectRevert();
        stakingPool.recoverERC20(address(stakeToken), 100 * 1e18);

        vm.expectRevert();
        stakingPool.recoverERC20(address(rewardToken), 100 * 1e18);
        vm.stopPrank();
    }

    // ============ Edge Cases & Security Tests ============

    function testRewardPerTokenWhenNoStakers() public {
        assertEq(stakingPool.rewardPerToken(), 0);
    }

    function testLastTimeRewardApplicable() public {
        uint256 rewardAmount = 7000 * 1e18;

        vm.startPrank(operator);
        rewardToken.approve(address(stakingPool), rewardAmount);
        stakingPool.notifyRewardAmount(rewardAmount, REWARD_DURATION);
        vm.stopPrank();

        uint256 expectedFinish = block.timestamp + REWARD_DURATION;

        // Before period ends
        assertEq(stakingPool.lastTimeRewardApplicable(), block.timestamp);

        // After period ends
        vm.warp(expectedFinish + 1);
        assertEq(stakingPool.lastTimeRewardApplicable(), expectedFinish);
    }

    function testGetRewardDuration() public {
        uint256 rewardAmount = 7000 * 1e18;

        vm.startPrank(operator);
        rewardToken.approve(address(stakingPool), rewardAmount);
        stakingPool.notifyRewardAmount(rewardAmount, REWARD_DURATION);
        vm.stopPrank();

        assertEq(stakingPool.getRewardDuration(), REWARD_DURATION);

        vm.warp(block.timestamp + REWARD_DURATION / 2);
        assertEq(stakingPool.getRewardDuration(), REWARD_DURATION / 2);

        vm.warp(block.timestamp + REWARD_DURATION);
        assertEq(stakingPool.getRewardDuration(), 0);
    }

    function testNotifyRewardAmountRevertsOnZeroReward() public {
        vm.startPrank(operator);
        rewardToken.approve(address(stakingPool), 1000 * 1e18);

        vm.expectRevert(StakingPool.ZeroAmount.selector);
        stakingPool.notifyRewardAmount(0, REWARD_DURATION);
        vm.stopPrank();
    }

    function testNotifyRewardAmountRevertsOnZeroDuration() public {
        vm.startPrank(operator);
        rewardToken.approve(address(stakingPool), 1000 * 1e18);

        vm.expectRevert(StakingPool.ZeroDuration.selector);
        stakingPool.notifyRewardAmount(1000 * 1e18, 0);
        vm.stopPrank();
    }

    function testStakeAndUnstakeMultipleTimes() public {
        uint256 amount = 1000 * 1e18;

        vm.startPrank(user1);
        stakeToken.approve(address(stakingPool), amount * 3);

        stakingPool.stake(amount);
        assertEq(stakingPool.balanceOf(user1), amount);

        stakingPool.stake(amount);
        assertEq(stakingPool.balanceOf(user1), amount * 2);

        stakingPool.unstake(amount / 2);
        assertEq(stakingPool.balanceOf(user1), amount * 2 - amount / 2);

        stakingPool.stake(amount);
        assertEq(stakingPool.balanceOf(user1), amount * 3 - amount / 2);

        vm.stopPrank();
    }

    // ============ Fuzz Tests ============

    function testFuzzStake(uint256 amount) public {
        amount = bound(amount, MIN_STAKE_AMOUNT, 10_000 * 1e18);

        vm.startPrank(user1);
        stakeToken.approve(address(stakingPool), amount);
        stakingPool.stake(amount);
        vm.stopPrank();

        assertEq(stakingPool.balanceOf(user1), amount);
        assertEq(stakingPool.totalStaked(), amount);
    }

    function testFuzzUnstake(uint256 stakeAmount, uint256 unstakeAmount) public {
        stakeAmount = bound(stakeAmount, MIN_STAKE_AMOUNT, 10_000 * 1e18);
        unstakeAmount = bound(unstakeAmount, 1, stakeAmount);

        vm.startPrank(user1);
        stakeToken.approve(address(stakingPool), stakeAmount);
        stakingPool.stake(stakeAmount);
        stakingPool.unstake(unstakeAmount);
        vm.stopPrank();

        assertEq(stakingPool.balanceOf(user1), stakeAmount - unstakeAmount);
    }

    function testFuzzRewards(uint256 rewardAmount, uint256 duration) public {
        rewardAmount = bound(rewardAmount, 1e18, 100_000 * 1e18);
        duration = bound(duration, 1 days, 365 days);

        vm.startPrank(operator);
        rewardToken.approve(address(stakingPool), rewardAmount);
        stakingPool.notifyRewardAmount(rewardAmount, duration);
        vm.stopPrank();

        assertEq(stakingPool.rewardRate(), rewardAmount / duration);
        assertEq(stakingPool.periodFinish(), block.timestamp + duration);
    }
}
