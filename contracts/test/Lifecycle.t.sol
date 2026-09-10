// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {KredxoTradeRejected} from "../src/KredxoErrors.sol";
import {IKredxoRiskPolicy} from "../src/IKredxoRiskPolicy.sol";
import {KredxoRegistry} from "../src/KredxoRegistry.sol";
import {KredxoCreditVault} from "../src/KredxoCreditVault.sol";
import {KredxoRiskController} from "../src/KredxoRiskController.sol";
import {KredxoRiskPolicy} from "../src/KredxoRiskPolicy.sol";
import {KredxoTradingAccount} from "../src/KredxoTradingAccount.sol";
import {MockUSDC} from "./mocks/MockUSDC.sol";

/// @notice Phase 9: LP → score/policy (Python fixture) → account → trade → PnL → tighten → reject.
contract LifecycleTest is Test {
    using stdJson for string;

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
    address internal eth = makeAddr("ETH");

    string internal fixture;

    function setUp() public {
        fixture = vm.readFile(string.concat(vm.projectRoot(), "/testdata/lifecycle.json"));

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
    }

    function test_pythonProposedPolicyEnforcedThroughLifecycle() public {
        uint256 deposit = 200_000 * USD;
        uint256 normalCredit = fixture.readUint(".normal.creditLimit");
        uint256 tradeSize = fixture.readUint(".tradeSize");
        uint256 leverage = fixture.readUint(".leverage");

        // LP deposit → vault
        usdc.mint(lp, deposit);
        vm.startPrank(lp);
        usdc.approve(address(vault), deposit);
        vault.deposit(deposit);
        vm.stopPrank();
        assertEq(vault.totalAssets(), deposit);

        // Request / score / adaptive credit (Python) → allocate + apply policy
        uint256 normalLeverage = fixture.readUint(".normal.maxLeverage");
        uint256 normalDaily = fixture.readUint(".normal.dailyLossLimit");

        vm.prank(admin);
        vault.allocateCredit(trader, normalCredit);
        _apply(".normal");

        vm.prank(admin);
        account.activate(normalCredit, normalLeverage, normalDaily);

        assertEq(account.creditLimit(), normalCredit);
        assertEq(account.maxLeverage(), fixture.readUint(".normal.maxLeverage"));
        assertTrue(policy.isCurrent(trader));
        assertEq(vault.allocatedOf(trader), normalCredit);
        assertEq(vault.utilizedOf(trader), 0);

        // Draw into the credit account (not the trader wallet)
        vm.prank(trader);
        account.draw(tradeSize);
        assertEq(usdc.balanceOf(trader), 0);
        assertEq(usdc.balanceOf(address(account)), tradeSize);
        assertEq(vault.utilizedOf(trader), tradeSize);

        // Trade approved under the Python NORMAL policy
        vm.prank(trader);
        uint256 id = account.executeTrade(btc, 0, tradeSize, leverage, BTC_PRICE);
        assertEq(account.exposureOf(btc), tradeSize);

        // PnL: +2% on the notional, then flatten
        vm.prank(trader);
        int256 pnl = account.closePosition(id, (BTC_PRICE * 102) / 100);
        assertGt(pnl, 0);
        assertEq(account.exposureOf(btc), 0);

        // Market shock → Python HIGH policy → vault allocation follows current credit
        uint256 shockCredit = fixture.readUint(".shock.creditLimit");
        _apply(".shock");
        _releaseTo(shockCredit);

        IKredxoRiskPolicy.Policy memory shocked = policy.policyOf(trader);
        assertEq(shocked.creditLimit, shockCredit);
        assertEq(shocked.riskLevel, uint8(fixture.readUint(".shock.riskLevel")));
        assertLt(shockCredit, normalCredit);
        assertLt(fixture.readUint(".shock.btcLimit"), tradeSize);
        assertEq(account.creditLimit(), shockCredit);

        // Same size that worked now reverts onchain
        vm.expectRevert(abi.encodeWithSelector(KredxoTradeRejected.selector, account.REASON_EXPOSURE()));
        vm.prank(trader);
        account.executeTrade(btc, 0, tradeSize, leverage, BTC_PRICE);

        // Recovery: Python NORMAL policy again, trade works
        _apply(".normal");
        uint256 missing = normalCredit - vault.allocatedOf(trader);
        if (missing > 0) {
            vm.prank(admin);
            vault.allocateCredit(trader, missing);
        }
        assertEq(account.creditLimit(), normalCredit);

        vm.prank(trader);
        account.executeTrade(btc, 0, tradeSize, leverage, BTC_PRICE);
        assertEq(account.exposureOf(btc), tradeSize);
    }

    function _apply(string memory key) internal {
        address[] memory markets = new address[](2);
        uint256[] memory limits = new uint256[](2);
        markets[0] = btc;
        markets[1] = eth;
        limits[0] = fixture.readUint(string.concat(key, ".btcLimit"));
        limits[1] = fixture.readUint(string.concat(key, ".ethLimit"));
        uint256 credit = fixture.readUint(string.concat(key, ".creditLimit"));
        uint256 leverage = fixture.readUint(string.concat(key, ".maxLeverage"));
        uint256 daily = fixture.readUint(string.concat(key, ".dailyLossLimit"));
        uint8 level = uint8(fixture.readUint(string.concat(key, ".riskLevel")));

        vm.prank(admin);
        controller.applyPolicy(
            trader, credit, leverage, daily, block.timestamp, block.timestamp + 1 days, level, markets, limits
        );
    }

    function _releaseTo(uint256 target) internal {
        uint256 allocated = vault.allocatedOf(trader);
        uint256 utilized = vault.utilizedOf(trader);
        if (allocated <= target) return;
        uint256 unused = allocated - utilized;
        uint256 releaseAmt = allocated - target;
        if (releaseAmt > unused) releaseAmt = unused;
        if (releaseAmt == 0) return;
        vm.prank(admin);
        vault.releaseCredit(trader, releaseAmt);
    }
}
