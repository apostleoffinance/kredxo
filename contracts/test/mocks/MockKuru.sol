// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IKredxoKuruVenue, IKuruRouter} from "../../src/IKredxoVenues.sol";
import {MockUSDC} from "./MockUSDC.sol";

contract MockKuru is IKredxoKuruVenue, IKuruRouter {
    IERC20 public immutable usdc;
    MockUSDC public immutable weth;

    constructor(address usdc_, address weth_) {
        usdc = IERC20(usdc_);
        weth = MockUSDC(weth_);
    }

    function swap(address recipient, address tokenOut, uint256 amountIn, uint256 minOut)
        external
        override
        returns (uint256 amountOut)
    {
        require(tokenOut == address(weth), "pair");
        amountOut = amountIn;
        require(amountOut >= minOut, "slippage");
        weth.mint(recipient, amountOut);
    }

    function anyToAnySwap(
        address[] calldata,
        bool[] calldata,
        bool[] calldata,
        address debitToken,
        address creditToken,
        uint256 amount,
        uint256 minAmountOut
    ) external payable override returns (uint256 amountOut) {
        require(IERC20(debitToken).transferFrom(msg.sender, address(this), amount), "pull");
        amountOut = amount;
        require(amountOut >= minAmountOut, "slippage");
        MockUSDC(creditToken).mint(msg.sender, amountOut);
    }
}
