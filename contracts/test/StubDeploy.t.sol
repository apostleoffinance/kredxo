// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import {KredxoZeroAddress} from "../src/KredxoErrors.sol";
import {KredxoRegistry} from "../src/KredxoRegistry.sol";
import {KredxoCreditVault} from "../src/KredxoCreditVault.sol";
import {KredxoRiskController} from "../src/KredxoRiskController.sol";
import {KredxoRiskPolicy} from "../src/KredxoRiskPolicy.sol";
import {KredxoTradingAccount} from "../src/KredxoTradingAccount.sol";
import {MockUSDC} from "./mocks/MockUSDC.sol";

contract StubDeployTest is Test {
    function test_registryRejectsZeroAdmin() public {
        vm.expectRevert(KredxoZeroAddress.selector);
        new KredxoRegistry(address(0));
    }

    function test_stubsWireTogether() public {
        address admin = makeAddr("admin");
        address trader = makeAddr("trader");

        MockUSDC usdc = new MockUSDC();
        KredxoRegistry registry = new KredxoRegistry(admin);
        KredxoCreditVault vault = new KredxoCreditVault(address(registry), address(usdc), admin);
        KredxoTradingAccount account =
            new KredxoTradingAccount(address(registry), address(vault), trader, admin);
        KredxoRiskPolicy policy = new KredxoRiskPolicy(admin);
        KredxoRiskController controller = new KredxoRiskController(address(policy), admin);

        vm.prank(admin);
        policy.setController(address(controller));

        assertEq(registry.NAME(), "KredxoRegistry");
        assertEq(registry.PHASE(), 1);
        assertTrue(registry.hasRole(registry.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(registry.hasRole(registry.ADMIN_ROLE(), admin));

        assertEq(vault.NAME(), "KredxoCreditVault");
        assertEq(vault.PHASE(), 10);
        assertEq(vault.REGISTRY(), address(registry));
        assertEq(address(vault.USDC()), address(usdc));

        assertEq(account.NAME(), "KredxoTradingAccount");
        assertEq(account.PHASE(), 4);
        assertEq(account.REGISTRY(), address(registry));
        assertEq(account.VAULT(), address(vault));
        assertEq(account.TRADER(), trader);

        assertEq(policy.NAME(), "KredxoRiskPolicy");
        assertEq(policy.PHASE(), 8);
        assertEq(controller.NAME(), "KredxoRiskController");
        assertEq(controller.PHASE(), 8);
        assertEq(address(controller.POLICY()), address(policy));
        assertEq(policy.controller(), address(controller));
        assertTrue(controller.hasRole(controller.RISK_CONTROLLER_ROLE(), admin));
    }
}
