// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import {
    KredxoPolicyBound,
    KredxoPolicyExpired,
    KredxoTradeRejected,
    KredxoUnauthorized,
    KredxoZeroAddress,
    KredxoZeroAmount
} from "../src/KredxoErrors.sol";
import {IKredxoRiskPolicy} from "../src/IKredxoRiskPolicy.sol";
import {KredxoRegistry} from "../src/KredxoRegistry.sol";
import {KredxoCreditVault} from "../src/KredxoCreditVault.sol";
import {KredxoRiskController} from "../src/KredxoRiskController.sol";
import {KredxoRiskPolicy} from "../src/KredxoRiskPolicy.sol";
import {KredxoTradingAccount} from "../src/KredxoTradingAccount.sol";
import {MockUSDC} from "./mocks/MockUSDC.sol";

contract RiskPolicyTest is Test {
    uint256 internal constant USD = 1e6;
    uint256 internal constant WAD = 1e18;
    uint256 internal constant BTC_PRICE = 60_000 * WAD;

    MockUSDC internal usdc;
    KredxoCreditVault internal vault;
    KredxoRiskPolicy internal policy;
    KredxoRiskController internal controller;
    KredxoTradingAccount internal account;

    address internal admin = makeAddr("admin");
    address internal lp = makeAddr("lp");
    address internal trader = makeAddr("trader");
    address internal stranger = makeAddr("stranger");
    address internal btc = makeAddr("BTC");
    address internal eth = makeAddr("ETH");
    uint8 internal levelNormal;
    uint8 internal levelHigh;

    function setUp() public {
        usdc = new MockUSDC();
        KredxoRegistry registry = new KredxoRegistry(admin);
        vault = new KredxoCreditVault(address(registry), address(usdc), admin);
        account = new KredxoTradingAccount(address(registry), address(vault), trader, admin);
        policy = new KredxoRiskPolicy(admin);
        controller = new KredxoRiskController(address(policy), admin);

        vm.prank(admin);
        policy.setController(address(controller));
        vm.prank(admin);
        account.setRiskPolicy(address(policy));
        vm.prank(admin);
        vault.setTradingAccount(trader, address(account));

        usdc.mint(lp, 1_000_000 * USD);
        vm.startPrank(lp);
        usdc.approve(address(vault), 200_000 * USD);
        vault.deposit(200_000 * USD);
        vm.stopPrank();

        vm.prank(admin);
        vault.allocateCredit(trader, 50_000 * USD);

        vm.prank(admin);
        account.activate(50_000 * USD, 5 * WAD, 2_000 * USD);

        levelNormal = policy.LEVEL_NORMAL();
        levelHigh = policy.LEVEL_HIGH();
    }

    function _markets(uint256 btcLimit, uint256 ethLimit)
        internal
        view
        returns (address[] memory markets, uint256[] memory limits)
    {
        markets = new address[](2);
        limits = new uint256[](2);
        markets[0] = btc;
        markets[1] = eth;
        limits[0] = btcLimit;
        limits[1] = ethLimit;
    }

    function _apply(
        uint256 credit,
        uint256 leverage,
        uint256 dailyLoss,
        uint8 level,
        uint256 btcLimit,
        uint256 ethLimit,
        uint256 validFor
    ) internal {
        (address[] memory markets, uint256[] memory limits) = _markets(btcLimit, ethLimit);
        vm.prank(admin);
        controller.applyPolicy(
            trader,
            credit,
            leverage,
            dailyLoss,
            block.timestamp,
            block.timestamp + validFor,
            level,
            markets,
            limits
        );
    }

    function _applyNormal() internal {
        _apply(50_000 * USD, 5 * WAD, 2_000 * USD, levelNormal, 25_000 * USD, 15_000 * USD, 1 days);
    }

    function _applyHigh() internal {
        _apply(32_000 * USD, 3 * WAD, 1_000 * USD, levelHigh, 12_000 * USD, 8_000 * USD, 1 days);
    }

    function test_onlyControllerCanWritePolicy() public {
        (address[] memory markets, uint256[] memory limits) = _markets(25_000 * USD, 15_000 * USD);
        IKredxoRiskPolicy.Policy memory next = IKredxoRiskPolicy.Policy({
            creditLimit: 50_000 * USD,
            maxLeverage: 5 * WAD,
            dailyLossLimit: 2_000 * USD,
            validFrom: block.timestamp,
            validUntil: block.timestamp + 1 days,
            riskLevel: levelNormal,
            active: true
        });

        vm.expectRevert(KredxoUnauthorized.selector);
        policy.write(trader, next, markets, limits);

        vm.prank(admin);
        vm.expectRevert(KredxoUnauthorized.selector);
        policy.write(trader, next, markets, limits);

        vm.prank(stranger);
        vm.expectRevert();
        controller.applyPolicy(
            trader,
            50_000 * USD,
            5 * WAD,
            2_000 * USD,
            block.timestamp,
            block.timestamp + 1 days,
            levelNormal,
            markets,
            limits
        );
    }

    function test_applyPolicyEmitsAndStores() public {
        (address[] memory markets, uint256[] memory limits) = _markets(25_000 * USD, 15_000 * USD);

        vm.expectEmit(true, false, false, true, address(controller));
        emit KredxoRiskController.PolicyUpdated(trader, 50_000 * USD, 5 * WAD);
        vm.expectEmit(true, false, false, true, address(controller));
        emit KredxoRiskController.CreditAdjusted(trader, 0, 50_000 * USD);
        vm.expectEmit(true, false, false, true, address(controller));
        emit KredxoRiskController.RiskLevelChanged(trader, 0, levelNormal);

        vm.prank(admin);
        controller.applyPolicy(
            trader,
            50_000 * USD,
            5 * WAD,
            2_000 * USD,
            block.timestamp,
            block.timestamp + 1 days,
            levelNormal,
            markets,
            limits
        );

        IKredxoRiskPolicy.Policy memory stored = policy.policyOf(trader);
        assertEq(stored.creditLimit, 50_000 * USD);
        assertEq(stored.maxLeverage, 5 * WAD);
        assertEq(stored.dailyLossLimit, 2_000 * USD);
        assertEq(stored.riskLevel, levelNormal);
        assertTrue(stored.active);
        assertTrue(policy.isCurrent(trader));
        assertTrue(policy.marketAllowed(trader, btc));
        assertEq(policy.positionLimit(trader, btc), 25_000 * USD);
        assertEq(account.creditLimit(), 50_000 * USD);
        assertEq(account.maxLeverage(), 5 * WAD);
        assertEq(account.dailyLossLimit(), 2_000 * USD);
    }

    function test_accountReadsPolicyNotLocalLimits() public {
        _applyNormal();
        vm.prank(trader);
        account.draw(20_000 * USD);

        vm.prank(trader);
        account.executeTrade(btc, 0, 20_000 * USD, 2 * WAD, BTC_PRICE);

        _applyHigh();

        assertEq(account.creditLimit(), 32_000 * USD);
        assertEq(account.maxLeverage(), 3 * WAD);
        assertEq(policy.positionLimit(trader, btc), 12_000 * USD);

        vm.expectRevert(abi.encodeWithSelector(KredxoTradeRejected.selector, account.REASON_EXPOSURE()));
        vm.prank(trader);
        account.executeTrade(btc, 0, 20_000 * USD, 2 * WAD, BTC_PRICE);
    }

    function test_expiredPolicyCannotTradeOrDraw() public {
        _apply(50_000 * USD, 5 * WAD, 2_000 * USD, levelNormal, 25_000 * USD, 15_000 * USD, 1);
        vm.prank(trader);
        account.draw(5_000 * USD);

        vm.warp(block.timestamp + 2);
        assertFalse(policy.isCurrent(trader));

        vm.expectRevert(KredxoPolicyExpired.selector);
        vm.prank(trader);
        account.draw(1_000 * USD);

        vm.expectRevert(abi.encodeWithSelector(KredxoTradeRejected.selector, account.REASON_POLICY()));
        vm.prank(trader);
        account.executeTrade(btc, 0, 1_000 * USD, 2 * WAD, BTC_PRICE);
    }

    function test_localLimitUpdatesBlockedWhenPolicyBound() public {
        vm.prank(admin);
        vm.expectRevert(KredxoPolicyBound.selector);
        account.setLimits(10_000 * USD, 2 * WAD, 500 * USD);

        vm.prank(admin);
        vm.expectRevert(KredxoPolicyBound.selector);
        account.setMarket(btc, true, 99_000 * USD);
    }

    function test_controllerMustBeBoundOnce() public {
        vm.prank(admin);
        vm.expectRevert(KredxoUnauthorized.selector);
        policy.setController(makeAddr("other"));
    }

    function test_applyPolicyRejectsZeroWindow() public {
        (address[] memory markets, uint256[] memory limits) = _markets(1, 1);
        vm.prank(admin);
        vm.expectRevert(KredxoZeroAmount.selector);
        controller.applyPolicy(
            trader, 1, 1, 1, block.timestamp, block.timestamp, levelNormal, markets, limits
        );
    }

    function test_policyRejectsZeroAdmin() public {
        vm.expectRevert(KredxoZeroAddress.selector);
        new KredxoRiskPolicy(address(0));
    }
}
