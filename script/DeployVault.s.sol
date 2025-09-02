// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {Vault} from "../src/Vault.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployVault is Script {
    function run() external returns (Vault, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfig();
        vm.startBroadcast();
        Vault vault = new Vault(networkConfig.keeperRegistry, networkConfig.checkInterval);
        vm.stopBroadcast();
        return (vault, helperConfig);
    }
}
