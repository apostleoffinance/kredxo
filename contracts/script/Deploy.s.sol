// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {KredxoDeploy} from "./KredxoDeploy.sol";

/// @notice Broadcasts the Phase 15 stack to Monad. Caller is admin.
contract Deploy is Script {
    function run() external {
        address admin = vm.envOr("KREDXO_ADMIN", msg.sender);
        address trader = _envAddress("KREDXO_TRADER");
        if (trader == address(0)) {
            trader = _envAddress("DEMO_WALLET");
        }
        if (trader == address(0)) trader = admin;

        address usdc = _envAddress("USDC_ADDRESS");
        if (usdc == address(0) && vm.envOr("DEPLOY_MOCK_USDC", false)) {
            usdc = address(0);
        } else if (usdc == address(0)) {
            usdc = KredxoDeploy.MONAD_TESTNET_USDC;
        }

        address btc = _envAddress("BTC_MARKET");
        address eth = _envAddress("ETH_MARKET");

        vm.startBroadcast();
        if (admin != msg.sender) {
            revert("KREDXO_ADMIN must be the broadcaster");
        }
        KredxoDeploy.Bundle memory d = KredxoDeploy.run(admin, trader, usdc, btc, eth);
        vm.stopBroadcast();

        _log(d);
        _write(d);
    }

    function _envAddress(string memory key) internal view returns (address value) {
        try vm.envAddress(key) returns (address found) {
            return found;
        } catch {
            return address(0);
        }
    }

    function _log(KredxoDeploy.Bundle memory d) internal pure {
        console2.log("USDC", d.usdc);
        console2.log("KredxoRegistry", address(d.registry));
        console2.log("KredxoCreditVault", address(d.vault));
        console2.log("KredxoRiskPolicy", address(d.policy));
        console2.log("KredxoRiskController", address(d.controller));
        console2.log("KredxoTradingAccount", address(d.account));
        console2.log("KredxoSettlement", address(d.settlement));
        console2.log("BTC", d.btc);
        console2.log("ETH", d.eth);
        console2.log("trader", d.trader);
    }

    function _write(KredxoDeploy.Bundle memory d) internal {
        string memory obj = "deploy";
        vm.serializeUint(obj, "chainId", 10143);
        vm.serializeString(obj, "network", "monad-testnet");
        vm.serializeAddress(obj, "usdc", d.usdc);
        vm.serializeAddress(obj, "registry", address(d.registry));
        vm.serializeAddress(obj, "vault", address(d.vault));
        vm.serializeAddress(obj, "policy", address(d.policy));
        vm.serializeAddress(obj, "controller", address(d.controller));
        vm.serializeAddress(obj, "tradingAccount", address(d.account));
        vm.serializeAddress(obj, "settlement", address(d.settlement));
        vm.serializeAddress(obj, "btc", d.btc);
        vm.serializeAddress(obj, "eth", d.eth);
        string memory json = vm.serializeAddress(obj, "trader", d.trader);
        vm.writeJson(json, "deployments/monad-testnet.json");
    }
}
