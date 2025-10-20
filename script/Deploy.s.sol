// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/StakingPool.sol";
import "../src/mocks/StakeToken.sol";
import "../src/mocks/RewardToken.sol";

/**
 * @title Deploy Script
 * @notice Deployment script for the staking protocol
 * @dev Run with: forge script script/Deploy.s.sol:DeployScript --rpc-url <RPC_URL> --broadcast
 */
contract DeployScript is Script {
    // Configuration
    uint256 constant INITIAL_SUPPLY = 1_000_000 * 1e18;
    uint256 constant MIN_STAKE_AMOUNT = 100 * 1e18;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying contracts with account:", deployer);
        console.log("Account balance:", deployer.balance);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy StakeToken
        StakeToken stakeToken = new StakeToken(INITIAL_SUPPLY);
        console.log("StakeToken deployed at:", address(stakeToken));

        // Deploy RewardToken
        RewardToken rewardToken = new RewardToken(INITIAL_SUPPLY);
        console.log("RewardToken deployed at:", address(rewardToken));

        // Deploy StakingPool
        StakingPool stakingPool = new StakingPool(
            address(stakeToken),
            address(rewardToken),
            MIN_STAKE_AMOUNT
        );
        console.log("StakingPool deployed at:", address(stakingPool));

        vm.stopBroadcast();

        // Log deployment summary
        console.log("\n=== Deployment Summary ===");
        console.log("StakeToken:", address(stakeToken));
        console.log("RewardToken:", address(rewardToken));
        console.log("StakingPool:", address(stakingPool));
        console.log("Min Stake Amount:", MIN_STAKE_AMOUNT);
        console.log("Initial Supply:", INITIAL_SUPPLY);
        console.log("\n=== Roles ===");
        console.log("Admin:", deployer);
        console.log("Operator:", deployer);
        console.log("Pauser:", deployer);
    }
}

/**
 * @title Local Deploy Script
 * @notice Deployment script for local testing (Anvil)
 * @dev Run with: forge script script/Deploy.s.sol:DeployLocalScript --rpc-url http://localhost:8545 --broadcast
 */
contract DeployLocalScript is Script {
    // Configuration
    uint256 constant INITIAL_SUPPLY = 1_000_000 * 1e18;
    uint256 constant MIN_STAKE_AMOUNT = 100 * 1e18;
    uint256 constant REWARD_AMOUNT = 10_000 * 1e18;
    uint256 constant REWARD_DURATION = 7 days;

    // Anvil default accounts
    address constant DEPLOYER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address constant USER1 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address constant USER2 = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;

    function run() external {
        console.log("Deploying to local network (Anvil)...");
        console.log("Deployer:", DEPLOYER);

        vm.startBroadcast(DEPLOYER);

        // Deploy tokens
        StakeToken stakeToken = new StakeToken(INITIAL_SUPPLY);
        console.log("StakeToken deployed at:", address(stakeToken));

        RewardToken rewardToken = new RewardToken(INITIAL_SUPPLY);
        console.log("RewardToken deployed at:", address(rewardToken));

        // Deploy staking pool
        StakingPool stakingPool = new StakingPool(
            address(stakeToken),
            address(rewardToken),
            MIN_STAKE_AMOUNT
        );
        console.log("StakingPool deployed at:", address(stakingPool));

        // Setup: Distribute tokens to test users
        stakeToken.transfer(USER1, 50_000 * 1e18);
        stakeToken.transfer(USER2, 50_000 * 1e18);
        console.log("Distributed stake tokens to test users");

        // Setup: Fund staking pool with rewards
        rewardToken.approve(address(stakingPool), REWARD_AMOUNT);
        stakingPool.notifyRewardAmount(REWARD_AMOUNT, REWARD_DURATION);
        console.log("Funded staking pool with", REWARD_AMOUNT, "rewards");

        vm.stopBroadcast();

        // Log deployment summary
        console.log("\n=== Local Deployment Summary ===");
        console.log("StakeToken:", address(stakeToken));
        console.log("RewardToken:", address(rewardToken));
        console.log("StakingPool:", address(stakingPool));
        console.log("\n=== Configuration ===");
        console.log("Min Stake Amount:", MIN_STAKE_AMOUNT);
        console.log("Reward Amount:", REWARD_AMOUNT);
        console.log("Reward Duration:", REWARD_DURATION);
        console.log("\n=== Test Accounts ===");
        console.log("Deployer:", DEPLOYER);
        console.log("User1:", USER1, "- Balance:", 50_000 * 1e18);
        console.log("User2:", USER2, "- Balance:", 50_000 * 1e18);
        console.log("\n=== Next Steps ===");
        console.log("1. Users can approve StakingPool to spend their tokens:");
        console.log("   cast send <STAKE_TOKEN> 'approve(address,uint256)' <STAKING_POOL> <AMOUNT> --from <USER>");
        console.log("2. Users can stake tokens:");
        console.log("   cast send <STAKING_POOL> 'stake(uint256)' <AMOUNT> --from <USER>");
        console.log("3. After some time, users can claim rewards:");
        console.log("   cast send <STAKING_POOL> 'claimRewards()' --from <USER>");
    }
}
