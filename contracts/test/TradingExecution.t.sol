// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import {KredxoTradeRejected, KredxoUnauthorized} from "../src/KredxoErrors.sol";
import {KredxoRegistry} from "../src/KredxoRegistry.sol";
import {KredxoCreditVault} from "../src/KredxoCreditVault.sol";
import {KredxoRiskController} from "../src/KredxoRiskController.sol";
import {KredxoRiskPolicy} from "../src/KredxoRiskPolicy.sol";
import {KredxoTradingAccount} from "../src/KredxoTradingAccount.sol";
import {MockUSDC} from "./mocks/MockUSDC.sol";

contract TradingExecutionTest is Test {
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
        usdc.approve(address(vault), 100_000 * USD);
        vault.deposit(100_000 * USD);
        vm.stopPrank();

        vm.prank(admin);
        vault.allocateCredit(trader, 50_000 * USD);

        _applyPolicy(50_000 * USD, 5 * WAD, 2_000 * USD, policy.LEVEL_NORMAL(), 15_000 * USD);

        vm.prank(admin);
        account.activate(50_000 * USD, 5 * WAD, 2_000 * USD);

        vm.prank(trader);
        account.draw(20_000 * USD);
    }

    function _applyPolicy(
        uint256 credit,
        uint256 leverage,
        uint256 dailyLoss,
        uint8 level,
        uint256 btcLimit
    ) internal {
        address[] memory markets = new address[](1);
        markets[0] = btc;
        uint256[] memory limits = new uint256[](1);
        limits[0] = btcLimit;
        vm.prank(admin);
        controller.applyPolicy(
            trader,
            credit,
            leverage,
            dailyLoss,
            block.timestamp,
            block.timestamp + 1 days,
            level,
            markets,
            limits
        );
    }

    function test_validTradeApprovesAndOpensPosition() public {
        vm.expectEmit(true, false, false, true, address(account));
        emit KredxoTradingAccount.TradeApproved(trader, btc, 10_000 * USD);

        vm.prank(trader);
        uint256 id = account.executeTrade(btc, 0, 10_000 * USD, 3 * WAD, BTC_PRICE);

        assertEq(id, 1);
        (
            address market,
            uint8 side,
            uint256 size,
            uint256 entryPrice,
            uint256 leverage,
            uint256 margin,
            int256 pnl,
            bool open
        ) = account.positions(id);

        assertEq(market, btc);
        assertEq(side, account.SIDE_LONG());
        assertEq(size, 10_000 * USD);
        assertEq(entryPrice, BTC_PRICE);
        assertEq(leverage, 3 * WAD);
        assertEq(margin, (10_000 * USD * WAD) / (3 * WAD));
        assertEq(pnl, 0);
        assertTrue(open);
        assertEq(account.exposureOf(btc), 10_000 * USD);
        assertEq(account.lockedMargin(), margin);
    }

    function test_overLimitTradeRevertsOnchain() public {
        vm.expectEmit(true, false, false, true, address(account));
        emit KredxoTradingAccount.TradeRejected(trader, account.REASON_EXPOSURE());

        vm.expectRevert(
            abi.encodeWithSelector(KredxoTradeRejected.selector, account.REASON_EXPOSURE())
        );
        vm.prank(trader);
        account.executeTrade(btc, 0, 25_000 * USD, 3 * WAD, BTC_PRICE);

        assertEq(account.positionCount(), 0);
        assertEq(account.exposureOf(btc), 0);
    }

    function test_rejectsInactiveAccount() public {
        vm.prank(admin);
        account.deactivate();

        vm.expectRevert(
            abi.encodeWithSelector(KredxoTradeRejected.selector, account.REASON_INACTIVE())
        );
        vm.prank(trader);
        account.executeTrade(btc, 0, 1_000 * USD, 2 * WAD, BTC_PRICE);
    }

    function test_rejectsDisallowedMarket() public {
        vm.expectRevert(abi.encodeWithSelector(KredxoTradeRejected.selector, account.REASON_MARKET()));
        vm.prank(trader);
        account.executeTrade(eth, 0, 1_000 * USD, 2 * WAD, BTC_PRICE);
    }

    function test_rejectsExcessLeverage() public {
        vm.expectRevert(
            abi.encodeWithSelector(KredxoTradeRejected.selector, account.REASON_LEVERAGE())
        );
        vm.prank(trader);
        account.executeTrade(btc, 0, 1_000 * USD, 6 * WAD, BTC_PRICE);
    }

    function test_rejectsWhenCreditIdleIsInsufficient() public {
        vm.prank(trader);
        account.executeTrade(btc, 0, 15_000 * USD, 1 * WAD, BTC_PRICE);

        _applyPolicy(50_000 * USD, 5 * WAD, 2_000 * USD, policy.LEVEL_NORMAL(), 30_000 * USD);

        vm.expectRevert(abi.encodeWithSelector(KredxoTradeRejected.selector, account.REASON_CREDIT()));
        vm.prank(trader);
        account.executeTrade(btc, 0, 10_000 * USD, 1 * WAD, BTC_PRICE);
    }

    function test_strangerCannotTrade() public {
        vm.expectRevert(KredxoUnauthorized.selector);
        vm.prank(stranger);
        account.executeTrade(btc, 0, 1_000 * USD, 2 * WAD, BTC_PRICE);
    }

    function test_closeLosingTradeThenDailyLossBlocksNext() public {
        vm.prank(trader);
        uint256 id = account.executeTrade(btc, 0, 12_000 * USD, 3 * WAD, BTC_PRICE);

        // 20% drop on $12k exposure = $2,400 loss, above $2,000 daily limit.
        vm.prank(trader);
        int256 pnl = account.closePosition(id, (BTC_PRICE * 80) / 100);
        assertLt(pnl, 0);
        assertGe(account.dailyLoss(), account.dailyLossLimit());

        vm.expectRevert(
            abi.encodeWithSelector(KredxoTradeRejected.selector, account.REASON_DAILY_LOSS())
        );
        vm.prank(trader);
        account.executeTrade(btc, 0, 1_000 * USD, 2 * WAD, BTC_PRICE);
    }

    function test_secondTradeAddsExposureUntilLimit() public {
        vm.prank(trader);
        account.executeTrade(btc, 0, 10_000 * USD, 3 * WAD, BTC_PRICE);

        vm.prank(trader);
        account.executeTrade(btc, 1, 5_000 * USD, 2 * WAD, BTC_PRICE);
        assertEq(account.exposureOf(btc), 15_000 * USD);

        vm.expectRevert(
            abi.encodeWithSelector(KredxoTradeRejected.selector, account.REASON_EXPOSURE())
        );
        vm.prank(trader);
        account.executeTrade(btc, 0, 1 * USD, 2 * WAD, BTC_PRICE);
    }
}
