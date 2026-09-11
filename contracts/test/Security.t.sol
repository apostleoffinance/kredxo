// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {
    KredxoPolicyExpired,
    KredxoTradeRejected,
    KredxoUnauthorized,
    KredxoUnauthorizedReceiver,
    KredxoWithdrawalsDisabled
} from "../src/KredxoErrors.sol";
import {IKredxoRiskPolicy} from "../src/IKredxoRiskPolicy.sol";
import {KredxoRegistry} from "../src/KredxoRegistry.sol";
import {KredxoCreditVault} from "../src/KredxoCreditVault.sol";
import {KredxoRiskController} from "../src/KredxoRiskController.sol";
import {KredxoRiskPolicy} from "../src/KredxoRiskPolicy.sol";
import {KredxoTradingAccount} from "../src/KredxoTradingAccount.sol";
import {MockUSDC} from "./mocks/MockUSDC.sol";

/// @notice Callback token used to prove vault withdraw is non-reentrant.
contract ReentrantUSDC is ERC20 {
    KredxoCreditVault public vault;
    bool public attack;

    constructor() ERC20("USD Coin", "USDC") {}

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function setVault(KredxoCreditVault vault_) external {
        vault = vault_;
    }

    function arm() external {
        attack = true;
    }

    function _update(address from, address to, uint256 value) internal override {
        super._update(from, to, value);
        if (attack && address(vault) != address(0) && from == address(vault)) {
            attack = false;
            vault.withdraw(1);
        }
    }
}

