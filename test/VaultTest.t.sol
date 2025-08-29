// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Vault} from "../src/Vault.sol";
import {DeployVault} from "../script/DeployVault.s.sol";

contract VaultTest is Test {
    Vault vault;
    DeployVault deployer;

    function setUp() external {
        deployer = new DeployVault();
        vault = deployer.run();
    }
}
