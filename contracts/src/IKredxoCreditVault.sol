// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IKredxoCreditVault {
    function USDC() external view returns (IERC20);

    function accountOf(address trader) external view returns (address);

    function allocatedOf(address trader) external view returns (uint256);

    function utilizedOf(address trader) external view returns (uint256);

    function interestOf(address trader) external view returns (uint256);

    function pendingInterest(address trader) external view returns (uint256);

    function debtOf(address trader) external view returns (uint256);

    function utilizeCredit(address trader, address to, uint256 amount) external;

    function repay(address trader, uint256 amount) external;

    function accrueInterest(address trader) external returns (uint256);
}
