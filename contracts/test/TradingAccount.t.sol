// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import {
    KredxoAccountInactive,
    KredxoAccountNotBound,
    KredxoInsufficientCredit,
    KredxoUnauthorized,
    KredxoUnauthorizedReceiver,
    KredxoWithdrawalsDisabled,
    KredxoZeroAddress,
    KredxoZeroAmount
} from "../src/KredxoErrors.sol";
import {KredxoRegistry} from "../src/KredxoRegistry.sol";
import {KredxoCreditVault} from "../src/KredxoCreditVault.sol";
import {KredxoTradingAccount} from "../src/KredxoTradingAccount.sol";
import {MockUSDC} from "./mocks/MockUSDC.sol";

contract TradingAccountTest is Test {
    uint256 internal constant USD = 1e6;
    uint256 internal constant WAD = 1e18;

    MockUSDC internal usdc;
    KredxoRegistry internal registry;
    KredxoCreditVault internal vault;
    KredxoTradingAccount internal account;

    address internal admin = makeAddr("admin");
    address internal lp = makeAddr("lp");
    address internal trader = makeAddr("trader");
    address internal stranger = makeAddr("stranger");

    function setUp() public {
        usdc = new MockUSDC();
        registry = new KredxoRegistry(admin);
        vault = new KredxoCreditVault(address(registry), address(usdc), admin);
        account = new KredxoTradingAccount(address(registry), address(vault), trader, admin);

        vm.prank(admin);
        vault.setTradingAccount(trader, address(account));

        usdc.mint(lp, 1_000_000 * USD);
        usdc.mint(trader, 1_000_000 * USD);

        vm.startPrank(lp);
        usdc.approve(address(vault), 100_000 * USD);
        vault.deposit(100_000 * USD);
        vm.stopPrank();

        vm.prank(admin);
        vault.allocateCredit(trader, 50_000 * USD);
    }

    function _activate() internal {
        vm.prank(admin);
        account.activate(50_000 * USD, 5 * WAD, 2_000 * USD);
    }

    function test_constructorRejectsZeroAddresses() public {
        vm.expectRevert(KredxoZeroAddress.selector);
        new KredxoTradingAccount(address(0), address(vault), trader, admin);
        vm.expectRevert(KredxoZeroAddress.selector);
        new KredxoTradingAccount(address(registry), address(0), trader, admin);
        vm.expectRevert(KredxoZeroAddress.selector);
        new KredxoTradingAccount(address(registry), address(vault), address(0), admin);
        vm.expectRevert(KredxoZeroAddress.selector);
        new KredxoTradingAccount(address(registry), address(vault), trader, address(0));
    }

    function test_bindRequiresMatchingVaultAndTrader() public {
        address other = makeAddr("other");
        KredxoTradingAccount mismatch =
            new KredxoTradingAccount(address(registry), address(vault), other, admin);

        vm.prank(admin);
        vm.expectRevert(KredxoAccountNotBound.selector);
        vault.setTradingAccount(trader, address(mismatch));
    }

    function test_accountStateAfterActivate() public {
        _activate();

        KredxoTradingAccount.CreditAccount memory state = account.account();
        assertEq(state.trader, trader);
        assertEq(state.creditLimit, 50_000 * USD);
        assertEq(state.usedCredit, 0);
        assertEq(state.collateral, 0);
        assertEq(state.maxLeverage, 5 * WAD);
        assertEq(state.dailyLossLimit, 2_000 * USD);
        assertTrue(state.active);
        assertEq(account.availableCredit(), 50_000 * USD);
        assertEq(account.VAULT(), address(vault));
        assertEq(vault.accountOf(trader), address(account));
    }

    function test_positionStructExistsEmpty() public view {
        (address market, uint8 side, uint256 size, uint256 entryPrice, uint256 leverage, uint256 margin, int256 pnl, bool open)
        = account.positions(0);
        assertEq(market, address(0));
        assertEq(side, 0);
        assertEq(size, 0);
        assertEq(entryPrice, 0);
        assertEq(leverage, 0);
        assertEq(margin, 0);
        assertEq(pnl, 0);
        assertFalse(open);
        assertEq(account.positionCount(), 0);
    }

    function test_drawSendsUsdcToAccountNotTrader() public {
        _activate();
        uint256 traderBefore = usdc.balanceOf(trader);

        vm.prank(trader);
        account.draw(15_000 * USD);

        assertEq(usdc.balanceOf(address(account)), 15_000 * USD);
        assertEq(usdc.balanceOf(trader), traderBefore);
        assertEq(account.usedCredit(), 15_000 * USD);
        assertEq(account.availableCredit(), 35_000 * USD);
        assertEq(vault.utilizedOf(trader), 15_000 * USD);
        assertEq(vault.allocatedOf(trader), 50_000 * USD);
        assertEq(vault.totalAssets(), 100_000 * USD);
    }

    function test_traderCannotWithdrawUsdc() public {
        _activate();
        vm.prank(trader);
        account.draw(15_000 * USD);

        vm.prank(trader);
        vm.expectRevert(KredxoWithdrawalsDisabled.selector);
        account.withdraw(trader, 15_000 * USD);

        vm.prank(trader);
        vm.expectRevert(KredxoWithdrawalsDisabled.selector);
        account.withdrawCollateral(trader, 1);
    }

    function test_cannotUtilizeToTraderWalletOnceBound() public {
        vm.prank(admin);
        vm.expectRevert(KredxoUnauthorizedReceiver.selector);
        vault.utilizeCredit(trader, trader, 1_000 * USD);
    }

    function test_cannotDrawWhenInactive() public {
        vm.prank(trader);
        vm.expectRevert(KredxoAccountInactive.selector);
        account.draw(1_000 * USD);
    }

    function test_cannotDrawMoreThanCreditLimit() public {
        _activate();
        vm.prank(trader);
        vm.expectRevert(KredxoInsufficientCredit.selector);
        account.draw(50_000 * USD + 1);
    }

    function test_strangerCannotDraw() public {
        _activate();
        vm.prank(stranger);
        vm.expectRevert(KredxoUnauthorized.selector);
        account.draw(1_000 * USD);
    }

    function test_repayReturnsUsdcToVault() public {
        _activate();
        vm.prank(trader);
        account.draw(15_000 * USD);

        vm.prank(trader);
        account.repay(15_000 * USD);

        assertEq(account.usedCredit(), 0);
        assertEq(vault.utilizedOf(trader), 0);
        assertEq(usdc.balanceOf(address(account)), 0);
        assertEq(usdc.balanceOf(address(vault)), 100_000 * USD);
        assertEq(vault.allocatedOf(trader), 50_000 * USD);
    }

    function test_depositCollateralDoesNotIncreaseUsedCredit() public {
        _activate();
        vm.startPrank(trader);
        usdc.approve(address(account), 5_000 * USD);
        account.depositCollateral(5_000 * USD);
        vm.stopPrank();

        assertEq(account.collateral(), 5_000 * USD);
        assertEq(account.usedCredit(), 0);
        assertEq(usdc.balanceOf(address(account)), 5_000 * USD);

        vm.prank(trader);
        vm.expectRevert(KredxoWithdrawalsDisabled.selector);
        account.withdrawCollateral(trader, 5_000 * USD);
    }

    function test_activateRejectsZeroLimits() public {
        vm.prank(admin);
        vm.expectRevert(KredxoZeroAmount.selector);
        account.activate(0, 5 * WAD, 2_000 * USD);
    }
}
