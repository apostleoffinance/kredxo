// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {KredxoCreditVault} from "../src/KredxoCreditVault.sol";
import {KredxoRiskController} from "../src/KredxoRiskController.sol";
import {KredxoTradingAccount} from "../src/KredxoTradingAccount.sol";

/// @notice LP deposit → allocate → NORMAL policy → activate. Phase 16 demo seed.
library KredxoSeed {
    uint256 internal constant USD = 1e6;
    uint256 internal constant WAD = 1e18;
    uint256 internal constant TARGET_DEPOSIT = 100_000 * USD;
    uint256 internal constant TARGET_CREDIT = 50_000 * USD;

    address internal constant BTC_MARKET = 0x0000000000000000000000000000000000000B7C;
    address internal constant ETH_MARKET = 0x0000000000000000000000000000000000000e7C;

    struct Result {
        uint256 deposited;
        uint256 credit;
        uint256 btcLimit;
        uint256 ethLimit;
        uint256 dailyLoss;
    }

    function run(
        IERC20 usdc,
        KredxoCreditVault vault,
        KredxoRiskController controller,
        KredxoTradingAccount account,
        address trader,
        uint256 deposit,
        uint256 credit
    ) internal returns (Result memory out) {
        if (deposit == 0) revert("KredxoSeed: zero deposit");
        if (credit == 0 || credit > deposit) credit = deposit > TARGET_CREDIT ? TARGET_CREDIT : deposit;

        usdc.approve(address(vault), deposit);
        vault.deposit(deposit);
        vault.allocateCredit(trader, credit);

        uint256 daily = (credit * 4) / 100;
        if (daily == 0) daily = 1;
        uint256 btc = (credit * 50) / 100;
        uint256 eth = (credit * 30) / 100;
        if (btc == 0) btc = 1;
        if (eth == 0) eth = 1;

        address[] memory markets = new address[](2);
        uint256[] memory limits = new uint256[](2);
        markets[0] = BTC_MARKET;
        markets[1] = ETH_MARKET;
        limits[0] = btc;
        limits[1] = eth;

        controller.applyPolicy(
            trader, credit, 5 * WAD, daily, block.timestamp, block.timestamp + 365 days, 1, markets, limits
        );
        account.activate(credit, 5 * WAD, daily);

        out = Result({deposited: deposit, credit: credit, btcLimit: btc, ethLimit: eth, dailyLoss: daily});
    }
}
