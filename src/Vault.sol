// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title Vault contract with role management and Chainlink Keepers integration
 * @author Anastasia Tymchak
 * @notice Allows users to deposit and withdraw Ether with lock periods, manages user roles based on deposits, and integrates with Chainlink Keepers for automated role expiration.
 * @dev Inherits from RoleManager, Ownable, and Chainlink's AutomationCompatibleInterface.
 */
import {Ownable} from "@openzeppelin/openzeppelin-contracts/contracts/access/Ownable.sol";
import {AutomationCompatibleInterface} from
    "@smartcontractkit/chainlink-evm/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol"; // Keeper interface
import {RoleManager} from "./RoleManager.sol";

contract Vault is RoleManager, Ownable, AutomationCompatibleInterface {
    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/
    /// @notice Thrown if the deposit amount is zero.
    error AmountMustBeMoreThatZero();
    /// @notice Thrown if an invalid lock period is provided.
    error InvalidLockPeriod();
    /// @notice Thrown if ETH transfer fails.
    error TransferFailed();
    /// @notice Thrown if withdrawal attempted before lock period expires.
    error CantWithdrawUntilLockPeriodIsOver();
    /// @notice Thrown if the withdrawal amount is invalid.
    error InvalidAmount();
    /// @notice Thrown if a deposit was already withdrawn.
    error AlreadyWitdrawn();
    /// @notice Thrown if a deposit index is invalid.
    error InvalidIndex();
    /// @notice Thrown if an address is the zero address.
    error InvalidAddress();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Enum representing the state of a deposit.
     * LOCKED: Deposit cannot be withdrawn.
     * UNLOCKED: Deposit is eligible for withdrawal.
     */
    enum DepositState {
        LOCKED,
        UNLOCKED
    }
    /**
     * @dev Struct representing a user's deposit.
     * @param amount Amount of Ether deposited.
     * @param timestamp Block timestamp when deposited.
     * @param lockUntil Timestamp until which funds are locked.
     * @param state Current state of the deposit.
     * @param withdrawn Whether the deposit has been withdrawn.
     */

    struct UserDeposit {
        uint256 amount;
        uint256 timestamp;
        uint256 lockUntil;
        DepositState state;
        bool withdrawn;
    }
    /// @notice Address of the Chainlink Keeper Registry.

    address private immutable s_keeperRegistry;
    /// @notice Interval (in seconds) at which keepers should check for expired roles.
    uint256 private immutable s_checkInterval;
    /// @notice Total value locked in the contract across all users.
    uint256 private totalValueLocked;
    /// @notice Maximum number of users for batch operations (in checkUpkeep).
    uint256 private constant MAX_USERS = 100;
    /// @notice Mapping from user address to array of their deposits.
    mapping(address => UserDeposit[]) private s_userDeposits;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Emitted when a user makes a deposit.
     * @param user The address of the user.
     * @param amount The amount deposited.
     * @param lockUntil The timestamp until which the deposit is locked.
     */
    event Deposit(address indexed user, uint256 indexed amount, uint256 indexed lockUntil);

    /**
     * @notice Emitted when a user withdraws a deposit.
     * @param user The address of the user.
     * @param amount The amount withdrawn.
     * @param timestamp The block timestamp of withdrawal.
     */
    event Withdraw(address indexed user, uint256 indexed amount, uint256 timestamp);

    /*//////////////////////////////////////////////////////////////*/
    /**
     * @notice Initializes the Vault contract.
     * @param keeperRegistry Address of the Chainlink Keeper Registry.
     * @param checkInterval Interval in seconds for keeper checks.
     */
    constructor(address keeperRegistry, uint256 checkInterval) Ownable(msg.sender) notZeroAddress(keeperRegistry) {
        s_keeperRegistry = keeperRegistry;
        s_checkInterval = checkInterval;
    }

    /**
     * @dev Allows the contract to receive Ether directly.
     */
    receive() external payable {}

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Ensures the amount is greater than zero.
     * @param amount The amount to check.
     */
    modifier moreThanZero(uint256 amount) {
        if (amount <= 0) {
            revert AmountMustBeMoreThatZero();
        }
        _;
    }

    modifier notZeroAddress(address addr) {
        if (addr == address(0)) revert InvalidAddress();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            MAIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Allows a user to deposit Ether with a lock period.
     * @dev Only accepts lock periods of 180 days, 365 days, or 5*365 days.
     *      Grants user roles based on deposit.
     * @param lockPeriod The lock period in seconds.
     */
    function deposit(uint256 lockPeriod) external payable moreThanZero(msg.value) {
        uint256 sixMonths = 180 days;
        uint256 oneYear = 365 days;
        uint256 fiveYears = 5 * 365 days;

        // Checks
        if (lockPeriod != sixMonths && lockPeriod != oneYear && lockPeriod != fiveYears) {
            revert InvalidLockPeriod();
        }

        // Effects
        UserDeposit memory newDeposit = UserDeposit({
            amount: msg.value,
            timestamp: block.timestamp,
            lockUntil: block.timestamp + lockPeriod,
            state: DepositState.LOCKED,
            withdrawn: false
        });
        totalValueLocked += msg.value;

        s_userDeposits[msg.sender].push(newDeposit);

        _checkAndGrantRole(msg.value, lockPeriod, s_userDeposits[msg.sender].length);
        _updateTempRole(msg.sender);

        emit Deposit(msg.sender, msg.value, newDeposit.lockUntil);
    }

    /**
     * @notice Allows a user to withdraw a deposit after the lock period.
     * @param index The index of the deposit to withdraw.
     */
    function withdraw(uint256 index) external {
        if (index >= s_userDeposits[msg.sender].length) {
            revert InvalidIndex();
        }

        UserDeposit storage dep = s_userDeposits[msg.sender][index];
        uint256 amountToSend = dep.amount;
        _updateDepositState(dep);
        if (dep.state == DepositState.LOCKED) {
            revert CantWithdrawUntilLockPeriodIsOver();
        }

        if (dep.withdrawn == true) {
            revert AlreadyWitdrawn();
        }

        dep.amount = 0;
        dep.timestamp = 0;
        dep.lockUntil = 0;
        dep.state = DepositState.UNLOCKED;
        dep.withdrawn = true;
        totalValueLocked -= amountToSend;

        _updateTempRole(msg.sender);

        emit Withdraw(msg.sender, amountToSend, block.timestamp);

        (bool success,) = msg.sender.call{value: amountToSend}("");
        if (!success) {
            revert TransferFailed();
        }
    }

    /**
     * @notice Chainlink Keeper interface: checks if any users have expired temporary roles.
     * @dev Returns a list of users whose temporary roles have expired.
     * @return upkeepNeeded True if there are expired roles, false otherwise.
     * @return performData Encoded list of expired user addresses and count.
     */
    function checkUpkeep(bytes calldata /*checkData*/ )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        address[] memory expiredUsers = new address[](MAX_USERS);
        uint256 count = 0;

        for (uint256 i = 0; i < allTempBigFanUsers.length; i++) {
            // Note: Using block.timestamp is acceptable here, as ±15s drift does
            // not impact role expiry logic.
            address user = allTempBigFanUsers[i];
            if (block.timestamp > tempRoles[user].lastActive + tempRoles[user].expiry) {
                expiredUsers[count] = user;
                count++;
            }
        }

        upkeepNeeded = (count > 0);

        performData = abi.encode(expiredUsers, count);
    }

    /**
     * @notice Chainlink Keeper interface: revokes expired temporary roles.
     * @dev Called by Chainlink Keepers; decodes performData to revoke roles.
     * @param performData Encoded addresses and count of expired users.
     */
    function performUpkeep(bytes calldata performData) external override {
        (address[] memory expiredUsers, uint256 count) = abi.decode(performData, (address[], uint256));
        for (uint256 i = 0; i < count; i++) {
            address user = expiredUsers[i];
            tempRoles[user].active = false;
            _revokeRole(TEMP_BIG_FAN, user);
        }
    }

    /**
     * @dev Internal function to update deposit state from LOCKED to UNLOCKED if lock period expired.
     * @param dep Reference to the user's deposit struct.
     */
    function _updateDepositState(UserDeposit storage dep) internal {
        if (dep.state == DepositState.LOCKED && block.timestamp >= dep.lockUntil) {
            dep.state = DepositState.UNLOCKED;
        }
    }

    /*//////////////////////////////////////////////////////////////
                            GETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the total value locked in the contract.
     * @return Total value locked.
     */
    function getTotalValueLocked() external view returns (uint256) {
        return totalValueLocked;
    }

    /**
     * @notice Returns all deposits for a given user.
     * @param user The address of the user.
     * @return Array of UserDeposit structs.
     */
    function getUserDeposits(address user) external view returns (UserDeposit[] memory) {
        return s_userDeposits[user];
    }

    /**
     * @notice Returns a single deposit for a user by index.
     * @param user The address of the user.
     * @param index The index of the deposit.
     * @return The UserDeposit struct.
     */
    function getDepositByIndex(address user, uint256 index) external view returns (UserDeposit memory) {
        return s_userDeposits[user][index];
    }

    /**
     * @notice Returns the total amount ever deposited by a user (including withdrawn).
     * @param user The address of the user.
     * @return total The total amount deposited.
     */
    function getTotalAmountUserDepostied(address user) external view returns (uint256 total) {
        UserDeposit[] memory deposits = s_userDeposits[user];
        for (uint256 i = 0; i < deposits.length; i++) {
            total += deposits[i].amount;
        }
    }

    /**
     * @notice Returns the total value of a user's active (locked and not withdrawn) deposits.
     * @param user The address of the user.
     * @return total The total amount in active deposits.
     */
    function getTotalAmountOfActiveDeposits(address user) external view returns (uint256 total) {
        UserDeposit[] memory deposits = s_userDeposits[user];
        for (uint256 i = 0; i < deposits.length; i++) {
            if (deposits[i].state == DepositState.LOCKED && deposits[i].withdrawn == false) {
                total += deposits[i].amount;
            }
        }
    }

    /**
     * @notice Returns the address of the Keeper Registry.
     * @return Keeper registry address.
     */
    function getKeeperRegistry() external view returns (address) {
        return s_keeperRegistry;
    }

    /**
     * @notice Returns the interval for keeper checks.
     * @return Check interval in seconds.
     */
    function getCheckInterval() external view returns (uint256) {
        return s_checkInterval;
    }
}
