// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/openzeppelin-contracts/contracts/access/Ownable.sol";

contract Vault is Ownable {
    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    error AmountMustBeMoreThatZero();
    error InvalidLockPeriod();
    error TransferFailed();
    error CantWithdrawUntilLockPeriodIsOver();
    error InvalidAmount();
    error AlreadyWitdrawn();

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
    }

    function withdraw(uint256 index) external {
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
}
