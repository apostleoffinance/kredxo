// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IKredxoPerplVenue} from "./IKredxoVenues.sol";
import {
    KredxoUnauthorized,
    KredxoWrongAsset,
    KredxoWrongChain,
    KredxoZeroAddress,
    KredxoZeroAmount
} from "./KredxoErrors.sol";
import {KredxoVenues} from "./KredxoVenues.sol";

/// @title KredxoPerplAdapter
/// @notice Typed Perpl adapter. Debit may be vault Circle USDC; venue token is Perpl collateral.
/// @dev Convert hop (if needed) runs on the Kuru adapter before this open. No arbitrary calldata.
contract KredxoPerplAdapter {
    address public immutable ROUTER;
    address public immutable EXCHANGE;
    address public immutable DEBIT_TOKEN;
    address public immutable VENUE_TOKEN;
    uint256 public immutable EXPECTED_CHAIN_ID;

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
            if (exchange_ == KredxoVenues.PERPL_MAINNET) revert KredxoWrongChain();
            if (exchange_ == KredxoVenues.PERPL_TESTNET) {
                if (
                    venueToken_ != KredxoVenues.PERPL_TESTNET_USD && venueToken_ != KredxoVenues.PERPL_TESTNET_AUSD
                ) revert KredxoWrongAsset();
                if (
                    debitToken_ != KredxoVenues.CIRCLE_TESTNET_USDC && debitToken_ != venueToken_
                ) revert KredxoWrongAsset();
            }
        }
        if (expectedChainId_ == KredxoVenues.MONAD_MAINNET) {
            if (exchange_ == KredxoVenues.PERPL_TESTNET) revert KredxoWrongChain();
            if (exchange_ == KredxoVenues.PERPL_MAINNET && venueToken_ != KredxoVenues.PERPL_MAINNET_AUSD) {
                revert KredxoWrongAsset();
            }
        }
        ROUTER = router_;
        EXCHANGE = exchange_;
        DEBIT_TOKEN = debitToken_;
        VENUE_TOKEN = venueToken_;
        EXPECTED_CHAIN_ID = expectedChainId_;
    }

    function SETTLEMENT_TOKEN() external view returns (address) {
        return DEBIT_TOKEN;
    }

    function open(
        address account,
        address market,
        uint8 side,
        uint256 size,
        uint256 leverage,
        uint256 price
    ) external {
        _onlyRouter();
        _requireChain();
        if (size == 0 || leverage == 0) revert KredxoZeroAmount();
        IKredxoPerplVenue(EXCHANGE).open(account, market, side, size, leverage, price);
    }

    function close(address account, uint256 id, uint256 price) external {
        _onlyRouter();
        _requireChain();
        IKredxoPerplVenue(EXCHANGE).close(account, id, price);
    }

    function _onlyRouter() internal view {
        if (msg.sender != ROUTER) revert KredxoUnauthorized();
    }

    function _requireChain() internal view {
        if (block.chainid != EXPECTED_CHAIN_ID) revert KredxoWrongChain();
    }
}
