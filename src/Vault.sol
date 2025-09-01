// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/openzeppelin-contracts/contracts/access/Ownable.sol";
import {AutomationCompatibleInterface} from
    "@smartcontractkit/chainlink-evm/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol"; // Keeper interface
import {RoleManager} from "./RoleManager.sol";

contract Vault is RoleManager, Ownable, AutomationCompatibleInterface {
    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    error AmountMustBeMoreThatZero();
    error InvalidLockPeriod();
    error TransferFailed();
    error CantWithdrawUntilLockPeriodIsOver();
    error InvalidAmount();
    error AlreadyWitdrawn();
    error InvalidIndex();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    enum DepositState {
        LOCKED,
        UNLOCKED
    }

    struct UserDeposit {
        uint256 amount;
        uint256 timestamp;
        uint256 lockUntil;
        DepositState state;
        bool withdrawn;
    }

    uint256 private totalValueLocked;
    uint256 private constant MAX_USERS = 100;
    mapping(address => UserDeposit[]) private s_userDeposits;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event Deposit(address indexed user, uint256 indexed amount, uint256 indexed lockUntil);
    event Withdraw(address indexed user, uint256 indexed amount, uint256 timestamp);

    /*//////////////////////////////////////////////////////////////*/

    constructor() Ownable(msg.sender) {}

    receive() external payable {}

    modifier moreThanZero(uint256 amount) {
        require(amount > 0, AmountMustBeMoreThatZero());
        _;
    }
    /*//////////////////////////////////////////////////////////////
                            MAIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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
        emit Deposit(msg.sender, msg.value, newDeposit.lockUntil);

        _checkAndGrantRole(msg.value, lockPeriod, s_userDeposits[msg.sender].length);
        _updateTempRole(msg.sender);
    }

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

        (bool success,) = msg.sender.call{value: amountToSend}("");
        require(success, TransferFailed());

        emit Withdraw(msg.sender, amountToSend, block.timestamp);
        _updateTempRole(msg.sender);
    }

    function checkUpkeep(bytes calldata /*checkData*/ )
        external
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        address[] memory expiredUsers = new address[](MAX_USERS);
        uint256 count = 0;

        for (uint256 i = 0; i < allTempBigFanUsers.length; i++) {
            address user = allTempBigFanUsers[i];
            if (block.timestamp > tempRoles[user].lastActive + tempRoles[user].expiry) {
                expiredUsers[count] = user;
                count++;
            }
        }

        upkeepNeeded = (count > 0);
        performData = abi.encode(expiredUsers, count);
    }

    function performUpkeep(bytes calldata performData) external override {
        (address[] memory expiredUsers, uint256 count) = abi.decode(performData, (address[], uint256));
        for (uint256 i = 0; i < count; i++) {
            address user = expiredUsers[i];
            tempRoles[user].active = false;
            _revokeRole(TEMP_BIG_FAN, user);
        }
    }

    function _updateDepositState(UserDeposit storage dep) internal {
        if (dep.state == DepositState.LOCKED && block.timestamp >= dep.lockUntil) {
            dep.state = DepositState.UNLOCKED;
        }
    }

    /*//////////////////////////////////////////////////////////////
                            GETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getTotalValueLocked() external view returns (uint256) {
        return totalValueLocked;
    }

    function getUserDeposits(address user) external view returns (UserDeposit[] memory) {
        return s_userDeposits[user];
    }

    function getDepositByIndex(address user, uint256 index) external view returns (UserDeposit memory) {
        return s_userDeposits[user][index];
    }

    function getTotalAmountUserDepostied(address user) external view returns (uint256 total) {
        UserDeposit[] memory deposits = s_userDeposits[user];
        for (uint256 i = 0; i < deposits.length; i++) {
            total += deposits[i].amount;
        }
    }

    function getTotalAmountOfActiveDeposits(address user) external view returns (uint256 total) {
        UserDeposit[] memory deposits = s_userDeposits[user];
        for (uint256 i = 0; i < deposits.length; i++) {
            if (deposits[i].state == DepositState.LOCKED && deposits[i].withdrawn == false) {
                total += deposits[i].amount;
            }
        }
    }
}
