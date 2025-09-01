// Config.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract Config {
    struct NetworkConfig {
        address keeperRegistry;
        uint256 checkInterval;
    }

    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;

    mapping(uint256 => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getSepoliaEthConfig();
        networkConfigs[LOCAL_CHAIN_ID] = getOrCreateAnvilNetworkConfig();
    }
}
