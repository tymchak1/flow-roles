// Config.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";

contract HelperConfig is Script {
    error HelperConfig__InvalidChainId();

    struct NetworkConfig {
        address keeperRegistry;
        uint256 checkInterval;
    }

    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;

    uint256 public constant INTERVAL = 6 hours;

    mapping(uint256 => NetworkConfig) public networkConfigs;
    NetworkConfig public localNetworkConfig;

    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getSepoliaEthConfig();
        networkConfigs[LOCAL_CHAIN_ID] = getOrCreateAnvilNetworkConfig();
    }

    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (networkConfigs[chainId].keeperRegistry != address(0)) {
            return networkConfigs[chainId];
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilNetworkConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({keeperRegistry: 0x86EFBD0b6736Bed994962f9797049422A3A8E8Ad, checkInterval: INTERVAL});
    }

    function getOrCreateAnvilNetworkConfig() public returns (NetworkConfig memory) {
        if (localNetworkConfig.keeperRegistry != address(0)) {
            return localNetworkConfig;
        }
        vm.startBroadcast();
        localNetworkConfig = NetworkConfig({keeperRegistry: address(0), checkInterval: INTERVAL});
        vm.stopBroadcast();
        return localNetworkConfig;
    }
}
