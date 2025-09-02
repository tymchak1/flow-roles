// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Vault} from "../src/Vault.sol";
import {DeployVault} from "../script/DeployVault.s.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";

contract VaultTest is Test {
    Vault vault;
    DeployVault deployer;
    HelperConfig helperConfig;
    address USER = makeAddr("user");
    uint256 SIX_MONTHS = 180 days;
    uint256 ONE_YEAR = 365 days;
    uint256 FIVE_YEARS = 5 * 365 days;
    uint256 DEPOSIT_AMOUNT = 1 ether;
    uint256 WITHDRAW_AMOUNT = 1 ether;

    address keeperRegistry;
    uint256 checkInterval;

    event Deposit(address indexed user, uint256 indexed amount, uint256 indexed lockUntil);
    event Withdraw(address indexed user, uint256 indexed amount, uint256 timestamp);

    function setUp() external {
        deployer = new DeployVault();
        (vault, helperConfig) = deployer.run();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        keeperRegistry = config.keeperRegistry;
        checkInterval = config.checkInterval;
        vm.deal(USER, 10 ether);
    }

    function test_InitialState() public view {
        assertEq(vault.getTotalValueLocked(), 0);
        assertEq(vault.getUserDeposits(address(this)).length, 0);
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ConstructorSetsOwner() public view {
        assert(vault.owner() != address(0));
    }

    function test_ConstructorSetsParametersCorrectly() public view {
        assertEq(vault.getKeeperRegistry(), keeperRegistry);
        assertEq(vault.getCheckInterval(), checkInterval);
    }

    /*//////////////////////////////////////////////////////////////
                            DEPOSIT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RevertIf_DepositAmountIsZero() public {
        vm.prank(USER);
        vm.expectRevert(Vault.AmountMustBeMoreThatZero.selector);
        vault.deposit{value: 0}(SIX_MONTHS);
    }

    function test_RevertIf_InvalidLockPeriod_TooShort() public {
        vm.prank(USER);
        vm.expectRevert(Vault.InvalidLockPeriod.selector);
        vault.deposit{value: DEPOSIT_AMOUNT}(30 days);
    }

    function test_RevertIf_InvalidLockPeriod_TooLong() public {
        vm.prank(USER);
        vm.expectRevert(Vault.InvalidLockPeriod.selector);
        vault.deposit{value: DEPOSIT_AMOUNT}(10 * 365 days);
    }

    function test_RevertIf_InvalidLockPeriod_NotExactPeriod() public {
        vm.startPrank(USER);

        vm.expectRevert(Vault.InvalidLockPeriod.selector);
        vault.deposit{value: DEPOSIT_AMOUNT}(179 days);

        vm.expectRevert(Vault.InvalidLockPeriod.selector);
        vault.deposit{value: DEPOSIT_AMOUNT}(181 days);

        vm.expectRevert(Vault.InvalidLockPeriod.selector);
        vault.deposit{value: DEPOSIT_AMOUNT}(364 days);

        vm.expectRevert(Vault.InvalidLockPeriod.selector);
        vault.deposit{value: DEPOSIT_AMOUNT}(366 days);

        vm.expectRevert(Vault.InvalidLockPeriod.selector);
        vault.deposit{value: DEPOSIT_AMOUNT}(200 days);

        vm.stopPrank();
    }

    function test_Deposit_SixMonthsPeriod() public {
        vm.prank(USER);

        vm.expectEmit(true, true, false, true);
        emit Deposit(USER, DEPOSIT_AMOUNT, block.timestamp + SIX_MONTHS);

        vault.deposit{value: DEPOSIT_AMOUNT}(SIX_MONTHS);

        Vault.UserDeposit[] memory deposits = vault.getUserDeposits(USER);
        assertEq(deposits.length, 1);
        assertEq(deposits[0].amount, DEPOSIT_AMOUNT);
        assertEq(deposits[0].timestamp, block.timestamp);
        assertEq(deposits[0].lockUntil, block.timestamp + SIX_MONTHS);
        assertEq(uint256(deposits[0].state), uint256(Vault.DepositState.LOCKED));
        assertEq(deposits[0].withdrawn, false);

        assertEq(vault.getTotalValueLocked(), DEPOSIT_AMOUNT);
    }

    function test_Deposit_OneYearPeriod() public {
        vm.prank(USER);

        vm.expectEmit(true, true, false, true);
        emit Deposit(USER, DEPOSIT_AMOUNT, block.timestamp + ONE_YEAR);

        vault.deposit{value: DEPOSIT_AMOUNT}(ONE_YEAR);

        Vault.UserDeposit memory deposit = vault.getDepositByIndex(USER, 0);
        assertEq(deposit.amount, DEPOSIT_AMOUNT);
        assertEq(deposit.timestamp, block.timestamp);
        assertEq(deposit.lockUntil, block.timestamp + ONE_YEAR);
        assertEq(uint256(deposit.state), uint256(Vault.DepositState.LOCKED));
        assertEq(deposit.withdrawn, false);

        assertEq(vault.getTotalValueLocked(), DEPOSIT_AMOUNT);
    }

    function test_Deposit_FiveYearsPeriod() public {
        // Перевірка, що користувач ще не має ролі LONG_TERM_WHALE
        assertFalse(vault.hasRole(vault.LONG_TERM_WHALE(), USER));

        vm.prank(USER);

        vm.expectEmit(true, true, false, true);
        emit Deposit(USER, DEPOSIT_AMOUNT, block.timestamp + FIVE_YEARS);

        vault.deposit{value: DEPOSIT_AMOUNT}(FIVE_YEARS);

        assertTrue(vault.hasRole(vault.LONG_TERM_WHALE(), USER));

        Vault.UserDeposit memory deposit = vault.getDepositByIndex(USER, 0);
        assertEq(deposit.amount, DEPOSIT_AMOUNT);
        assertEq(deposit.lockUntil, block.timestamp + FIVE_YEARS);

        assertEq(vault.getTotalValueLocked(), DEPOSIT_AMOUNT);
    }

    function test_MultipleDepositsFromSameUser() public {
        vm.startPrank(USER);

        vm.expectEmit(true, true, false, true);
        emit Deposit(USER, DEPOSIT_AMOUNT, block.timestamp + SIX_MONTHS);
        vault.deposit{value: DEPOSIT_AMOUNT}(SIX_MONTHS);

        vm.expectEmit(true, true, false, true);

        emit Deposit(USER, DEPOSIT_AMOUNT * 2, block.timestamp + ONE_YEAR);
        vault.deposit{value: DEPOSIT_AMOUNT * 2}(ONE_YEAR);

        vm.expectEmit(true, true, false, true);

        emit Deposit(USER, DEPOSIT_AMOUNT * 3, block.timestamp + FIVE_YEARS);
        vault.deposit{value: DEPOSIT_AMOUNT * 3}(FIVE_YEARS);

        vm.stopPrank();

        Vault.UserDeposit[] memory deposits = vault.getUserDeposits(USER);
        assertEq(deposits.length, 3);

        assertEq(deposits[0].amount, DEPOSIT_AMOUNT);
        assertEq(deposits[0].lockUntil, block.timestamp + SIX_MONTHS);

        assertEq(deposits[1].amount, DEPOSIT_AMOUNT * 2);
        assertEq(deposits[1].lockUntil, block.timestamp + ONE_YEAR);

        assertEq(deposits[2].amount, DEPOSIT_AMOUNT * 3);
        assertEq(deposits[2].lockUntil, block.timestamp + FIVE_YEARS);

        assertEq(vault.getTotalValueLocked(), DEPOSIT_AMOUNT * 6);
    }

    function test_DepositFromMultipleUsers() public {
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");
        address user3 = makeAddr("user3");

        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);

        vm.prank(user1);
        vm.expectEmit(true, true, false, true);

        emit Deposit(user1, DEPOSIT_AMOUNT, block.timestamp + SIX_MONTHS);
        vault.deposit{value: DEPOSIT_AMOUNT}(SIX_MONTHS);

        vm.prank(user2);
        vm.expectEmit(true, true, false, true);
        emit Deposit(user2, DEPOSIT_AMOUNT * 2, block.timestamp + ONE_YEAR);
        vault.deposit{value: DEPOSIT_AMOUNT * 2}(ONE_YEAR);

        vm.prank(user3);
        vm.expectEmit(true, true, false, true);
        emit Deposit(user3, DEPOSIT_AMOUNT * 3, block.timestamp + FIVE_YEARS);
        vault.deposit{value: DEPOSIT_AMOUNT * 3}(FIVE_YEARS);

        assertEq(vault.getTotalValueLocked(), DEPOSIT_AMOUNT * 6);

        assertEq(vault.getUserDeposits(user1).length, 1);
        assertEq(vault.getUserDeposits(user2).length, 1);
        assertEq(vault.getUserDeposits(user3).length, 1);
    }

    function test_DepositWithMinimumAmount() public {
        vm.prank(USER);

        vm.expectEmit(true, true, false, true);
        emit Deposit(USER, 1 wei, block.timestamp + SIX_MONTHS);

        vault.deposit{value: 1 wei}(SIX_MONTHS);

        assertEq(vault.getTotalValueLocked(), 1 wei);

        Vault.UserDeposit memory deposit = vault.getDepositByIndex(USER, 0);
        assertEq(deposit.amount, 1 wei);
    }

    /*//////////////////////////////////////////////////////////////
                             WITHDRAW TESTS
    //////////////////////////////////////////////////////////////*/

    function testGrantLongTermWhaleRole() public {
        uint256 fiveYears = 5 * 365 days;

        vm.startPrank(USER);
        vault.deposit{value: 1 ether}(fiveYears);
        vm.stopPrank();

        assertTrue(vault.hasRole(vault.LONG_TERM_WHALE(), USER));
    }

    function testGrantFrequentWhaleRole() public {
        uint256 oneYear = 365 days;

        vm.startPrank(USER);
        vault.deposit{value: 1 ether}(oneYear);
        vault.deposit{value: 1 ether}(oneYear);
        vault.deposit{value: 1 ether}(oneYear);
        vm.stopPrank();

        assertTrue(vault.hasRole(vault.FREQUENT_WHALE(), USER));
    }

    function testGrantBigDepositorRole() public {
        uint256 oneYear = 365 days;

        vm.startPrank(USER);
        vault.deposit{value: 5 ether}(oneYear);
        vm.stopPrank();

        assertTrue(vault.hasRole(vault.BIG_DEPOSITOR(), USER));
    }

    /*//////////////////////////////////////////////////////////////

                             WITHDRAW TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RevertIf_WithdrawBeforeLockPeriodEnds() public {
        vm.prank(USER);
        vault.deposit{value: DEPOSIT_AMOUNT}(SIX_MONTHS);

        vm.prank(USER);
        vm.expectRevert(Vault.CantWithdrawUntilLockPeriodIsOver.selector);
        vault.withdraw(0);
    }

    function test_RevertIf_WithdrawAlreadyWithdrawnDeposit() public {
        vm.prank(USER);
        vault.deposit{value: DEPOSIT_AMOUNT}(SIX_MONTHS);

        vm.warp(block.timestamp + SIX_MONTHS + 1);

        vm.prank(USER);
        vault.withdraw(0);

        vm.prank(USER);
        vm.expectRevert(Vault.AlreadyWitdrawn.selector);
        vault.withdraw(0);
    }

    function test_RevertIf_WithdrawInvalidIndex() public {
        vm.prank(USER);
        vault.deposit{value: DEPOSIT_AMOUNT}(SIX_MONTHS);

        vm.warp(block.timestamp + SIX_MONTHS + 1);

        vm.prank(USER);
        vm.expectRevert(Vault.InvalidIndex.selector);
        vault.withdraw(1);
    }

    function test_RevertIf_WithdrawFromEmptyUserDeposits() public {
        vm.warp(block.timestamp + SIX_MONTHS + 1);

        vm.prank(USER);
        vm.expectRevert();
        vault.withdraw(0);
    }

    function test_RevertIf_WithdrawJustBeforeLockExpires() public {
        vm.prank(USER);
        vault.deposit{value: DEPOSIT_AMOUNT}(SIX_MONTHS);

        vm.warp(block.timestamp + SIX_MONTHS - 1);

        vm.prank(USER);
        vm.expectRevert(Vault.CantWithdrawUntilLockPeriodIsOver.selector);
        vault.withdraw(0);
    }

    function test_RevertIf_WithdrawDifferentLockPeriodsBeforeExpiry() public {
        vm.startPrank(USER);

        vault.deposit{value: DEPOSIT_AMOUNT}(SIX_MONTHS);
        vault.deposit{value: DEPOSIT_AMOUNT}(ONE_YEAR);
        vault.deposit{value: DEPOSIT_AMOUNT}(FIVE_YEARS);

        vm.stopPrank();

        vm.warp(block.timestamp + 7 * 30 days);

        vm.startPrank(USER);

        vm.expectRevert(Vault.CantWithdrawUntilLockPeriodIsOver.selector);
        vault.withdraw(1);

        vm.expectRevert(Vault.CantWithdrawUntilLockPeriodIsOver.selector);
        vault.withdraw(2);

        vm.stopPrank();
    }

    function test_WithdrawAfterSixMonthsLockExpires() public {
        uint256 userBalanceBefore = USER.balance;

        vm.prank(USER);
        vault.deposit{value: DEPOSIT_AMOUNT}(SIX_MONTHS);

        uint256 userBalanceAfterDeposit = USER.balance;
        assertEq(userBalanceAfterDeposit, userBalanceBefore - DEPOSIT_AMOUNT);

        vm.warp(block.timestamp + SIX_MONTHS + 1);

        vm.prank(USER);
        vm.expectEmit(true, true, false, true);
        emit Withdraw(USER, DEPOSIT_AMOUNT, block.timestamp);
        vault.withdraw(0);

        uint256 userBalanceAfterWithdraw = USER.balance;
        assertEq(userBalanceAfterWithdraw, userBalanceBefore);

        assertEq(vault.getTotalValueLocked(), 0);

        Vault.UserDeposit memory deposit = vault.getDepositByIndex(USER, 0);
        assertEq(deposit.amount, 0);
        assertEq(deposit.timestamp, 0);
        assertEq(deposit.lockUntil, 0);
        assertEq(uint256(deposit.state), uint256(Vault.DepositState.UNLOCKED));
        assertEq(deposit.withdrawn, true);
    }

    function test_WithdrawAfterOneYearLockExpires() public {
        uint256 userBalanceBefore = USER.balance;

        vm.prank(USER);
        vault.deposit{value: DEPOSIT_AMOUNT}(ONE_YEAR);

        vm.warp(block.timestamp + ONE_YEAR + 1);

        vm.prank(USER);
        vm.expectEmit(true, true, false, true);
        emit Withdraw(USER, DEPOSIT_AMOUNT, block.timestamp);
        vault.withdraw(0);

        assertEq(USER.balance, userBalanceBefore);

        assertEq(vault.getTotalValueLocked(), 0);
    }

    function test_WithdrawAfterFiveYearsLockExpires() public {
        uint256 userBalanceBefore = USER.balance;

        vm.prank(USER);
        vault.deposit{value: DEPOSIT_AMOUNT}(FIVE_YEARS);

        vm.warp(block.timestamp + FIVE_YEARS + 1);

        vm.prank(USER);
        vm.expectEmit(true, true, false, true);
        emit Withdraw(USER, DEPOSIT_AMOUNT, block.timestamp);
        vault.withdraw(0);

        assertEq(USER.balance, userBalanceBefore);
        assertEq(vault.getTotalValueLocked(), 0);
    }

    function test_WithdrawExactlyWhenLockExpires() public {
        uint256 userBalanceBefore = USER.balance;

        vm.prank(USER);
        vault.deposit{value: DEPOSIT_AMOUNT}(SIX_MONTHS);

        vm.warp(block.timestamp + SIX_MONTHS);

        vm.prank(USER);
        vm.expectEmit(true, true, false, true);
        emit Withdraw(USER, DEPOSIT_AMOUNT, block.timestamp);
        vault.withdraw(0);

        assertEq(USER.balance, userBalanceBefore);
        assertEq(vault.getTotalValueLocked(), 0);
    }

    function test_WithdrawMultipleDepositsPartially() public {
        uint256 userBalanceBefore = USER.balance;

        vm.startPrank(USER);
        vault.deposit{value: DEPOSIT_AMOUNT}(SIX_MONTHS);
        vault.deposit{value: DEPOSIT_AMOUNT * 2}(ONE_YEAR);
        vault.deposit{value: DEPOSIT_AMOUNT * 3}(FIVE_YEARS);
        vm.stopPrank();

        vm.warp(block.timestamp + 7 * 30 days);

        vm.prank(USER);
        vm.expectEmit(true, true, false, true);
        emit Withdraw(USER, DEPOSIT_AMOUNT, block.timestamp);
        vault.withdraw(0);

        assertEq(USER.balance, userBalanceBefore - DEPOSIT_AMOUNT * 5);
        assertEq(vault.getTotalValueLocked(), DEPOSIT_AMOUNT * 5);

        Vault.UserDeposit memory firstDeposit = vault.getDepositByIndex(USER, 0);
        assertEq(firstDeposit.withdrawn, true);

        Vault.UserDeposit memory secondDeposit = vault.getDepositByIndex(USER, 1);
        assertEq(uint256(secondDeposit.state), uint256(Vault.DepositState.LOCKED));
        assertEq(secondDeposit.withdrawn, false);
    }

    function test_WithdrawMultipleDepositsSequentially() public {
        uint256 userBalanceBefore = USER.balance;

        vm.startPrank(USER);
        vault.deposit{value: DEPOSIT_AMOUNT}(SIX_MONTHS);
        vault.deposit{value: DEPOSIT_AMOUNT * 2}(SIX_MONTHS);
        vm.stopPrank();

        vm.warp(block.timestamp + SIX_MONTHS + 1);

        vm.startPrank(USER);

        vm.expectEmit(true, true, false, true);
        emit Withdraw(USER, DEPOSIT_AMOUNT, block.timestamp);
        vault.withdraw(0);

        vm.expectEmit(true, true, false, true);
        emit Withdraw(USER, DEPOSIT_AMOUNT * 2, block.timestamp);
        vault.withdraw(1);

        vm.stopPrank();

        assertEq(USER.balance, userBalanceBefore);
        assertEq(vault.getTotalValueLocked(), 0);

        Vault.UserDeposit memory firstDeposit = vault.getDepositByIndex(USER, 0);
        Vault.UserDeposit memory secondDeposit = vault.getDepositByIndex(USER, 1);
        assertEq(firstDeposit.withdrawn, true);
        assertEq(secondDeposit.withdrawn, true);
    }

    function test_WithdrawFromMultipleUsers() public {
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");

        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);

        uint256 user1BalanceBefore = user1.balance;
        uint256 user2BalanceBefore = user2.balance;

        vm.prank(user1);
        vault.deposit{value: DEPOSIT_AMOUNT}(SIX_MONTHS);

        vm.prank(user2);
        vault.deposit{value: DEPOSIT_AMOUNT * 2}(SIX_MONTHS);

        vm.warp(block.timestamp + SIX_MONTHS + 1);

        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        emit Withdraw(user1, DEPOSIT_AMOUNT, block.timestamp);
        vault.withdraw(0);

        vm.prank(user2);
        vm.expectEmit(true, true, false, true);
        emit Withdraw(user2, DEPOSIT_AMOUNT * 2, block.timestamp);
        vault.withdraw(0);

        assertEq(user1.balance, user1BalanceBefore);
        assertEq(user2.balance, user2BalanceBefore);
        assertEq(vault.getTotalValueLocked(), 0);
    }

    function test_WithdrawMinimumAmount() public {
        uint256 userBalanceBefore = USER.balance;

        vm.prank(USER);
        vault.deposit{value: 1 wei}(SIX_MONTHS);

        vm.warp(block.timestamp + SIX_MONTHS + 1);

        vm.prank(USER);
        vm.expectEmit(true, true, false, true);
        emit Withdraw(USER, 1 wei, block.timestamp);
        vault.withdraw(0);

        assertEq(USER.balance, userBalanceBefore);
        assertEq(vault.getTotalValueLocked(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                            EDGE CASES TESTS
    //////////////////////////////////////////////////////////////*/

    function test_UsersCanDeposit() public {
        for (uint256 i = 0; i < 100; i++) {
            address user = makeAddr(string(abi.encodePacked("user", vm.toString(i))));
            vm.deal(user, 10 ether);
            vm.prank(user);
            vault.deposit{value: 1 ether}(SIX_MONTHS);
        }

        address user101 = makeAddr("user101");
        vm.deal(user101, 10 ether);
        vm.prank(user101);
        vault.deposit{value: 1 ether}(SIX_MONTHS);

        assertEq(vault.getTotalValueLocked(), 101 ether);
        assertEq(vault.getUserDeposits(user101).length, 1);
    }
    /*//////////////////////////////////////////////////////////////
                              GETTER TESTS
    //////////////////////////////////////////////////////////////*/

    function testGetTotalValueLocked() public {
        assertEq(vault.getTotalValueLocked(), 0);

        vm.startPrank(USER);
        vault.deposit{value: 1 ether}(180 days);
        vm.stopPrank();

        assertEq(vault.getTotalValueLocked(), 1 ether);
    }

    function testGetUserDeposits() public {
        vm.startPrank(USER);
        vault.deposit{value: 1 ether}(180 days);
        vault.deposit{value: 2 ether}(365 days);
        vm.stopPrank();

        Vault.UserDeposit[] memory deposits = vault.getUserDeposits(USER);
        assertEq(deposits.length, 2);
        assertEq(deposits[0].amount, 1 ether);
        assertEq(deposits[1].amount, 2 ether);
        assertEq(uint256(deposits[0].state), uint256(Vault.DepositState.LOCKED));
    }

    function testGetDepositByIndex() public {
        vm.startPrank(USER);
        vault.deposit{value: 1 ether}(180 days);
        vm.stopPrank();

        Vault.UserDeposit memory dep = vault.getDepositByIndex(USER, 0);
        assertEq(dep.amount, 1 ether);
        assertEq(uint256(dep.state), uint256(Vault.DepositState.LOCKED));
        assertEq(dep.withdrawn, false);
    }

    function testGetTotalAmountUserDepostied() public {
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);

        vm.startPrank(user1);
        vault.deposit{value: 1 ether}(SIX_MONTHS);
        vault.deposit{value: 2 ether}(ONE_YEAR);
        vm.stopPrank();

        vm.prank(user2);
        vault.deposit{value: 3 ether}(FIVE_YEARS);

        uint256 total1 = vault.getTotalAmountUserDepostied(user1);
        uint256 total2 = vault.getTotalAmountUserDepostied(user2);
        assertEq(total1, 3 ether, "user1 total deposited");
        assertEq(total2, 3 ether, "user2 total deposited");
    }

    function testGetTotalAmountOfActiveDeposits() public {
        address user = USER;
        vm.deal(user, 10 ether);

        vm.startPrank(user);
        vault.deposit{value: 1 ether}(SIX_MONTHS);
        vault.deposit{value: 2 ether}(ONE_YEAR);
        vault.deposit{value: 3 ether}(FIVE_YEARS);
        vm.stopPrank();

        uint256 activeAll = vault.getTotalAmountOfActiveDeposits(user);
        assertEq(activeAll, 6 ether, "all active at start");

        vm.warp(block.timestamp + SIX_MONTHS + 1);
        uint256 activeAfterFirst = vault.getTotalAmountOfActiveDeposits(user);
        assertEq(activeAfterFirst, 6 ether, "still all active, need withdraw to update state");

        vm.warp(block.timestamp + (ONE_YEAR - SIX_MONTHS));
        uint256 activeAfterSecond = vault.getTotalAmountOfActiveDeposits(user);
        assertEq(activeAfterSecond, 6 ether, "still all active, need withdraw to update state");

        vm.warp(block.timestamp + (FIVE_YEARS - ONE_YEAR));
        uint256 activeAfterAll = vault.getTotalAmountOfActiveDeposits(user);
        assertEq(activeAfterAll, 6 ether, "still all active, need withdraw to update state");

        vm.startPrank(user);
        vault.withdraw(0);
        uint256 afterWithdraw1 = vault.getTotalAmountOfActiveDeposits(user);
        assertEq(afterWithdraw1, 5 ether, "after withdrawing first deposit");

        vault.withdraw(1);
        uint256 afterWithdraw2 = vault.getTotalAmountOfActiveDeposits(user);
        assertEq(afterWithdraw2, 3 ether, "after withdrawing second deposit");

        vault.withdraw(2);
        uint256 afterWithdraw3 = vault.getTotalAmountOfActiveDeposits(user);
        assertEq(afterWithdraw3, 0, "after withdrawing all deposits");
        vm.stopPrank();
    }
}
