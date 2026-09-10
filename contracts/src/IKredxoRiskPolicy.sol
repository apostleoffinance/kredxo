// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IKredxoRiskPolicy
/// @notice Live trading authority. The account reads this, not a UI cache.
interface IKredxoRiskPolicy {
    struct Policy {
        uint256 creditLimit;
        uint256 maxLeverage;
        uint256 dailyLossLimit;
        uint256 validFrom;
        uint256 validUntil;
        uint8 riskLevel;
        bool active;
    }

    function policyOf(address trader) external view returns (Policy memory);
    function marketAllowed(address trader, address market) external view returns (bool);
    function positionLimit(address trader, address market) external view returns (uint256);
    function isCurrent(address trader) external view returns (bool);
}
