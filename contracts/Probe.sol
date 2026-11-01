// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
contract Probe {
    uint256 public value;
    event Set(uint256 v);
    function set(uint256 v) external { value = v; emit Set(v); }
}
