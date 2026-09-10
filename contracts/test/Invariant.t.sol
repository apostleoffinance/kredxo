// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import {KredxoTradeRejected} from "../src/KredxoErrors.sol";
import {IKredxoRiskPolicy} from "../src/IKredxoRiskPolicy.sol";
import {KredxoRegistry} from "../src/KredxoRegistry.sol";
import {KredxoCreditVault} from "../src/KredxoCreditVault.sol";
import {KredxoRiskController} from "../src/KredxoRiskController.sol";
import {KredxoRiskPolicy} from "../src/KredxoRiskPolicy.sol";
import {KredxoTradingAccount} from "../src/KredxoTradingAccount.sol";
import {MockUSDC} from "./mocks/MockUSDC.sol";

/// @notice Random trades against a live policy. Over-limit must never succeed.
contract TradeHandler is Test {
    uint256 internal constant USD = 1e6;
    uint256 internal constant WAD = 1e18;
    uint256 internal constant BTC_PRICE = 60_000 * WAD;

    KredxoTradingAccount public account;
    KredxoRiskController public controller;
    KredxoRiskPolicy public policy;
    address public admin;
    address public trader;
    address public btc;

    uint256 public approved;
    uint256 public rejected;

    constructor(
        KredxoTradingAccount account_,
        KredxoRiskController controller_,
        KredxoRiskPolicy policy_,
        address admin_,
        address trader_,
        address btc_
    ) {
        account = account_;
        controller = controller_;
        policy = policy_;
        admin = admin_;
        trader = trader_;
        btc = btc_;
    }

    function trade(uint256 sizeRaw, uint256 levRaw, uint8 sideRaw) external {
        uint256 size = bound(sizeRaw, 1, 80_000 * USD);
        uint256 leverage = bound(levRaw, 1 * WAD, 20 * WAD);
        uint8 side = uint8(bound(sideRaw, 0, 1));

        uint256 limit = policy.positionLimit(trader, btc);
        uint256 maxLev = account.maxLeverage();
        uint256 exposure = account.exposureOf(btc);
        bool forbidden =
            leverage > maxLev || exposure + size > limit || !policy.isCurrent(trader);

        vm.prank(trader);
        try account.executeTrade(btc, side, size, leverage, BTC_PRICE) {
            assertFalse(forbidden, "fail-closed: over-limit trade succeeded");
            approved += 1;
        } catch {
            rejected += 1;
        }
    }

    function tighten(uint256 raw) external {
        uint256 btcLimit = bound(raw, 1, 25_000 * USD);
        IKredxoRiskPolicy.Policy memory current = policy.policyOf(trader);
        address[] memory markets = new address[](1);
        uint256[] memory limits = new uint256[](1);
        markets[0] = btc;
        limits[0] = btcLimit;
        vm.prank(admin);
        controller.applyPolicy(
            trader,
            current.creditLimit,
            current.maxLeverage,
            current.dailyLossLimit,
            block.timestamp,
            block.timestamp + 1 days,
            current.riskLevel,
            markets,
            limits
        );
    }

    function closeOne(uint256 raw) external {
        uint256 n = account.positionCount();
        if (n == 0) return;
        uint256 id = bound(raw, 1, n);
        (,,,,,,, bool open) = account.positions(id);
        if (!open) return;
        vm.prank(trader);
        account.closePosition(id, BTC_PRICE);
    }
}

