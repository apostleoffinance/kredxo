// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import {KredxoRegistry} from "../src/KredxoRegistry.sol";
import {KredxoCreditVault} from "../src/KredxoCreditVault.sol";
import {KredxoRiskController} from "../src/KredxoRiskController.sol";
import {KredxoRiskPolicy} from "../src/KredxoRiskPolicy.sol";
import {KredxoTradingAccount} from "../src/KredxoTradingAccount.sol";
import {MockUSDC} from "./mocks/MockUSDC.sol";

contract InterestTest is Test {
    uint256 internal constant USD = 1e6;
    uint256 internal constant WAD = 1e18;

    MockUSDC internal usdc;
    KredxoCreditVault internal vault;
    KredxoRiskPolicy internal policy;
    KredxoRiskController internal controller;

    address internal admin = makeAddr("admin");
    address internal lp = makeAddr("lp");
    address internal trader = makeAddr("trader");
    address internal btc = makeAddr("BTC");

    function setUp() public {
        usdc = new MockUSDC();
        KredxoRegistry registry = new KredxoRegistry(admin);
        vault = new KredxoCreditVault(address(registry), address(usdc), admin);
        policy = new KredxoRiskPolicy(admin);
        controller = new KredxoRiskController(address(policy), admin);

        vm.prank(admin);
        policy.setController(address(controller));
        vm.prank(admin);
        vault.setRiskPolicy(address(policy));

        usdc.mint(lp, 1_000_000 * USD);
        usdc.mint(trader, 1_000_000 * USD);
        vm.startPrank(lp);
        usdc.approve(address(vault), 100_000 * USD);
        vault.deposit(100_000 * USD);
        vm.stopPrank();
    }

    function _apply(uint8 level) internal {
        address[] memory markets = new address[](1);
        uint256[] memory limits = new uint256[](1);
        markets[0] = btc;
        limits[0] = 25_000 * USD;
        vm.prank(admin);
        controller.applyPolicy(
            trader,
            50_000 * USD,
            5 * WAD,
            2_000 * USD,
            block.timestamp,
            block.timestamp + 365 days,
            level,
            markets,
            limits
        );
    }

    function test_lowIdleAprIs7_2Percent() public {
        _apply(policy.LEVEL_LOW());
        assertEq(vault.borrowApr(trader), 72e15);
    }

    function test_normalIdleAprIs8Percent() public {
        _apply(1);
        assertEq(vault.borrowApr(trader), 8e16);
    }

    function test_highHalfUtilAprIs14_5Percent() public {
        _apply(3);
        vm.startPrank(admin);
        vault.allocateCredit(trader, 50_000 * USD);
        vault.utilizeCredit(trader, trader, 50_000 * USD);
        vm.stopPrank();
        assertEq(vault.utilizationWad(), WAD / 2);
        assertEq(vault.borrowApr(trader), 145e15);
    }

    function test_utilizedCreditAccruesLpYield() public {
        _apply(1);
        uint256 shares = vault.balanceOf(lp);
        uint256 navBefore = vault.convertToAssets(shares);

        vm.startPrank(admin);
        vault.allocateCredit(trader, 50_000 * USD);
        vault.utilizeCredit(trader, trader, 20_000 * USD);
        vm.stopPrank();

        assertEq(vault.convertToAssets(shares), navBefore);

        vm.warp(block.timestamp + 365 days);
        uint256 interest = vault.accrueInterest(trader);

        assertGt(interest, 0);
        assertEq(interest, vault.interestOf(trader));
        assertGt(vault.totalAssets(), 100_000 * USD);
        assertGt(vault.convertToAssets(shares), navBefore);
        assertEq(vault.utilizedOf(trader), 20_000 * USD);
    }

    function test_repayPaysInterestThenPrincipal() public {
        _apply(1);
        vm.startPrank(admin);
        vault.allocateCredit(trader, 50_000 * USD);
        vault.utilizeCredit(trader, trader, 10_000 * USD);
        vm.stopPrank();

        vm.warp(block.timestamp + 365 days);
        uint256 interest = vault.pendingInterest(trader);
        assertGt(interest, 0);

        uint256 pay = interest + 1_000 * USD;
        vm.startPrank(trader);
        usdc.approve(address(vault), pay);
        vault.repay(trader, pay);
        vm.stopPrank();

        assertEq(vault.interestOf(trader), 0);
        assertEq(vault.interestAccrued(), 0);
        assertEq(vault.utilizedOf(trader), 9_000 * USD);
        assertEq(usdc.balanceOf(address(vault)), 90_000 * USD + pay);
    }

    function test_accountRepayTracksPrincipalAfterInterest() public {
        KredxoRegistry registry = KredxoRegistry(vault.REGISTRY());
        KredxoTradingAccount account =
            new KredxoTradingAccount(address(registry), address(vault), trader, admin);
        vm.prank(admin);
        vault.setTradingAccount(trader, address(account));
        vm.prank(admin);
        account.activate(50_000 * USD, 5 * WAD, 2_000 * USD);
        _apply(1);

        vm.prank(admin);
        vault.allocateCredit(trader, 50_000 * USD);
        vm.prank(trader);
        account.draw(10_000 * USD);

        vm.warp(block.timestamp + 365 days);
        uint256 interest = vault.pendingInterest(trader);
        uint256 pay = interest + 10_000 * USD;
        usdc.mint(address(account), interest);

        vm.prank(trader);
        account.repay(pay);

        assertEq(account.usedCredit(), 0);
        assertEq(vault.utilizedOf(trader), 0);
        assertEq(vault.interestOf(trader), 0);
        assertGt(vault.convertToAssets(vault.balanceOf(lp)), 100_000 * USD);
    }
}
