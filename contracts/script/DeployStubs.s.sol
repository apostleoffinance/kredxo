// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {KredxoRegistry} from "../src/KredxoRegistry.sol";
import {KredxoCreditVault} from "../src/KredxoCreditVault.sol";
import {KredxoTradingAccount} from "../src/KredxoTradingAccount.sol";
import {MockUSDC} from "../test/mocks/MockUSDC.sol";

/// @dev Local/anvil wiring. Do not use for Monad deployment until Phase 15.
contract DeployStubs is Script {
    function run() external {
        address admin = vm.envOr("KREDXO_ADMIN", msg.sender);
        address trader = vm.envOr("KREDXO_TRADER", admin);

        vm.startBroadcast();
        address usdc = vm.envOr("USDC", address(0));
        if (usdc == address(0)) {
            usdc = address(new MockUSDC());
        }
        KredxoRegistry registry = new KredxoRegistry(admin);
        KredxoCreditVault vault = new KredxoCreditVault(address(registry), usdc, admin);
        KredxoTradingAccount account =
            new KredxoTradingAccount(address(registry), address(vault), trader, admin);
        vault.setTradingAccount(trader, address(account));
        vm.stopBroadcast();

        console2.log("USDC", usdc);
        console2.log("KredxoRegistry", address(registry));
        console2.log("KredxoCreditVault", address(vault));
        console2.log("KredxoTradingAccount", address(account));
    }
}