/// @notice Phase 13: deposit / withdraw / allocate / repay / policy / approve / reject + fail-closed fuzz.
contract FailClosedTest is Test {
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
    address internal btc = makeAddr("BTC");

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

        usdc.mint(lp, 200_000 * USD);
        vm.startPrank(lp);
        usdc.approve(address(vault), 200_000 * USD);
        vault.deposit(200_000 * USD);
        vm.stopPrank();

        vm.prank(admin);
        vault.allocateCredit(trader, 50_000 * USD);
        _apply(50_000 * USD, 5 * WAD, 2_000 * USD, 15_000 * USD);
        vm.prank(admin);
        account.activate(50_000 * USD, 5 * WAD, 2_000 * USD);
        vm.prank(trader);
        account.draw(20_000 * USD);
    }

    function test_depositWithdrawAllocateRepayPolicyApproveReject() public {
        usdc.mint(lp, 20_000 * USD);
        vm.startPrank(lp);
        usdc.approve(address(vault), 20_000 * USD);
        vault.deposit(20_000 * USD);
        uint256 withdrawn = vault.withdraw(10_000 * USD);
        vm.stopPrank();
        assertEq(withdrawn, 10_000 * USD);

        vm.prank(admin);
        vault.allocateCredit(trader, 5_000 * USD);
        assertEq(vault.allocatedOf(trader), 55_000 * USD);

        _apply(50_000 * USD, 5 * WAD, 2_000 * USD, 15_000 * USD);

        vm.prank(trader);
        uint256 id = account.executeTrade(btc, 0, 10_000 * USD, 2 * WAD, BTC_PRICE);
        assertEq(id, 1);
        assertEq(account.exposureOf(btc), 10_000 * USD);

        vm.expectRevert(
            abi.encodeWithSelector(KredxoTradeRejected.selector, account.REASON_EXPOSURE())
        );
        vm.prank(trader);
        account.executeTrade(btc, 0, 10_000 * USD, 2 * WAD, BTC_PRICE);
        assertEq(account.exposureOf(btc), 10_000 * USD);

        vm.prank(trader);
        account.closePosition(id, BTC_PRICE);
        vm.prank(trader);
        account.repay(5_000 * USD);
        assertEq(account.usedCredit(), 15_000 * USD);
    }

    function testFuzz_sizeOverPositionLimitAlwaysReverts(uint256 extra, uint256 levRaw, uint8 sideRaw)
        public
    {
        uint256 over = bound(extra, 1, 1_000_000 * USD);
        uint256 leverage = bound(levRaw, 1 * WAD, account.maxLeverage());
        uint8 side = uint8(bound(sideRaw, 0, 1));
        uint256 size = policy.positionLimit(trader, btc) + over;
        uint256 exposureBefore = account.exposureOf(btc);

        vm.expectRevert(
            abi.encodeWithSelector(KredxoTradeRejected.selector, account.REASON_EXPOSURE())
        );
        vm.prank(trader);
        account.executeTrade(btc, side, size, leverage, BTC_PRICE);

        assertEq(account.exposureOf(btc), exposureBefore);
        assertEq(account.positionCount(), 0);
    }

    function testFuzz_leverageOverMaxAlwaysReverts(uint256 sizeRaw, uint256 extraLev) public {
        uint256 size = bound(sizeRaw, 1, 10_000 * USD);
        uint256 leverage = bound(extraLev, account.maxLeverage() + 1, account.maxLeverage() + 50 * WAD);

        vm.expectRevert(
            abi.encodeWithSelector(KredxoTradeRejected.selector, account.REASON_LEVERAGE())
        );
        vm.prank(trader);
        account.executeTrade(btc, 0, size, leverage, BTC_PRICE);
        assertEq(account.exposureOf(btc), 0);
    }

    function test_tightenThenPreviouslyValidSizeReverts() public {
        vm.prank(trader);
        uint256 id = account.executeTrade(btc, 0, 10_000 * USD, 2 * WAD, BTC_PRICE);
        vm.prank(trader);
        account.closePosition(id, BTC_PRICE);

        _apply(50_000 * USD, 5 * WAD, 2_000 * USD, 5_000 * USD);

        vm.expectRevert(
            abi.encodeWithSelector(KredxoTradeRejected.selector, account.REASON_EXPOSURE())
        );
        vm.prank(trader);
        account.executeTrade(btc, 0, 10_000 * USD, 2 * WAD, BTC_PRICE);
        assertEq(account.exposureOf(btc), 0);
    }

    function _apply(uint256 credit, uint256 leverage, uint256 daily, uint256 btcLimit) internal {
        address[] memory markets = new address[](1);
        uint256[] memory limits = new uint256[](1);
        markets[0] = btc;
        limits[0] = btcLimit;
        vm.prank(admin);
        controller.applyPolicy(
            trader, credit, leverage, daily, block.timestamp, block.timestamp + 1 days, 1, markets, limits
        );
    }
}

/// @notice Stateful invariant: a trader never executes more risk than the active policy.
contract InvariantTest is Test {
    uint256 internal constant USD = 1e6;
    uint256 internal constant WAD = 1e18;

    TradeHandler internal handler;
    KredxoTradingAccount internal account;
    KredxoRiskPolicy internal policy;
    address internal trader;
    address internal btc;

    function setUp() public {
        address admin = makeAddr("admin");
        address lp = makeAddr("lp");
        trader = makeAddr("trader");
        btc = makeAddr("BTC");

        MockUSDC usdc = new MockUSDC();
        KredxoRegistry registry = new KredxoRegistry(admin);
        KredxoCreditVault vault = new KredxoCreditVault(address(registry), address(usdc), admin);
        account = new KredxoTradingAccount(address(registry), address(vault), trader, admin);
        policy = new KredxoRiskPolicy(admin);
        KredxoRiskController controller = new KredxoRiskController(address(policy), admin);

        vm.prank(admin);
        policy.setController(address(controller));
        vm.prank(admin);
        account.setRiskPolicy(address(policy));
        vm.prank(admin);
        vault.setTradingAccount(trader, address(account));

        usdc.mint(lp, 200_000 * USD);
        vm.startPrank(lp);
        usdc.approve(address(vault), 200_000 * USD);
        vault.deposit(200_000 * USD);
        vm.stopPrank();

        vm.prank(admin);
        vault.allocateCredit(trader, 50_000 * USD);

        address[] memory markets = new address[](1);
        uint256[] memory limits = new uint256[](1);
        markets[0] = btc;
        limits[0] = 15_000 * USD;
        vm.prank(admin);
        controller.applyPolicy(
            trader, 50_000 * USD, 5 * WAD, 2_000 * USD, block.timestamp, block.timestamp + 1 days, 1, markets, limits
        );
        vm.prank(admin);
        account.activate(50_000 * USD, 5 * WAD, 2_000 * USD);
        vm.prank(trader);
        account.draw(40_000 * USD);

        handler = new TradeHandler(account, controller, policy, admin, trader, btc);

        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = TradeHandler.trade.selector;
        selectors[1] = TradeHandler.tighten.selector;
        selectors[2] = TradeHandler.closeOne.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
        targetContract(address(handler));
    }

    function invariant_usedCreditNeverExceedsLimit() public view {
        assertLe(account.usedCredit(), account.creditLimit());
    }

    function invariant_overLimitTradeAlwaysReverts() public {
        uint256 limit = policy.positionLimit(trader, btc);
        uint256 exposure = account.exposureOf(btc);
        uint256 size = exposure >= limit ? uint256(1) : (limit - exposure + 1);
        uint256 leverage = account.maxLeverage();
        uint256 before = account.exposureOf(btc);

        vm.prank(trader);
        try account.executeTrade(btc, 0, size, leverage, 60_000 * WAD) {
            assertTrue(false, "fail-closed: over-limit trade succeeded");
        } catch {
            assertEq(account.exposureOf(btc), before);
        }
    }
}
