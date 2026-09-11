// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {KredxoCreditVault} from "../src/KredxoCreditVault.sol";
import {KredxoRiskController} from "../src/KredxoRiskController.sol";
import {KredxoTradingAccount} from "../src/KredxoTradingAccount.sol";
import {KredxoSeed} from "./KredxoSeed.sol";

/// @notice Broadcasts the Phase 16 demo seed. LP is the signer.
contract SeedDemo is Script {
    function run() external {
        address vault = vm.envAddress("CREDIT_VAULT_ADDRESS");
        address usdc = vm.envAddress("USDC_ADDRESS");
        address controller = vm.envAddress("RISK_CONTROLLER_ADDRESS");
        address account = vm.envAddress("TRADING_ACCOUNT_ADDRESS");
        address trader = _envAddress("KREDXO_TRADER");
        if (trader == address(0)) trader = _envAddress("DEMO_WALLET");
        if (trader == address(0)) revert("set DEMO_WALLET or KREDXO_TRADER");

        uint256 wantDeposit = vm.envOr("LP_DEPOSIT_USDC", KredxoSeed.TARGET_DEPOSIT);
        uint256 wantCredit = vm.envOr("CREDIT_LIMIT_USDC", KredxoSeed.TARGET_CREDIT);

        vm.startBroadcast();
        address lp = msg.sender;
        uint256 balance = IERC20(usdc).balanceOf(lp);
        uint256 deposit = wantDeposit <= balance ? wantDeposit : balance;
        if (deposit == 0) revert("KredxoSeed: LP has no USDC");

        KredxoSeed.Result memory out = KredxoSeed.run(
            IERC20(usdc),
            KredxoCreditVault(vault),
            KredxoRiskController(controller),
            KredxoTradingAccount(account),
            trader,
            deposit,
            wantCredit > deposit ? deposit : wantCredit
        );
        vm.stopBroadcast();

        console2.log("lp", lp);
        console2.log("deposited", out.deposited);
        console2.log("credit", out.credit);
        console2.log("btcLimit", out.btcLimit);
        console2.log("targetDeposit", KredxoSeed.TARGET_DEPOSIT);
        if (out.deposited < KredxoSeed.TARGET_DEPOSIT) {
            console2.log("note: deposited less than 100000 USDC; faucet balance was smaller");
        }
    }

    function _envAddress(string memory key) internal view returns (address value) {
        try vm.envAddress(key) returns (address found) {
            return found;
        } catch {
            return address(0);
        }
    }
}
