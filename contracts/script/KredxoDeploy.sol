// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {KredxoRegistry} from "../src/KredxoRegistry.sol";
import {KredxoCreditVault} from "../src/KredxoCreditVault.sol";
import {KredxoRiskController} from "../src/KredxoRiskController.sol";
import {KredxoRiskPolicy} from "../src/KredxoRiskPolicy.sol";
import {KredxoTradingAccount} from "../src/KredxoTradingAccount.sol";
import {KredxoSettlement} from "../src/KredxoSettlement.sol";
import {MockUSDC} from "../test/mocks/MockUSDC.sol";

/// @notice Registry → Vault → Risk Policy → Risk Controller → Trading Account → Settlement.
library KredxoDeploy {
    address internal constant BTC_MARKET = 0x0000000000000000000000000000000000000B7C;
    address internal constant ETH_MARKET = 0x0000000000000000000000000000000000000e7C;
    /// @dev Official Monad Testnet USDC (tokenlist-testnet.json).
    address internal constant MONAD_TESTNET_USDC = 0x534b2f3A21130d7a60830c2Df862319e593943A3;

    struct Bundle {
        address usdc;
        KredxoRegistry registry;
        KredxoCreditVault vault;
        KredxoRiskPolicy policy;
        KredxoRiskController controller;
        KredxoTradingAccount account;
        KredxoSettlement settlement;
        address btc;
        address eth;
        address trader;
    }

    function run(address admin, address trader, address usdc, address btc, address eth)
        internal
        returns (Bundle memory b)
    {
        if (usdc == address(0)) {
            usdc = address(new MockUSDC());
        }
        if (btc == address(0)) btc = BTC_MARKET;
        if (eth == address(0)) eth = ETH_MARKET;

        b.usdc = usdc;
        b.trader = trader;
        b.btc = btc;
        b.eth = eth;
        b.registry = new KredxoRegistry(admin);
        b.vault = new KredxoCreditVault(address(b.registry), usdc, admin);
        b.policy = new KredxoRiskPolicy(admin);
        b.controller = new KredxoRiskController(address(b.policy), admin);
        b.account = new KredxoTradingAccount(address(b.registry), address(b.vault), trader, admin);
        b.settlement = new KredxoSettlement(address(b.registry), address(b.vault), usdc, admin);

        b.policy.setController(address(b.controller));
        b.account.setRiskPolicy(address(b.policy));
        b.vault.setRiskPolicy(address(b.policy));
        b.vault.setTradingAccount(trader, address(b.account));
        b.settlement.setVenue(address(b.account));
        b.settlement.setMarket(b.settlement.BTC(), btc);
        b.settlement.setMarket(b.settlement.ETH(), eth);
    }
}
