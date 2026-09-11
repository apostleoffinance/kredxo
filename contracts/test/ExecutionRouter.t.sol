// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import {
    KredxoActionNotAllowed,
    KredxoTradeRejected,
    KredxoUnauthorized,
    KredxoVenueNotAllowed,
    KredxoWrongAsset,
    KredxoWrongChain
} from "../src/KredxoErrors.sol";
import {KredxoExecutionRouter} from "../src/KredxoExecutionRouter.sol";
import {KredxoKuruAdapter} from "../src/KredxoKuruAdapter.sol";
import {KredxoPerplAdapter} from "../src/KredxoPerplAdapter.sol";
import {KredxoRegistry} from "../src/KredxoRegistry.sol";
import {KredxoCreditVault} from "../src/KredxoCreditVault.sol";
import {KredxoRiskController} from "../src/KredxoRiskController.sol";
import {KredxoRiskPolicy} from "../src/KredxoRiskPolicy.sol";
import {KredxoTradingAccount} from "../src/KredxoTradingAccount.sol";
import {KredxoVenues} from "../src/KredxoVenues.sol";
import {MockKuru} from "./mocks/MockKuru.sol";
import {MockPerpl} from "./mocks/MockPerpl.sol";
import {MockUSDC} from "./mocks/MockUSDC.sol";

