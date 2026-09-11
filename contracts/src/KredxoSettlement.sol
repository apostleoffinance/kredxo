// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

import {KredxoZeroAddress} from "./KredxoErrors.sol";

/// @title KredxoSettlement
/// @notice Onchain venue and market configuration. PnL, repay, and interest stay on the account and vault.
/// @dev Phase 15. One Monad-native venue: the bound trading account.
contract KredxoSettlement is AccessControl {
    string public constant NAME = "KredxoSettlement";
    uint64 public constant PHASE = 15;

    bytes32 public constant BTC = bytes32("BTC");
    bytes32 public constant ETH = bytes32("ETH");

    address public immutable REGISTRY;
    address public immutable VAULT;
    address public immutable USDC;

    address public venue;
    mapping(bytes32 symbol => address market) public marketOf;

    event VenueSet(address indexed venue);
    event MarketSet(bytes32 indexed symbol, address indexed market);

    constructor(address registry_, address vault_, address usdc_, address admin_) {
        if (registry_ == address(0) || vault_ == address(0) || usdc_ == address(0) || admin_ == address(0)) {
            revert KredxoZeroAddress();
        }
        REGISTRY = registry_;
        VAULT = vault_;
        USDC = usdc_;
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
    }

    function setVenue(address venue_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (venue_ == address(0)) revert KredxoZeroAddress();
        venue = venue_;
        emit VenueSet(venue_);
    }

    function setMarket(bytes32 symbol, address market) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (symbol == bytes32(0) || market == address(0)) revert KredxoZeroAddress();
        marketOf[symbol] = market;
        emit MarketSet(symbol, market);
    }
}
