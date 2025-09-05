// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/openzeppelin-contracts/contracts/access/AccessControl.sol";

/**
 * @title RoleManager
 * @notice Manages user roles, including permanent roles (LONG_TERM_WHALE, FREQUENT_WHALE, BIG_DEPOSITOR)
 *         and temporary role (TEMP_BIG_FAN) based on deposit activity.
 * @dev Uses OpenZeppelin's AccessControl for role management.
 */
contract RoleManager is AccessControl {
    /**
     * @notice Represents a temporary role for a user
     * @param active Indicates if the role is currently active
     * @param lastActive Timestamp of the user's last activity
     * @param expiry Timestamp when the temporary role expires
     */
    struct TimedRole {
        bool active;
        uint256 lastActive;
        uint256 expiry;
    }

    /// @notice Mapping from user address to their temporary role
    mapping(address => TimedRole) public tempRoles;
    address[] public allTempBigFanUsers;

    /// @notice Permanent role identifiers
    bytes32 public constant LONG_TERM_WHALE = keccak256("LONG_TERM_WHALE");
    bytes32 public constant FREQUENT_WHALE = keccak256("FREQUENT_WHALE");
    bytes32 public constant BIG_DEPOSITOR = keccak256("BIG_DEPOSITOR");

    /// @notice Temporary role identifier
    bytes32 public constant TEMP_BIG_FAN = keccak256("TEMP_BIG_FAN");

    /// @notice Time periods in seconds
    uint256 private constant SIX_MONTHS = 180 days;
    uint256 private constant ONE_YEAR = 365 days;
    uint256 private constant FIVE_YEARS = 5 * 365 days;

    /// @notice Duration for temporary role expiry
    uint256 private constant TEMP_ROLE_EXPIRY = 8 days;

    /**
     * @notice Constructor grants the deployer the default admin role
     */
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @notice Grants appropriate role based on deposit amount, lock period, and number of deposits
     * @param amount Deposit amount in wei
     * @param lockPeriod Lock period in seconds
     * @param timesDeposited Number of times the user has deposited
     * @dev If a user qualifies for TEMP_BIG_FAN, sets up a TimedRole struct for tracking
     */
    function _checkAndGrantRole(uint256 amount, uint256 lockPeriod, uint256 timesDeposited) internal {
        if (amount >= 1 ether && lockPeriod == FIVE_YEARS) {
            _grantRole(LONG_TERM_WHALE, msg.sender);
        } else if (amount >= 1 ether && timesDeposited >= 3) {
            _grantRole(FREQUENT_WHALE, msg.sender);
        } else if (amount >= 5 ether) {
            _grantRole(BIG_DEPOSITOR, msg.sender);
        } else if (amount > 0.001 ether) {
            _grantRole(TEMP_BIG_FAN, msg.sender);
            tempRoles[msg.sender] =
                TimedRole({active: true, lastActive: block.timestamp, expiry: block.timestamp + TEMP_ROLE_EXPIRY});
        }
    }

    /**
     * @notice Updates a user's temporary role timestamps to extend its expiry
     * @param user Address of the user
     * @dev Only updates if the user currently has the TEMP_BIG_FAN role and it is active
     */
    function _updateTempRole(address user) internal {
        if (hasRole(TEMP_BIG_FAN, user) && tempRoles[user].active) {
            tempRoles[user].lastActive = block.timestamp;
            tempRoles[user].expiry = block.timestamp + TEMP_ROLE_EXPIRY;
            allTempBigFanUsers.push(user);
        }
    }
}
