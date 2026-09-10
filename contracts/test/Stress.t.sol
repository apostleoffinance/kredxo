// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {KredxoTradeRejected} from "../src/KredxoErrors.sol";
import {KredxoRegistry} from "../src/KredxoRegistry.sol";
import {KredxoCreditVault} from "../src/KredxoCreditVault.sol";
import {KredxoRiskController} from "../src/KredxoRiskController.sol";
import {KredxoRiskPolicy} from "../src/KredxoRiskPolicy.sol";
import {KredxoTradingAccount} from "../src/KredxoTradingAccount.sol";
import {MockUSDC} from "./mocks/MockUSDC.sol";

/// @notice Phase 12 sitting: approve → shock → reject → HIGH → ELEVATED → NORMAL.
contract StressTest is Test {
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
        fixture = vm.readFile(string.concat(vm.projectRoot(), "/testdata/stress.json"));

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
    }

    function test_approveShockRejectRecoverInOneSitting() public {
        uint256 tradeSize = fixture.readUint(".tradeSize");
        uint256 leverage = fixture.readUint(".leverage");
        uint256 normalCredit = fixture.readUint(".normal.creditLimit");
        uint256 shockCredit = fixture.readUint(".shock.creditLimit");
        uint256 elevatedCredit = fixture.readUint(".elevated.creditLimit");

        uint256 normalLev = fixture.readUint(".normal.maxLeverage");
        uint256 normalDaily = fixture.readUint(".normal.dailyLossLimit");
        vm.prank(admin);
        vault.allocateCredit(trader, normalCredit);
        _apply(".normal");
        vm.prank(admin);
        account.activate(normalCredit, normalLev, normalDaily);

        vm.prank(trader);
        account.draw(tradeSize);

        vm.prank(trader);
        uint256 id = account.executeTrade(btc, 0, tradeSize, leverage, BTC_PRICE);
        vm.prank(trader);
        account.closePosition(id, BTC_PRICE);

        _apply(".shock");
        assertEq(account.creditLimit(), shockCredit);
        assertLt(shockCredit, normalCredit);
        assertLt(fixture.readUint(".shock.btcLimit"), tradeSize);

        vm.expectRevert(abi.encodeWithSelector(KredxoTradeRejected.selector, account.REASON_EXPOSURE()));
        vm.prank(trader);
        account.executeTrade(btc, 0, tradeSize, leverage, BTC_PRICE);

        _apply(".elevated");
        assertEq(account.creditLimit(), elevatedCredit);
        assertGt(elevatedCredit, shockCredit);
        assertLt(elevatedCredit, normalCredit);
        assertEq(uint256(policy.policyOf(trader).riskLevel), fixture.readUint(".elevated.riskLevel"));

        _apply(".normal");
        assertEq(account.creditLimit(), normalCredit);
        assertEq(uint256(policy.policyOf(trader).riskLevel), fixture.readUint(".normal.riskLevel"));

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
        uint256 lev = fixture.readUint(string.concat(key, ".maxLeverage"));
        uint256 daily = fixture.readUint(string.concat(key, ".dailyLossLimit"));
        uint8 level = uint8(fixture.readUint(string.concat(key, ".riskLevel")));
        vm.prank(admin);
        controller.applyPolicy(
            trader, credit, lev, daily, block.timestamp, block.timestamp + 1 days, level, markets, limits
        );
    }
}