contract ExecutionRouterTest is Test {
    uint256 internal constant USD = 1e6;
    uint256 internal constant WAD = 1e18;

    MockUSDC internal usdc;
    MockUSDC internal weth;
    MockPerpl internal perpl;
    MockKuru internal kuru;
    KredxoCreditVault internal vault;
    KredxoRiskPolicy internal policy;
    KredxoRiskController internal controller;
    KredxoTradingAccount internal account;
    KredxoExecutionRouter internal router;
    KredxoPerplAdapter internal perplAdapter;
    KredxoKuruAdapter internal kuruAdapter;

    address internal admin = makeAddr("admin");
    address internal lp = makeAddr("lp");
    address internal trader = makeAddr("trader");
    address internal stranger = makeAddr("stranger");
    address internal btc = address(uint160(0xb7c));

    function setUp() public {
        usdc = new MockUSDC();
        weth = new MockUSDC();
        perpl = new MockPerpl(address(usdc));
        kuru = new MockKuru(address(usdc), address(weth));

        KredxoRegistry registry = new KredxoRegistry(admin);
        vault = new KredxoCreditVault(address(registry), address(usdc), admin);
        account = new KredxoTradingAccount(address(registry), address(vault), trader, admin);
        policy = new KredxoRiskPolicy(admin);
        controller = new KredxoRiskController(address(policy), admin);

        vm.startPrank(admin);
        policy.setController(address(controller));
        account.setRiskPolicy(address(policy));
        vault.setTradingAccount(trader, address(account));
        vm.stopPrank();

        usdc.mint(lp, 1_000_000 * USD);
        vm.startPrank(lp);
        usdc.approve(address(vault), 100_000 * USD);
        vault.deposit(100_000 * USD);
        vm.stopPrank();

        vm.prank(admin);
        vault.allocateCredit(trader, 50_000 * USD);

        address[] memory markets = new address[](3);
        uint256[] memory limits = new uint256[](3);
        markets[0] = btc;
        markets[1] = KredxoVenues.PERPL_MARKET;
        markets[2] = KredxoVenues.KURU_MARKET;
        limits[0] = 15_000 * USD;
        limits[1] = 10_000 * USD;
        limits[2] = 5_000 * USD;
        vm.prank(admin);
        controller.applyPolicy(
            trader, 50_000 * USD, 5 * WAD, 2_000 * USD, block.timestamp, block.timestamp + 1 days, 1, markets, limits
        );

        vm.prank(admin);
        account.activate(50_000 * USD, 5 * WAD, 2_000 * USD);
        vm.prank(trader);
        account.draw(20_000 * USD);

        router = new KredxoExecutionRouter(address(account), address(policy), block.chainid, admin);
        perplAdapter = new KredxoPerplAdapter(address(router), address(perpl), block.chainid, address(usdc), address(usdc));
        kuruAdapter = new KredxoKuruAdapter(address(router), address(kuru), block.chainid, address(usdc), address(usdc));

        vm.startPrank(admin);
        account.setExecutionRouter(address(router));
        account.grantRole(account.OPERATOR_ROLE(), address(router));
        router.setAdapter(KredxoVenues.PERPL, address(perplAdapter), address(perpl));
        router.setAdapter(KredxoVenues.KURU, address(kuruAdapter), address(kuru));
        router.setAction(KredxoVenues.PERPL, KredxoVenues.OPEN_PERP, true);
        router.setAction(KredxoVenues.PERPL, KredxoVenues.CLOSE_PERP, true);
        router.setAction(KredxoVenues.KURU, KredxoVenues.SWAP, true);
        vm.stopPrank();
    }

    function test_directExecuteTradeStillWorks() public {
        vm.prank(trader);
        uint256 id = account.executeTrade(btc, 0, 1_000 * USD, 2 * WAD, 60_000 * WAD);
        assertEq(id, 1);
        assertEq(account.exposureOf(btc), 1_000 * USD);
    }

    function test_internalViaRouterOpensPosition() public {
        bytes memory data = abi.encode(btc, uint8(0), 2_000 * USD, 2 * WAD, 60_000 * WAD);
        vm.prank(trader);
        router.execute(KredxoVenues.INTERNAL, KredxoVenues.OPEN_PERP, data);
        assertEq(account.exposureOf(btc), 2_000 * USD);
    }

    function test_perplOpenPaysVenueAndRecords() public {
        uint256 before = usdc.balanceOf(address(account));
        bytes memory data = abi.encode(btc, uint8(0), 4_000 * USD, 2 * WAD, 60_000 * WAD);
        vm.prank(trader);
        router.execute(KredxoVenues.PERPL, KredxoVenues.OPEN_PERP, data);
        assertEq(router.exposureOf(trader, KredxoVenues.PERPL), 4_000 * USD);
        assertEq(usdc.balanceOf(address(perpl)), 2_000 * USD);
        assertEq(usdc.balanceOf(address(account)), before - 2_000 * USD);
        assertEq(perpl.lastId(), 1);
    }

    function test_kuruSwapSendsOutputToAccount() public {
        bytes memory data = abi.encode(address(weth), 1_000 * USD, uint256(1));
        vm.prank(trader);
        router.execute(KredxoVenues.KURU, KredxoVenues.SWAP, data);
        assertEq(weth.balanceOf(address(account)), 1_000 * USD);
        assertEq(usdc.balanceOf(address(kuru)), 1_000 * USD);
        assertEq(router.exposureOf(trader, KredxoVenues.KURU), 1_000 * USD);
    }

    function test_overLimitPerplRevertsWithoutTransfer() public {
        uint256 before = usdc.balanceOf(address(account));
        bytes memory data = abi.encode(btc, uint8(0), 10_001 * USD, 2 * WAD, 60_000 * WAD);
        vm.prank(trader);
        vm.expectRevert(abi.encodeWithSelector(KredxoTradeRejected.selector, "exposure exceeds position limit"));
        router.execute(KredxoVenues.PERPL, KredxoVenues.OPEN_PERP, data);
        assertEq(usdc.balanceOf(address(account)), before);
        assertEq(usdc.balanceOf(address(perpl)), 0);
    }

    function test_strangerCannotRoute() public {
        bytes memory data = abi.encode(btc, uint8(0), 100 * USD, 2 * WAD, 60_000 * WAD);
        vm.prank(stranger);
        vm.expectRevert(KredxoUnauthorized.selector);
        router.execute(KredxoVenues.INTERNAL, KredxoVenues.OPEN_PERP, data);
    }

    function test_unknownVenueReverts() public {
        vm.prank(trader);
        vm.expectRevert(KredxoVenueNotAllowed.selector);
        router.execute(3, KredxoVenues.SWAP, bytes(""));
    }

    function test_kuruCannotOpenPerp() public {
        bytes memory data = abi.encode(btc, uint8(0), 100 * USD, 2 * WAD, 60_000 * WAD);
        vm.prank(trader);
        vm.expectRevert(KredxoActionNotAllowed.selector);
        router.execute(KredxoVenues.KURU, KredxoVenues.OPEN_PERP, data);
    }

    function test_unlistedTargetCannotBePaid() public {
        vm.prank(trader);
        vm.expectRevert(KredxoUnauthorized.selector);
        account.payVenue(stranger, 1 * USD);
    }

    function test_cannotSetMainnetPerplOnTestnetRouter() public {
        KredxoExecutionRouter testnetRouter =
            new KredxoExecutionRouter(address(account), address(policy), KredxoVenues.MONAD_TESTNET, admin);
        KredxoPerplAdapter adapter =
            new KredxoPerplAdapter(
                address(testnetRouter), address(perpl), KredxoVenues.MONAD_TESTNET, address(usdc), address(usdc)
            );
        vm.prank(admin);
        vm.expectRevert(KredxoWrongChain.selector);
        testnetRouter.setAdapter(KredxoVenues.PERPL, address(adapter), KredxoVenues.PERPL_MAINNET);
    }

    function test_cannotBindOfficialKuruRouterAsPayTarget() public {
        vm.prank(admin);
        vm.expectRevert(KredxoWrongAsset.selector);
        router.setAdapter(KredxoVenues.KURU, address(kuruAdapter), KredxoVenues.KURU_TESTNET_ROUTER);
    }

    function test_perplMismatchedVenueWithoutHopDoesNotPay() public {
        MockUSDC tUsdc = new MockUSDC();
        KredxoPerplAdapter adapter =
            new KredxoPerplAdapter(address(router), address(perpl), block.chainid, address(usdc), address(tUsdc));
        vm.prank(admin);
        router.setAdapter(KredxoVenues.PERPL, address(adapter), address(perpl));
        uint256 before = usdc.balanceOf(address(account));
        bytes memory data = abi.encode(btc, uint8(0), 4_000 * USD, 2 * WAD, 60_000 * WAD);
        vm.prank(trader);
        vm.expectRevert(KredxoWrongAsset.selector);
        router.execute(KredxoVenues.PERPL, KredxoVenues.OPEN_PERP, data);
        assertEq(usdc.balanceOf(address(account)), before);
        assertEq(usdc.balanceOf(address(perpl)), 0);
    }

    function test_perplOfficialAdapterAcceptsCircleDebit() public {
        KredxoPerplAdapter adapter = new KredxoPerplAdapter(
            address(router),
            KredxoVenues.PERPL_TESTNET,
            KredxoVenues.MONAD_TESTNET,
            KredxoVenues.CIRCLE_TESTNET_USDC,
            KredxoVenues.PERPL_TESTNET_USD
        );
        assertEq(adapter.DEBIT_TOKEN(), KredxoVenues.CIRCLE_TESTNET_USDC);
        assertEq(adapter.VENUE_TOKEN(), KredxoVenues.PERPL_TESTNET_USD);
    }

    function test_kuruOfficialAdapterRejectsCircleAsVenueToken() public {
        vm.expectRevert(KredxoWrongAsset.selector);
        new KredxoKuruAdapter(
            address(router),
            KredxoVenues.KURU_TESTNET_ROUTER,
            KredxoVenues.MONAD_TESTNET,
            KredxoVenues.CIRCLE_TESTNET_USDC,
            KredxoVenues.CIRCLE_TESTNET_USDC
        );
    }

    function test_kuruOfficialAdapterAcceptsCircleDebitAndKuruVenue() public {
        KredxoKuruAdapter adapter = new KredxoKuruAdapter(
            address(router),
            KredxoVenues.KURU_TESTNET_ROUTER,
            KredxoVenues.MONAD_TESTNET,
            KredxoVenues.CIRCLE_TESTNET_USDC,
            KredxoVenues.KURU_TESTNET_USDC
        );
        assertEq(adapter.DEBIT_TOKEN(), KredxoVenues.CIRCLE_TESTNET_USDC);
        assertEq(adapter.VENUE_TOKEN(), KredxoVenues.KURU_TESTNET_USDC);
    }

    function test_kuruOfficialAdapterAcceptsKuruUsdc() public {
        KredxoKuruAdapter adapter = new KredxoKuruAdapter(
            address(router),
            KredxoVenues.KURU_TESTNET_ROUTER,
            KredxoVenues.MONAD_TESTNET,
            KredxoVenues.KURU_TESTNET_USDC,
            KredxoVenues.KURU_TESTNET_USDC
        );
        assertEq(adapter.SETTLEMENT_TOKEN(), KredxoVenues.KURU_TESTNET_USDC);
    }

    function test_executeRevertsWhenAdapterDebitMismatchesVault() public {
        KredxoKuruAdapter wrong = new KredxoKuruAdapter(
            address(router), address(kuru), block.chainid, KredxoVenues.KURU_TESTNET_USDC, KredxoVenues.KURU_TESTNET_USDC
        );
        vm.startPrank(admin);
        router.setAdapter(KredxoVenues.KURU, address(wrong), address(wrong));
        vm.stopPrank();
        bytes memory data = abi.encode(address(weth), 1_000 * USD, uint256(1));
        uint256 before = usdc.balanceOf(address(account));
        vm.prank(trader);
        vm.expectRevert(KredxoWrongAsset.selector);
        router.execute(KredxoVenues.KURU, KredxoVenues.SWAP, data);
        assertEq(usdc.balanceOf(address(account)), before);
        assertEq(usdc.balanceOf(address(kuru)), 0);
    }

    function test_kuruHopConvertsDebitToVenueTokenOnAccount() public {
        MockUSDC tUsdc = new MockUSDC();
        KredxoKuruAdapter hopAdapter =
            new KredxoKuruAdapter(address(router), address(kuru), block.chainid, address(usdc), address(tUsdc));
        address[] memory markets = new address[](1);
        bool[] memory isBuy = new bool[](1);
        bool[] memory nativeSend = new bool[](1);
        markets[0] = address(uint160(1));
        vm.startPrank(admin);
        router.setAdapter(KredxoVenues.KURU, address(hopAdapter), address(hopAdapter));
        router.setKuruHop(markets, isBuy, nativeSend);
        vm.stopPrank();
        uint256 before = usdc.balanceOf(address(account));
        bytes memory data = abi.encode(address(tUsdc), 1_000 * USD, uint256(1));
        vm.prank(trader);
        router.execute(KredxoVenues.KURU, KredxoVenues.SWAP, data);
        assertEq(tUsdc.balanceOf(address(account)), 1_000 * USD);
        assertEq(tUsdc.balanceOf(trader), 0);
        assertEq(usdc.balanceOf(address(account)), before - 1_000 * USD);
        assertEq(usdc.balanceOf(address(kuru)), 1_000 * USD);
    }

    function test_kuruHopRevertsWithoutPathWhenTokensDiffer() public {
        MockUSDC tUsdc = new MockUSDC();
        KredxoKuruAdapter hopAdapter =
            new KredxoKuruAdapter(address(router), address(kuru), block.chainid, address(usdc), address(tUsdc));
        vm.prank(admin);
        router.setAdapter(KredxoVenues.KURU, address(hopAdapter), address(hopAdapter));
        uint256 before = usdc.balanceOf(address(account));
        bytes memory data = abi.encode(address(tUsdc), 1_000 * USD, uint256(1));
        vm.prank(trader);
        vm.expectRevert(KredxoWrongAsset.selector);
        router.execute(KredxoVenues.KURU, KredxoVenues.SWAP, data);
        assertEq(usdc.balanceOf(address(account)), before);
        assertEq(tUsdc.balanceOf(trader), 0);
    }

    function test_perplHopConvertsThenPaysVenueToken() public {
        MockUSDC tUsdc = new MockUSDC();
        MockPerpl perplT = new MockPerpl(address(tUsdc));
        KredxoKuruAdapter hopAdapter =
            new KredxoKuruAdapter(address(router), address(kuru), block.chainid, address(usdc), address(tUsdc));
        KredxoPerplAdapter hopPerpl =
            new KredxoPerplAdapter(address(router), address(perplT), block.chainid, address(usdc), address(tUsdc));
        address[] memory markets = new address[](1);
        bool[] memory isBuy = new bool[](1);
        bool[] memory nativeSend = new bool[](1);
        markets[0] = address(uint160(1));
        vm.startPrank(admin);
        router.setAdapter(KredxoVenues.KURU, address(hopAdapter), address(hopAdapter));
        router.setKuruHop(markets, isBuy, nativeSend);
        router.setAdapter(KredxoVenues.PERPL, address(hopPerpl), address(perplT));
        vm.stopPrank();
        uint256 before = usdc.balanceOf(address(account));
        bytes memory data = abi.encode(btc, uint8(0), 4_000 * USD, 2 * WAD, 60_000 * WAD);
        vm.prank(trader);
        router.execute(KredxoVenues.PERPL, KredxoVenues.OPEN_PERP, data);
        assertEq(tUsdc.balanceOf(address(perplT)), 2_000 * USD);
        assertEq(tUsdc.balanceOf(trader), 0);
        assertEq(usdc.balanceOf(address(account)), before - 2_000 * USD);
        assertEq(perplT.lastId(), 1);
    }

    function test_perplAdapterRejectsMainnetExchangeOnTestnetChainId() public {
        vm.expectRevert(KredxoWrongChain.selector);
        new KredxoPerplAdapter(
            address(router), KredxoVenues.PERPL_MAINNET, KredxoVenues.MONAD_TESTNET, address(usdc), address(usdc)
        );
    }

    function test_withdrawStillDisabledAfterRouter() public {
        vm.prank(trader);
        vm.expectRevert();
        account.withdraw(address(usdc), 1);
    }
}
