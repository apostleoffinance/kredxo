// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

import {IKredxoRiskPolicy} from "./IKredxoRiskPolicy.sol";
import {KredxoRiskPolicy} from "./KredxoRiskPolicy.sol";
import {KredxoUnauthorized, KredxoZeroAddress} from "./KredxoErrors.sol";

/// @title KredxoRiskController
/// @notice Sole writer of live risk policy. Offchain engine calls through this role.
/// @dev Phase 8. RISK_CONTROLLER_ROLE is the only updater.
contract KredxoRiskController is AccessControl {
    bytes32 public constant RISK_CONTROLLER_ROLE = keccak256("RISK_CONTROLLER_ROLE");

    string public constant NAME = "KredxoRiskController";
    uint64 public constant PHASE = 8;

    KredxoRiskPolicy public immutable POLICY;

    event PolicyUpdated(address indexed trader, uint256 creditLimit, uint256 leverageLimit);
    event CreditAdjusted(address indexed trader, uint256 oldCredit, uint256 newCredit);
    event RiskLevelChanged(address indexed trader, uint8 oldLevel, uint8 newLevel);

    constructor(address policy_, address admin_) {
        if (policy_ == address(0) || admin_ == address(0)) revert KredxoZeroAddress();
        POLICY = KredxoRiskPolicy(policy_);
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(RISK_CONTROLLER_ROLE, admin_);
    }

    function applyPolicy(
        address trader,
        uint256 creditLimit,
        uint256 maxLeverage,
        uint256 dailyLossLimit,
        uint256 validFrom,
        uint256 validUntil,
        uint8 riskLevel,
        address[] calldata markets,
        uint256[] calldata limits
    ) external onlyRole(RISK_CONTROLLER_ROLE) {
        if (POLICY.controller() != address(this)) revert KredxoUnauthorized();

        IKredxoRiskPolicy.Policy memory prev = POLICY.policyOf(trader);
        IKredxoRiskPolicy.Policy memory next = IKredxoRiskPolicy.Policy({
            creditLimit: creditLimit,
            maxLeverage: maxLeverage,
            dailyLossLimit: dailyLossLimit,
            validFrom: validFrom,
            validUntil: validUntil,
            riskLevel: riskLevel,
            active: true
        });

        POLICY.write(trader, next, markets, limits);

        emit PolicyUpdated(trader, creditLimit, maxLeverage);
        if (prev.creditLimit != creditLimit) {
            emit CreditAdjusted(trader, prev.creditLimit, creditLimit);
        }
        if (prev.riskLevel != riskLevel || !prev.active) {
            emit RiskLevelChanged(trader, prev.riskLevel, riskLevel);
        }
    }
}
