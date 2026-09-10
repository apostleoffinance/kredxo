// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import {
    KredxoInsufficientAllocation,
    KredxoInsufficientLiquidity,
    KredxoInsufficientUtilization,
    KredxoZeroAddress,
    KredxoZeroAmount
} from "../src/KredxoErrors.sol";
import {KredxoRegistry} from "../src/KredxoRegistry.sol";
import {KredxoCreditVault} from "../src/KredxoCreditVault.sol";
import {MockUSDC} from "./mocks/MockUSDC.sol";

contract CreditVaultTest is Test {
    uint256 internal constant USD = 1e6;

    MockUSDC internal usdc;
    KredxoRegistry internal registry;
    KredxoCreditVault internal vault;

    address internal admin = makeAddr("admin");
    address internal lp = makeAddr("lp");
    address internal lp2 = makeAddr("lp2");
    address internal trader = makeAddr("trader");
    address internal stranger = makeAddr("stranger");

    function setUp() public {
        usdc = new MockUSDC();
        registry = new KredxoRegistry(admin);
        vault = new KredxoCreditVault(address(registry), address(usdc), admin);

        usdc.mint(lp, 1_000_000 * USD);
        usdc.mint(lp2, 1_000_000 * USD);
        usdc.mint(trader, 1_000_000 * USD);
    }

    function _deposit(address from, uint256 assets) internal returns (uint256 shares) {
        vm.startPrank(from);
        usdc.approve(address(vault), assets);
        shares = vault.deposit(assets);
        vm.stopPrank();
    }

    function test_depositMintsOneToOneOnEmptyVault() public {
        uint256 shares = _deposit(lp, 100_000 * USD);

        assertEq(shares, 100_000 * USD);
        assertEq(vault.totalShares(), 100_000 * USD);
        assertEq(vault.totalAssets(), 100_000 * USD);
        assertEq(vault.availableLiquidity(), 100_000 * USD);
        assertEq(vault.allocatedCredit(), 0);
        assertEq(vault.utilizedCredit(), 0);
        assertEq(usdc.balanceOf(address(vault)), 100_000 * USD);
        assertEq(vault.balanceOf(lp), 100_000 * USD);
    }

    function test_allocateDoesNotMoveUsdcOrCreateUtilization() public {
        _deposit(lp, 100_000 * USD);

        vm.prank(admin);
        vault.allocateCredit(trader, 50_000 * USD);

        assertEq(vault.totalAssets(), 100_000 * USD);
        assertEq(vault.allocatedCredit(), 50_000 * USD);
        assertEq(vault.allocatedOf(trader), 50_000 * USD);
        assertEq(vault.utilizedCredit(), 0);
        assertEq(vault.utilizedOf(trader), 0);
        assertEq(vault.availableLiquidity(), 50_000 * USD);
        assertEq(usdc.balanceOf(address(vault)), 100_000 * USD);
        assertEq(usdc.balanceOf(trader), 1_000_000 * USD);
    }

    function test_cannotAllocateMoreThanAvailable() public {
        _deposit(lp, 100_000 * USD);
        vm.prank(admin);
        vault.allocateCredit(trader, 50_000 * USD);

        vm.prank(admin);
        vm.expectRevert(KredxoInsufficientLiquidity.selector);
        vault.allocateCredit(trader, 50_000 * USD + 1);
    }

    function test_unauthorizedAllocateReverts() public {
        _deposit(lp, 100_000 * USD);
        vm.prank(stranger);
        vm.expectRevert();
        vault.allocateCredit(trader, 1 * USD);
    }

    function test_withdrawLimitedToUnallocatedLiquidity() public {
        _deposit(lp, 100_000 * USD);
        vm.prank(admin);
        vault.allocateCredit(trader, 50_000 * USD);

        vm.prank(lp);
        vm.expectRevert(KredxoInsufficientLiquidity.selector);
        vault.withdraw(60_000 * USD);

        vm.prank(lp);
        uint256 assets = vault.withdraw(50_000 * USD);

        assertEq(assets, 50_000 * USD);
        assertEq(vault.totalAssets(), 50_000 * USD);
        assertEq(vault.allocatedCredit(), 50_000 * USD);
        assertEq(vault.availableLiquidity(), 0);
        assertEq(vault.utilizedCredit(), 0);
    }

    function test_utilizeMovesUsdcAndKeepsNav() public {
        _deposit(lp, 100_000 * USD);
        vm.prank(admin);
        vault.allocateCredit(trader, 50_000 * USD);

        vm.prank(admin);
        vault.utilizeCredit(trader, trader, 15_000 * USD);

        assertEq(vault.totalAssets(), 100_000 * USD);
        assertEq(vault.allocatedCredit(), 50_000 * USD);
        assertEq(vault.utilizedCredit(), 15_000 * USD);
        assertEq(vault.utilizedOf(trader), 15_000 * USD);
        assertEq(vault.availableLiquidity(), 50_000 * USD);
        assertEq(usdc.balanceOf(address(vault)), 85_000 * USD);
        assertEq(usdc.balanceOf(trader), 1_015_000 * USD);
    }

    function test_cannotUtilizeMoreThanUnusedAllocation() public {
        _deposit(lp, 100_000 * USD);
        vm.prank(admin);
        vault.allocateCredit(trader, 50_000 * USD);

        vm.prank(admin);
        vm.expectRevert(KredxoInsufficientAllocation.selector);
        vault.utilizeCredit(trader, trader, 50_000 * USD + 1);
    }

    function test_repayRestoresIdleCash() public {
        _deposit(lp, 100_000 * USD);
        vm.startPrank(admin);
        vault.allocateCredit(trader, 50_000 * USD);
        vault.utilizeCredit(trader, trader, 15_000 * USD);
        vm.stopPrank();

        vm.startPrank(trader);
        usdc.approve(address(vault), 15_000 * USD);
        vault.repay(trader, 15_000 * USD);
        vm.stopPrank();

        assertEq(vault.utilizedCredit(), 0);
        assertEq(vault.utilizedOf(trader), 0);
        assertEq(vault.allocatedCredit(), 50_000 * USD);
        assertEq(vault.totalAssets(), 100_000 * USD);
        assertEq(usdc.balanceOf(address(vault)), 100_000 * USD);
    }

    function test_cannotRepayMoreThanUtilized() public {
        _deposit(lp, 100_000 * USD);
        vm.prank(admin);
        vault.allocateCredit(trader, 50_000 * USD);

        vm.startPrank(trader);
        usdc.approve(address(vault), 1 * USD);
        vm.expectRevert(KredxoInsufficientUtilization.selector);
        vault.repay(trader, 1 * USD);
        vm.stopPrank();
    }

    function test_releaseOnlyUnusedAllocation() public {
        _deposit(lp, 100_000 * USD);
        vm.startPrank(admin);
        vault.allocateCredit(trader, 50_000 * USD);
        vault.utilizeCredit(trader, trader, 15_000 * USD);

        vm.expectRevert(KredxoInsufficientAllocation.selector);
        vault.releaseCredit(trader, 40_000 * USD);

        vault.releaseCredit(trader, 35_000 * USD);
        vm.stopPrank();

        assertEq(vault.allocatedOf(trader), 15_000 * USD);
        assertEq(vault.allocatedCredit(), 15_000 * USD);
        assertEq(vault.utilizedCredit(), 15_000 * USD);
        assertEq(vault.availableLiquidity(), 85_000 * USD);
    }

    function test_secondLpGetsProportionalShares() public {
        _deposit(lp, 100_000 * USD);
        uint256 shares = _deposit(lp2, 50_000 * USD);

        assertEq(shares, 50_000 * USD);
        assertEq(vault.totalShares(), 150_000 * USD);
        assertEq(vault.totalAssets(), 150_000 * USD);
        assertEq(vault.balanceOf(lp2), 50_000 * USD);
    }

    function test_zeroAmountAndZeroAddressRevert() public {
        _deposit(lp, 100_000 * USD);

        vm.prank(lp);
        vm.expectRevert(KredxoZeroAmount.selector);
        vault.deposit(0);

        vm.prank(lp);
        vm.expectRevert(KredxoZeroAmount.selector);
        vault.withdraw(0);

        vm.startPrank(admin);
        vm.expectRevert(KredxoZeroAddress.selector);
        vault.allocateCredit(address(0), 1 * USD);
        vm.expectRevert(KredxoZeroAmount.selector);
        vault.allocateCredit(trader, 0);
        vm.stopPrank();
    }

    function test_constructorRejectsZeroAddresses() public {
        vm.expectRevert(KredxoZeroAddress.selector);
        new KredxoCreditVault(address(0), address(usdc), admin);
        vm.expectRevert(KredxoZeroAddress.selector);
        new KredxoCreditVault(address(registry), address(0), admin);
        vm.expectRevert(KredxoZeroAddress.selector);
        new KredxoCreditVault(address(registry), address(usdc), address(0));
    }
}
