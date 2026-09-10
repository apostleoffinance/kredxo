// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

import {KredxoZeroAddress} from "./KredxoErrors.sol";

/// @title KredxoRegistry
/// @notice Protocol configuration: users, markets, controllers, vaults, approved venues.
/// @dev Phase 1 stub. Setters and storage land in later phases.
contract KredxoRegistry is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    string public constant NAME = "KredxoRegistry";
    uint64 public constant PHASE = 1;

    constructor(address admin) {
        if (admin == address(0)) revert KredxoZeroAddress();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
    }
}
