// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {KredxoDeploy} from "../script/KredxoDeploy.sol";
import {KredxoSeed} from "../script/KredxoSeed.sol";
import {MockUSDC} from "./mocks/MockUSDC.sol";

contract SeedDemoTest is Test {
    address internal admin = makeAddr("admin");
    address internal trader = 0x83000000000000000000000000000000000009A2;

    function test_demoLpDeposits100kAndIssues50kCredit() public {
        vm.startPrank(admin);
        KredxoDeploy.Bundle memory d = KredxoDeploy.run(admin, trader, address(0), address(0), address(0));
        MockUSDC(d.usdc).mint(admin, KredxoSeed.TARGET_DEPOSIT);

        KredxoSeed.Result memory out = KredxoSeed.run(
            IERC20(d.usdc),
            d.vault,
            d.controller,
            d.account,
            trader,
            KredxoSeed.TARGET_DEPOSIT,
            KredxoSeed.TARGET_CREDIT
        );
        vm.stopPrank();

        assertEq(out.deposited, 100_000 * 1e6);
        assertEq(out.credit, 50_000 * 1e6);
        assertEq(d.vault.totalAssets(), 100_000 * 1e6);
        assertEq(d.vault.allocatedOf(trader), 50_000 * 1e6);
        assertEq(d.vault.utilizedCredit(), 0);
        assertEq(d.account.creditLimit(), 50_000 * 1e6);
        assertEq(d.account.maxLeverage(), 5e18);
        assertTrue(d.account.active());
        assertTrue(d.policy.isCurrent(trader));
        assertEq(d.policy.positionLimit(trader, d.btc), 25_000 * 1e6);
    }

    function test_faucetSizedDepositStillIssuesCredit() public {
        vm.startPrank(admin);
        KredxoDeploy.Bundle memory d = KredxoDeploy.run(admin, trader, address(0), address(0), address(0));
        MockUSDC(d.usdc).mint(admin, 20 * 1e6);

        KredxoSeed.Result memory out = KredxoSeed.run(
            IERC20(d.usdc), d.vault, d.controller, d.account, trader, 20 * 1e6, 50_000 * 1e6
        );
        vm.stopPrank();

        assertEq(out.deposited, 20 * 1e6);
        assertEq(out.credit, 20 * 1e6);
        assertEq(d.vault.allocatedOf(trader), 20 * 1e6);
        assertEq(d.account.creditLimit(), 20 * 1e6);
        assertTrue(d.account.active());
    }

    function test_seededAccountCanApproveTenKBtc() public {
        vm.startPrank(admin);
        KredxoDeploy.Bundle memory d = KredxoDeploy.run(admin, trader, address(0), address(0), address(0));
        MockUSDC(d.usdc).mint(admin, KredxoSeed.TARGET_DEPOSIT);
        KredxoSeed.run(
            IERC20(d.usdc),
            d.vault,
            d.controller,
            d.account,
            trader,
            KredxoSeed.TARGET_DEPOSIT,
            KredxoSeed.TARGET_CREDIT
        );
        vm.stopPrank();

        vm.prank(trader);
        d.account.draw(10_000 * 1e6);
        vm.prank(trader);
        uint256 id = d.account.executeTrade(d.btc, 0, 10_000 * 1e6, 2e18, 60_000e18);
        assertEq(id, 1);
        assertEq(d.account.exposureOf(d.btc), 10_000 * 1e6);
    }
}
