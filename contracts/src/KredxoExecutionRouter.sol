// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IKredxoRiskPolicy} from "./IKredxoRiskPolicy.sol";
import {KredxoKuruAdapter} from "./KredxoKuruAdapter.sol";
import {KredxoPerplAdapter} from "./KredxoPerplAdapter.sol";
import {KredxoTradingAccount} from "./KredxoTradingAccount.sol";
import {KredxoVenues} from "./KredxoVenues.sol";
import {
    KredxoActionNotAllowed,
    KredxoTradeRejected,
    KredxoUnauthorized,
    KredxoVenueNotAllowed,
    KredxoWrongAsset,
    KredxoWrongChain,
    KredxoZeroAddress,
    KredxoZeroAmount
} from "./KredxoErrors.sol";

/// @title KredxoExecutionRouter
/// @notice Policy-controlled venue router. Does not hold credit. No arbitrary external calldata.
/// @dev Phase 19. Circle USDC hops to venue token on the Kuru adapter. Adapter 0 remains the trading account.
contract KredxoExecutionRouter is AccessControl, ReentrancyGuard {
    string public constant NAME = "KredxoExecutionRouter";
    uint64 public constant PHASE = 19;
    string public constant REASON_EXPOSURE = "exposure exceeds position limit";
    string public constant REASON_VENUE = "venue not allowed";

    KredxoTradingAccount public immutable ACCOUNT;
    IKredxoRiskPolicy public immutable POLICY;
    address public immutable TRADER;
    uint256 public immutable EXPECTED_CHAIN_ID;

    mapping(uint8 venue => address adapter) public adapterOf;
    mapping(uint8 venue => address target) public targetOf;
    mapping(uint8 venue => mapping(uint8 action => bool)) public actionAllowed;
    mapping(address target => bool) public isVenueTarget;
    mapping(address trader => mapping(uint8 venue => uint256)) public exposureOf;

    event AdapterSet(uint8 indexed venue, address adapter, address target);
    event ActionSet(uint8 indexed venue, uint8 indexed action, bool allowed);
    event Routed(address indexed trader, uint8 venue, uint8 action, uint256 size);

    constructor(address account_, address policy_, uint256 expectedChainId_, address admin_) {
        if (account_ == address(0) || policy_ == address(0) || admin_ == address(0)) revert KredxoZeroAddress();
        if (expectedChainId_ == 0) revert KredxoZeroAmount();
        ACCOUNT = KredxoTradingAccount(account_);
        POLICY = IKredxoRiskPolicy(policy_);
        TRADER = ACCOUNT.TRADER();
        EXPECTED_CHAIN_ID = expectedChainId_;
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
    }

    function setAdapter(uint8 venue, address adapter, address target) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (venue == KredxoVenues.INTERNAL) revert KredxoVenueNotAllowed();
        if (adapter == address(0) || target == address(0)) revert KredxoZeroAddress();
        _forbidMainnetOnTestnet(target);
        if (target == KredxoVenues.KURU_TESTNET_ROUTER || target == KredxoVenues.KURU_MAINNET) {
            revert KredxoWrongAsset();
        }
        address prevTarget = targetOf[venue];
        address prevAdapter = adapterOf[venue];
        if (prevTarget != address(0)) isVenueTarget[prevTarget] = false;
        if (prevAdapter != address(0)) isVenueTarget[prevAdapter] = false;
        adapterOf[venue] = adapter;
        targetOf[venue] = target;
        isVenueTarget[target] = true;
        if (venue == KredxoVenues.KURU) isVenueTarget[adapter] = true;
        emit AdapterSet(venue, adapter, target);
    }

    function setAction(uint8 venue, uint8 action, bool allowed) external onlyRole(DEFAULT_ADMIN_ROLE) {
        actionAllowed[venue][action] = allowed;
        emit ActionSet(venue, action, allowed);
    }

    function setKuruHop(address[] calldata markets, bool[] calldata isBuy, bool[] calldata nativeSend)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        address adapter = adapterOf[KredxoVenues.KURU];
        if (adapter == address(0)) revert KredxoVenueNotAllowed();
        KredxoKuruAdapter(adapter).setHop(markets, isBuy, nativeSend);
    }

    function setKuruCredit(address token, bool allowed) external onlyRole(DEFAULT_ADMIN_ROLE) {
        address adapter = adapterOf[KredxoVenues.KURU];
        if (adapter == address(0)) revert KredxoVenueNotAllowed();
        KredxoKuruAdapter(adapter).setCreditAllowed(token, allowed);
    }

    /// @param data Typed payload: perp (market, side, size, leverage, price), close (id, price), swap (tokenOut, amountIn, minOut).
    function execute(uint8 venue, uint8 action, bytes calldata data) external nonReentrant {
        _requireChain();
        _onlyTraderOrOperator();
        if (venue > KredxoVenues.KURU) revert KredxoVenueNotAllowed();

        if (venue == KredxoVenues.INTERNAL) {
            _internal(action, data);
            return;
        }
        if (!actionAllowed[venue][action]) revert KredxoActionNotAllowed();
        if (adapterOf[venue] == address(0)) revert KredxoVenueNotAllowed();

        if (venue == KredxoVenues.PERPL) {
            _perpl(action, data);
            return;
        }
        _kuru(action, data);
    }

    function _internal(uint8 action, bytes calldata data) internal {
        if (action == KredxoVenues.OPEN_PERP) {
            (address market, uint8 side, uint256 size, uint256 leverage, uint256 price) =
                abi.decode(data, (address, uint8, uint256, uint256, uint256));
            ACCOUNT.executeTrade(market, side, size, leverage, price);
            emit Routed(TRADER, KredxoVenues.INTERNAL, action, size);
            return;
        }
        if (action == KredxoVenues.CLOSE_PERP) {
            (uint256 id, uint256 price) = abi.decode(data, (uint256, uint256));
            ACCOUNT.closePosition(id, price);
            emit Routed(TRADER, KredxoVenues.INTERNAL, action, 0);
            return;
        }
        revert KredxoActionNotAllowed();
    }

    function _perpl(uint8 action, bytes calldata data) internal {
        KredxoPerplAdapter adapter = KredxoPerplAdapter(adapterOf[KredxoVenues.PERPL]);
        _requireDebit(adapter.DEBIT_TOKEN());
        if (action == KredxoVenues.OPEN_PERP) {
            (address market, uint8 side, uint256 size, uint256 leverage, uint256 price) =
                abi.decode(data, (address, uint8, uint256, uint256, uint256));
            _requireLimit(KredxoVenues.PERPL_MARKET, size, KredxoVenues.PERPL);
            uint256 margin = (size * 1e18) / leverage;
            if (margin == 0) revert KredxoZeroAmount();
            _payPerplMargin(adapter, margin);
            adapter.open(address(ACCOUNT), market, side, size, leverage, price);
            exposureOf[TRADER][KredxoVenues.PERPL] += size;
            emit Routed(TRADER, KredxoVenues.PERPL, action, size);
            return;
        }
        if (action == KredxoVenues.CLOSE_PERP) {
            (uint256 id, uint256 price) = abi.decode(data, (uint256, uint256));
            adapter.close(address(ACCOUNT), id, price);
            emit Routed(TRADER, KredxoVenues.PERPL, action, 0);
            return;
        }
        revert KredxoActionNotAllowed();
    }

    function _kuru(uint8 action, bytes calldata data) internal {
        if (action != KredxoVenues.SWAP) revert KredxoActionNotAllowed();
        (address tokenOut, uint256 amountIn, uint256 minOut) = abi.decode(data, (address, uint256, uint256));
        KredxoKuruAdapter adapter = KredxoKuruAdapter(adapterOf[KredxoVenues.KURU]);
        _requireDebit(adapter.DEBIT_TOKEN());
        _requireLimit(KredxoVenues.KURU_MARKET, amountIn, KredxoVenues.KURU);
        if (adapter.DEBIT_TOKEN() != adapter.VENUE_TOKEN() && adapter.hopLength() == 0) revert KredxoWrongAsset();
        ACCOUNT.payVenue(address(adapter), amountIn);
        adapter.swap(address(ACCOUNT), tokenOut, amountIn, minOut);
        exposureOf[TRADER][KredxoVenues.KURU] += amountIn;
        emit Routed(TRADER, KredxoVenues.KURU, action, amountIn);
    }

    function _payPerplMargin(KredxoPerplAdapter adapter, uint256 margin) internal {
        if (adapter.DEBIT_TOKEN() == adapter.VENUE_TOKEN()) {
            ACCOUNT.payVenue(targetOf[KredxoVenues.PERPL], margin);
            return;
        }
        address kuruAdapter = adapterOf[KredxoVenues.KURU];
        if (kuruAdapter == address(0) || KredxoKuruAdapter(kuruAdapter).hopLength() == 0) revert KredxoWrongAsset();
        ACCOUNT.payVenue(kuruAdapter, margin);
        KredxoKuruAdapter(kuruAdapter).swap(address(ACCOUNT), adapter.VENUE_TOKEN(), margin, 1);
        uint256 got = IERC20(adapter.VENUE_TOKEN()).balanceOf(address(ACCOUNT));
        if (got == 0) revert KredxoWrongAsset();
        ACCOUNT.payVenueToken(adapter.VENUE_TOKEN(), targetOf[KredxoVenues.PERPL], got);
    }

    function _requireLimit(address marketKey, uint256 size, uint8 venue) internal {
        if (size == 0) revert KredxoZeroAmount();
        if (!POLICY.marketAllowed(TRADER, marketKey)) {
            emit TradeRejected(TRADER, REASON_VENUE);
            revert KredxoTradeRejected(REASON_VENUE);
        }
        uint256 cap = POLICY.positionLimit(TRADER, marketKey);
        if (exposureOf[TRADER][venue] + size > cap) {
            emit TradeRejected(TRADER, REASON_EXPOSURE);
            revert KredxoTradeRejected(REASON_EXPOSURE);
        }
    }

    function _onlyTraderOrOperator() internal view {
        if (msg.sender != TRADER && !ACCOUNT.hasRole(ACCOUNT.OPERATOR_ROLE(), msg.sender)) {
            revert KredxoUnauthorized();
        }
    }

    function _requireChain() internal view {
        if (block.chainid != EXPECTED_CHAIN_ID) revert KredxoWrongChain();
    }

    function _forbidMainnetOnTestnet(address target) internal view {
        if (EXPECTED_CHAIN_ID != KredxoVenues.MONAD_TESTNET) return;
        if (target == KredxoVenues.PERPL_MAINNET || target == KredxoVenues.KURU_MAINNET) revert KredxoWrongChain();
    }

    function _requireDebit(address debit) internal view {
        if (address(ACCOUNT.usdc()) != debit) revert KredxoWrongAsset();
    }

    event TradeRejected(address indexed trader, string reason);
}