/// @notice Phase 14: enforcement lives in the contracts, not the frontend.
contract SecurityTest is Test {
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
        vault.setRiskPolicy(address(policy));
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

    function test_strangerCannotAllocateOrUpdatePolicy() public {
        vm.expectRevert();
        vm.prank(stranger);
        vault.allocateCredit(trader, 1 * USD);

        vm.expectRevert();
        vm.prank(stranger);
        vault.releaseCredit(trader, 1 * USD);

        address[] memory markets = new address[](1);
        uint256[] memory limits = new uint256[](1);
        markets[0] = btc;
        limits[0] = 1;
        vm.expectRevert();
        vm.prank(stranger);
        controller.applyPolicy(
            trader, 1, 1, 1, block.timestamp, block.timestamp + 1, 1, markets, limits
        );

        IKredxoRiskPolicy.Policy memory forged = IKredxoRiskPolicy.Policy({
            creditLimit: 1,
            maxLeverage: 1,
            dailyLossLimit: 1,
            validFrom: block.timestamp,
            validUntil: block.timestamp + 1,
            riskLevel: 1,
            active: true
        });
        vm.expectRevert(KredxoUnauthorized.selector);
        vm.prank(stranger);
        policy.write(trader, forged, markets, limits);
    }

    function test_strangerCannotUtilizeToWalletOrTrade() public {
        vm.expectRevert();
        vm.prank(stranger);
        vault.utilizeCredit(trader, stranger, 1 * USD);

        vm.expectRevert(KredxoUnauthorizedReceiver.selector);
        vm.prank(admin);
        vault.utilizeCredit(trader, stranger, 1 * USD);

        vm.expectRevert(KredxoUnauthorized.selector);
        vm.prank(stranger);
        account.draw(1 * USD);

        vm.expectRevert(KredxoUnauthorized.selector);
        vm.prank(stranger);
        account.executeTrade(btc, 0, 1_000 * USD, 2 * WAD, BTC_PRICE);
    }

    function test_traderCannotWithdrawCreditAsUsdc() public {
        vm.expectRevert(KredxoWithdrawalsDisabled.selector);
        vm.prank(trader);
        account.withdraw(trader, 1 * USD);
        vm.expectRevert(KredxoWithdrawalsDisabled.selector);
        vm.prank(trader);
        account.withdrawCollateral(trader, 1 * USD);
        assertEq(usdc.balanceOf(trader), 0);
    }

    function test_lpCannotWithdrawReservedCapacity() public {
        vm.prank(lp);
        vm.expectRevert();
        vault.withdraw(160_000 * USD);

        uint256 nav = vault.totalAssets();
        uint256 idle = usdc.balanceOf(address(vault));
        assertEq(nav, idle + vault.utilizedCredit() + vault.interestAccrued());
        assertLe(vault.utilizedCredit(), vault.allocatedCredit());
        assertLe(vault.availableLiquidity(), idle);
    }

    function test_lossDoesNotInflateNav() public {
        uint256 navBefore = vault.totalAssets();
        uint256 utilizedBefore = vault.utilizedCredit();

        vm.prank(trader);
        uint256 id = account.executeTrade(btc, 0, 12_000 * USD, 3 * WAD, BTC_PRICE);
        vm.prank(trader);
        int256 pnl = account.closePosition(id, (BTC_PRICE * 80) / 100);
        assertLt(pnl, 0);

        assertEq(vault.totalAssets(), navBefore);
        assertLt(vault.utilizedCredit(), utilizedBefore);
        assertEq(
            vault.totalAssets(),
            usdc.balanceOf(address(vault)) + vault.utilizedCredit() + vault.interestAccrued()
        );
    }

    function test_expiredAndFuturePolicyCannotTrade() public {
        vm.warp(block.timestamp + 2 days);
        assertFalse(policy.isCurrent(trader));

        vm.expectRevert(KredxoPolicyExpired.selector);
        vm.prank(trader);
        account.draw(1 * USD);

        vm.expectRevert(abi.encodeWithSelector(KredxoTradeRejected.selector, account.REASON_POLICY()));
        vm.prank(trader);
        account.executeTrade(btc, 0, 1_000 * USD, 2 * WAD, BTC_PRICE);

        _applyAt(50_000 * USD, 5 * WAD, 2_000 * USD, 15_000 * USD, block.timestamp + 1 days, block.timestamp + 2 days);
        assertFalse(policy.isCurrent(trader));
        vm.expectRevert(abi.encodeWithSelector(KredxoTradeRejected.selector, account.REASON_POLICY()));
        vm.prank(trader);
        account.executeTrade(btc, 0, 1_000 * USD, 2 * WAD, BTC_PRICE);
    }

    function test_frontendCannotBypassLivePolicy() public {
        vm.prank(trader);
        uint256 id = account.executeTrade(btc, 0, 10_000 * USD, 2 * WAD, BTC_PRICE);
        vm.prank(trader);
        account.closePosition(id, BTC_PRICE);

        _apply(50_000 * USD, 3 * WAD, 1_000 * USD, 5_000 * USD);

        vm.expectRevert(abi.encodeWithSelector(KredxoTradeRejected.selector, account.REASON_EXPOSURE()));
        vm.prank(trader);
        account.executeTrade(btc, 0, 10_000 * USD, 2 * WAD, BTC_PRICE);

        vm.expectRevert(abi.encodeWithSelector(KredxoTradeRejected.selector, account.REASON_LEVERAGE()));
        vm.prank(trader);
        account.executeTrade(btc, 0, 1_000 * USD, 4 * WAD, BTC_PRICE);
    }

    function testFuzz_overLimitNeverSucceeds(uint256 extra) public {
        uint256 size = policy.positionLimit(trader, btc) + bound(extra, 1, 1_000_000 * USD);
        uint256 before = account.exposureOf(btc);
        vm.expectRevert(abi.encodeWithSelector(KredxoTradeRejected.selector, account.REASON_EXPOSURE()));
        vm.prank(trader);
        account.executeTrade(btc, 0, size, 2 * WAD, BTC_PRICE);
        assertEq(account.exposureOf(btc), before);
    }

    function test_zeroMarginSizeRejected() public {
        vm.expectRevert(abi.encodeWithSelector(KredxoTradeRejected.selector, account.REASON_CREDIT()));
        vm.prank(trader);
        account.executeTrade(btc, 0, 1, 5 * WAD, BTC_PRICE);
    }

    function test_withdrawReentrancyBlocked() public {
        ReentrantUSDC token = new ReentrantUSDC();
        KredxoRegistry registry = new KredxoRegistry(admin);
        KredxoCreditVault reVault = new KredxoCreditVault(address(registry), address(token), admin);
        token.setVault(reVault);
        token.mint(lp, 10_000 * USD);
        vm.startPrank(lp);
        token.approve(address(reVault), 10_000 * USD);
        reVault.deposit(10_000 * USD);
        token.arm();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        reVault.withdraw(1_000 * USD);
        vm.stopPrank();
    }

    function _apply(uint256 credit, uint256 leverage, uint256 daily, uint256 btcLimit) internal {
        _applyAt(credit, leverage, daily, btcLimit, block.timestamp, block.timestamp + 1 days);
    }

    function _applyAt(
        uint256 credit,
        uint256 leverage,
        uint256 daily,
        uint256 btcLimit,
        uint256 validFrom,
        uint256 validUntil
    ) internal {
        address[] memory markets = new address[](1);
        uint256[] memory limits = new uint256[](1);
        markets[0] = btc;
        limits[0] = btcLimit;
        vm.prank(admin);
        controller.applyPolicy(trader, credit, leverage, daily, validFrom, validUntil, 1, markets, limits);
    }
}
