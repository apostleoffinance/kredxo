// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

import {IKredxoRiskPolicy} from "./IKredxoRiskPolicy.sol";
import {KredxoUnauthorized, KredxoZeroAddress, KredxoZeroAmount} from "./KredxoErrors.sol";

/// @title KredxoRiskPolicy
/// @notice Stores per-trader trading authority. Only the risk controller may write.
/// @dev Phase 8. Python proposes; this contract is the source of limits.
contract KredxoRiskPolicy is AccessControl, IKredxoRiskPolicy {
    uint8 public constant LEVEL_LOW = 0;
    uint8 public constant LEVEL_NORMAL = 1;
    uint8 public constant LEVEL_ELEVATED = 2;
    uint8 public constant LEVEL_HIGH = 3;
    uint8 public constant LEVEL_CRITICAL = 4;

    string public constant NAME = "KredxoRiskPolicy";
    uint64 public constant PHASE = 8;

    address public controller;

    mapping(address trader => Policy) private _policies;
    mapping(address trader => mapping(address market => bool)) private _marketAllowed;
    mapping(address trader => mapping(address market => uint256)) private _positionLimit;

    event ControllerSet(address indexed controller);

    constructor(address admin_) {
        if (admin_ == address(0)) revert KredxoZeroAddress();
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
    }

    function setController(address controller_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (controller_ == address(0)) revert KredxoZeroAddress();
        if (controller != address(0)) revert KredxoUnauthorized();
        controller = controller_;
        emit ControllerSet(controller_);
    }

    function write(
        address trader,
        Policy calldata next,
        address[] calldata markets,
        uint256[] calldata limits
    ) external {
        if (msg.sender != controller) revert KredxoUnauthorized();
        if (trader == address(0)) revert KredxoZeroAddress();
        if (next.creditLimit == 0 || next.maxLeverage == 0 || next.dailyLossLimit == 0) {
            revert KredxoZeroAmount();
        }
        if (next.validUntil <= next.validFrom) revert KredxoZeroAmount();
        if (next.riskLevel > LEVEL_CRITICAL) revert KredxoZeroAmount();
        if (markets.length != limits.length) revert KredxoZeroAmount();

        _policies[trader] = next;
        for (uint256 i = 0; i < markets.length; ++i) {
            if (markets[i] == address(0)) revert KredxoZeroAddress();
            _positionLimit[trader][markets[i]] = limits[i];
            _marketAllowed[trader][markets[i]] = limits[i] > 0;
        }
    }

    function policyOf(address trader) external view returns (Policy memory) {
        return _policies[trader];
    }

    function marketAllowed(address trader, address market) external view returns (bool) {
        return _marketAllowed[trader][market];
    }

    function positionLimit(address trader, address market) external view returns (uint256) {
        return _positionLimit[trader][market];
    }

    function isCurrent(address trader) public view returns (bool) {
        Policy memory p = _policies[trader];
        if (!p.active) return false;
        if (block.timestamp < p.validFrom || block.timestamp > p.validUntil) return false;
        return true;
    }
}
