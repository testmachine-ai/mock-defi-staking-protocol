# DeFi Staking Protocol

Stake ERC20 tokens to earn time-based rewards. Built with Foundry and Solidity.

## Features

- Stake/unstake tokens
- Time-based reward distribution
- Multi-role access control (Admin, Operator, Pauser)
- Pausable for emergencies
- Reentrancy protection

## Setup

```bash
forge install
forge build
forge test
```

## Deploy

```bash
# Local (Anvil)
anvil
forge script script/Deploy.s.sol:DeployLocalScript --rpc-url http://localhost:8545 --broadcast

# Testnet/Mainnet
forge script script/Deploy.s.sol:DeployScript --rpc-url $RPC_URL --broadcast --verify
```

## Test Results

30/30 tests passing

## License

MIT
