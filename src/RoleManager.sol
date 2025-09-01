// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/openzeppelin-contracts/contracts/access/AccessControl.sol";

contract RoleManager is AccessControl {
    struct TimedRole {
        bool active;
        uint256 lastActive;
        uint256 expiry;
    }

    mapping(address => TimedRole) public tempRoles;
    address[] public allTempBigFanUsers;
    mapping(address => bool) private isInTempBigFanList;

    bytes32 public constant LONG_TERM_WHALE = keccak256("LONG_TERM_WHALE");
    bytes32 public constant FREQUENT_WHALE = keccak256("FREQUENT_WHALE");
    bytes32 public constant BIG_DEPOSITOR = keccak256("BIG_DEPOSITOR");

    bytes32 public constant TEMP_BIG_FAN = keccak256("TEMP_BIG_FAN");

    uint256 private constant SIX_MONTHS = 180 days;
    uint256 private constant ONE_YEAR = 365 days;
    uint256 private constant FIVE_YEARS = 5 * 365 days;
    uint256 private constant TEMP_ROLE_EXPIRY = 8 days;

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function _checkAndGrantRole(uint256 amount, uint256 lockPeriod, uint256 timesDeposited) internal {
        if (amount >= 1 ether && lockPeriod == FIVE_YEARS) {
            _grantRole(LONG_TERM_WHALE, msg.sender);
        } else if (amount >= 1 ether && timesDeposited >= 3) {
            _grantRole(FREQUENT_WHALE, msg.sender);
        } else if (amount >= 5 ether) {
            _grantRole(BIG_DEPOSITOR, msg.sender);
        } else if (amount > 0.001 ether) {
            __grantRole(TEMP_BIG_FAN, msg.sender);
            tempRoles[msg.sender] =
                TimedRole({active: true, lastActive: block.timestamp, expiry: block.timestamp + TEMP_ROLE_EXPIRY});

            if (!isInTempBigFanList[msg.sender]) {
                allTempBigFanUsers.push(msg.sender);
                isInTempBigFanList[msg.sender] = true;
            }
        }
    }

    function _updateTempRole(address user) internal {
        if (hasRole(TEMP_BIG_FAN, user) && tempRoles[user].active) {
            tempRoles[user].lastActive = block.timestamp;
            tempRoles[user].expiry = block.timestamp + 8 days;
        }
    }
}
