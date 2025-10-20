// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title StakeToken
 * @notice Mock ERC20 token for staking purposes
 * @dev Simple mintable token for testing the staking protocol
 */
contract StakeToken is ERC20, Ownable {
    /**
     * @notice Constructor that mints initial supply to deployer
     * @param initialSupply The initial token supply
     */
    constructor(uint256 initialSupply) ERC20("Stake Token", "STAKE") Ownable(msg.sender) {
        _mint(msg.sender, initialSupply);
    }

    /**
     * @notice Mint new tokens
     * @param to Address to receive minted tokens
     * @param amount Amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /**
     * @notice Burn tokens from caller
     * @param amount Amount of tokens to burn
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}
