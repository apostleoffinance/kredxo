// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import {KredxoUnauthorized} from "../src/KredxoErrors.sol";
import {IKredxoRiskPolicy} from "../src/IKredxoRiskPolicy.sol";
import {KredxoDeploy} from "../script/KredxoDeploy.sol";

contract DeployTest is Test {
    address internal admin = makeAddr("admin");
    address internal trader = 0x83000000000000000000000000000000000009A2;
    address internal stranger = makeAddr("stranger");

    function test_deploysInProtocolOrderAndConfigures() public {
        vm.startPrank(admin);
        KredxoDeploy.Bundle memory d = KredxoDeploy.run(admin, trader, address(0), address(0), address(0));
        vm.stopPrank();

        assertEq(d.vault.REGISTRY(), address(d.registry));
        assertEq(address(d.vault.USDC()), d.usdc);
        assertEq(d.vault.riskPolicy(), address(d.policy));
        assertEq(d.vault.accountOf(trader), address(d.account));

        assertEq(d.policy.controller(), address(d.controller));
        assertEq(address(d.controller.POLICY()), address(d.policy));
        assertTrue(d.controller.hasRole(d.controller.RISK_CONTROLLER_ROLE(), admin));

        assertEq(d.account.VAULT(), address(d.vault));
        assertEq(d.account.TRADER(), trader);
        assertEq(d.account.riskPolicy(), address(d.policy));

        assertEq(d.settlement.REGISTRY(), address(d.registry));
        assertEq(d.settlement.VAULT(), address(d.vault));
        assertEq(d.settlement.USDC(), d.usdc);
        assertEq(d.settlement.venue(), address(d.account));
        assertEq(d.settlement.marketOf(d.settlement.BTC()), KredxoDeploy.BTC_MARKET);
        assertEq(d.settlement.marketOf(d.settlement.ETH()), KredxoDeploy.ETH_MARKET);
        assertEq(d.settlement.PHASE(), 15);
    }

    function test_officialTestnetUsdcIsConfiguredWhenProvided() public {
        vm.startPrank(admin);
        KredxoDeploy.Bundle memory d =
            KredxoDeploy.run(admin, trader, KredxoDeploy.MONAD_TESTNET_USDC, address(0), address(0));
        vm.stopPrank();
        assertEq(d.usdc, KredxoDeploy.MONAD_TESTNET_USDC);
        assertEq(address(d.vault.USDC()), KredxoDeploy.MONAD_TESTNET_USDC);
        assertEq(d.settlement.USDC(), KredxoDeploy.MONAD_TESTNET_USDC);
    }

    function test_strangerCannotRetargetVenueOrMarkets() public {
        vm.startPrank(admin);
        KredxoDeploy.Bundle memory d = KredxoDeploy.run(admin, trader, address(0), address(0), address(0));
        vm.stopPrank();

        bytes32 btc = d.settlement.BTC();
        assertFalse(d.settlement.hasRole(d.settlement.DEFAULT_ADMIN_ROLE(), stranger));

        vm.startPrank(stranger);
        vm.expectRevert();
        d.settlement.setVenue(stranger);
        vm.expectRevert();
        d.settlement.setMarket(btc, stranger);
        vm.stopPrank();
    }

    function test_onlyControllerWritesAfterDeploy() public {
        vm.startPrank(admin);
        KredxoDeploy.Bundle memory d = KredxoDeploy.run(admin, trader, address(0), address(0), address(0));
        vm.stopPrank();

        address[] memory markets = new address[](1);
        uint256[] memory limits = new uint256[](1);
        markets[0] = d.btc;
        limits[0] = 1;
        IKredxoRiskPolicy.Policy memory next = IKredxoRiskPolicy.Policy({
            creditLimit: 1,
            maxLeverage: 1,
            dailyLossLimit: 1,
            validFrom: block.timestamp,
            validUntil: block.timestamp + 1,
            riskLevel: 1,
            active: true
        });

        vm.expectRevert(KredxoUnauthorized.selector);
        vm.prank(stranger);
        d.policy.write(trader, next, markets, limits);
    }
}
