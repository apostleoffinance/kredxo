// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IKredxoKuruVenue, IKuruRouter} from "./IKredxoVenues.sol";
import {
    KredxoUnauthorized,
    KredxoWrongAsset,
    KredxoWrongChain,
    KredxoZeroAddress,
    KredxoZeroAmount
} from "./KredxoErrors.sol";
import {KredxoVenues} from "./KredxoVenues.sol";

/// @title KredxoKuruAdapter
/// @notice Typed Kuru adapter. Circle USDC may hop to venue token via allowlisted anyToAnySwap.
/// @dev Output stays on the Credit Account. No Kuru Flow calldata.
contract KredxoKuruAdapter {
    using SafeERC20 for IERC20;

    address public immutable ROUTER;
    address public immutable EXCHANGE;
    address public immutable DEBIT_TOKEN;
    address public immutable VENUE_TOKEN;
    uint256 public immutable EXPECTED_CHAIN_ID;

    address[] public hopMarkets;
    bool[] public hopIsBuy;
    bool[] public hopNativeSend;
    mapping(address token => bool) public creditAllowed;

    event HopSet(uint256 markets);
    event CreditAllowed(address indexed token, bool allowed);
    event Converted(address indexed account, address debit, address credit, uint256 amountIn, uint256 amountOut);

    constructor(
        address router_,
        address exchange_,
        uint256 expectedChainId_,
        address debitToken_,
        address venueToken_
    ) {
        if (router_ == address(0) || exchange_ == address(0) || debitToken_ == address(0) || venueToken_ == address(0))
        {
            revert KredxoZeroAddress();
        }
        if (expectedChainId_ == 0) revert KredxoZeroAmount();
        if (expectedChainId_ == KredxoVenues.MONAD_TESTNET) {
            if (exchange_ == KredxoVenues.KURU_MAINNET) revert KredxoWrongChain();
            if (exchange_ == KredxoVenues.KURU_TESTNET_ROUTER) {
                if (venueToken_ != KredxoVenues.KURU_TESTNET_USDC) revert KredxoWrongAsset();
                if (debitToken_ != KredxoVenues.CIRCLE_TESTNET_USDC && debitToken_ != KredxoVenues.KURU_TESTNET_USDC) {
                    revert KredxoWrongAsset();
                }
            }
        }
        if (expectedChainId_ == KredxoVenues.MONAD_MAINNET) {
            if (exchange_ == KredxoVenues.KURU_TESTNET_ROUTER) revert KredxoWrongChain();
            if (exchange_ == KredxoVenues.KURU_MAINNET && venueToken_ != KredxoVenues.KURU_MAINNET_USDC) {
                revert KredxoWrongAsset();
            }
        }
        ROUTER = router_;
        EXCHANGE = exchange_;
        DEBIT_TOKEN = debitToken_;
        VENUE_TOKEN = venueToken_;
        EXPECTED_CHAIN_ID = expectedChainId_;
        creditAllowed[venueToken_] = true;
    }

    function SETTLEMENT_TOKEN() external view returns (address) {
        return DEBIT_TOKEN;
    }

    function setHop(address[] calldata markets, bool[] calldata isBuy, bool[] calldata nativeSend) external {
        if (msg.sender != ROUTER) revert KredxoUnauthorized();
        if (markets.length == 0 || markets.length != isBuy.length || markets.length != nativeSend.length) {
            revert KredxoZeroAmount();
        }
        delete hopMarkets;
        delete hopIsBuy;
        delete hopNativeSend;
        for (uint256 i; i < markets.length; ++i) {
            if (markets[i] == address(0)) revert KredxoZeroAddress();
            hopMarkets.push(markets[i]);
            hopIsBuy.push(isBuy[i]);
            hopNativeSend.push(nativeSend[i]);
        }
        emit HopSet(markets.length);
    }

    function setCreditAllowed(address token, bool allowed) external {
        if (msg.sender != ROUTER) revert KredxoUnauthorized();
        if (token == address(0)) revert KredxoZeroAddress();
        creditAllowed[token] = allowed;
        emit CreditAllowed(token, allowed);
    }

    function hopLength() external view returns (uint256) {
        return hopMarkets.length;
    }

    function swap(address account, address tokenOut, uint256 amountIn, uint256 minOut)
        external
        returns (uint256 amountOut)
    {
        if (msg.sender != ROUTER) revert KredxoUnauthorized();
        if (block.chainid != EXPECTED_CHAIN_ID) revert KredxoWrongChain();
        if (account == address(0) || tokenOut == address(0) || amountIn == 0) revert KredxoZeroAmount();

        IERC20 debit = IERC20(DEBIT_TOKEN);
        if (debit.balanceOf(address(this)) < amountIn) revert KredxoZeroAmount();

        if (hopMarkets.length == 0) {
            if (DEBIT_TOKEN != VENUE_TOKEN) revert KredxoWrongAsset();
            debit.safeTransfer(EXCHANGE, amountIn);
            amountOut = IKredxoKuruVenue(EXCHANGE).swap(account, tokenOut, amountIn, minOut);
            emit Converted(account, DEBIT_TOKEN, tokenOut, amountIn, amountOut);
            return amountOut;
        }

        if (!creditAllowed[tokenOut]) revert KredxoWrongAsset();
        debit.forceApprove(EXCHANGE, amountIn);
        amountOut = IKuruRouter(EXCHANGE).anyToAnySwap(
            hopMarkets, hopIsBuy, hopNativeSend, DEBIT_TOKEN, tokenOut, amountIn, minOut
        );
        uint256 got = IERC20(tokenOut).balanceOf(address(this));
        if (got < minOut) revert KredxoWrongAsset();
        IERC20(tokenOut).safeTransfer(account, got);
        uint256 leftover = debit.balanceOf(address(this));
        if (leftover > 0) debit.safeTransfer(account, leftover);
        emit Converted(account, DEBIT_TOKEN, tokenOut, amountIn, got);
        return got;
    }
}
