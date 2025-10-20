# Project Context: DeFi Staking Protocol

## Project Overview
Mock DeFi staking protocol built with Foundry. Users stake ERC20 tokens to earn time-based rewards.

## Tech Stack
- Solidity 0.8.20
- Foundry (forge, anvil)
- OpenZeppelin Contracts

## Project Structure
```
src/
├── StakingPool.sol              # Main staking contract (330 lines)
├── mocks/
    ├── StakeToken.sol           # Mock ERC20 for staking
    └── RewardToken.sol          # Mock ERC20 for rewards
test/
└── StakingPool.t.sol            # 30 tests (all passing)
script/
└── Deploy.s.sol                 # Deployment scripts (local + production)
```

## Core Contracts

### StakingPool.sol
- **Roles**: DEFAULT_ADMIN_ROLE, OPERATOR_ROLE, PAUSER_ROLE
- **Key Functions**: stake(), unstake(), claimRewards(), exit()
- **Operator Functions**: notifyRewardAmount(), setMinStakeAmount(), recoverERC20()
- **Admin Functions**: emergencyWithdraw(), grantRole(), revokeRole()
- **Security**: ReentrancyGuard, Pausable, SafeERC20, AccessControl
- **Reward Model**: Time-based, proportional to stake, calculated via rewardPerToken()

### Internal Architecture
- Uses internal `_unstake()` and `_claimRewards()` functions to avoid reentrancy issues in `exit()`
- `updateReward(address)` modifier updates rewards before state changes
- Immutable tokens: `stakingToken`, `rewardToken`

## Key Parameters
- `minStakeAmount`: Minimum stake required (default: 100e18)
- `rewardRate`: Tokens per second
- `periodFinish`: End of reward period
- `rewardPerTokenStored`: Accumulated rewards per token

## Build Commands
```bash
forge build
forge test
forge test --gas-report
forge test -vvv  # verbose
```

## Deploy Commands
```bash
# Local
anvil
forge script script/Deploy.s.sol:DeployLocalScript --rpc-url http://localhost:8545 --broadcast

# Production
forge script script/Deploy.s.sol:DeployScript --rpc-url $RPC_URL --broadcast --verify
```

## Test Coverage
- 30/30 tests passing
- Basic functionality (stake, unstake, claim, exit)
- Access control (all roles)
- Edge cases (zero amounts, insufficient balance)
- Security (reentrancy, pause)
- Multi-user rewards
- Fuzz tests

## Known Warnings (Non-Critical)
- Linter suggests SCREAMING_SNAKE_CASE for immutables (stakingToken, rewardToken)
- Linter suggests wrapping modifier logic for gas optimization
- Unchecked transfer warnings in test files (acceptable for tests)

## Design Decisions
- Chose staking protocol over full lending protocol for simplicity
- Multi-role RBAC for production-ready access control
- Internal functions to handle exit() without reentrancy issues
- Custom errors for gas efficiency
- Time-based rewards (not block-based) for cross-chain compatibility

## Next Steps (Future Enhancements)
- Add stable rate borrowing
- Implement flash loans
- Add LP token functionality
- Multi-asset support
- Governance token integration
