// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IKredxoPerplVenue} from "../../src/IKredxoVenues.sol";

contract MockPerpl is IKredxoPerplVenue {
    struct Pos {
        address account;
        address market;
        uint8 side;
        uint256 size;
        uint256 leverage;
        uint256 price;
        bool open;
    }

    IERC20 public immutable usdc;
    uint256 public lastId;
    mapping(uint256 id => Pos) public positions;

    constructor(address usdc_) {
        usdc = IERC20(usdc_);
    }

    function open(address account, address market, uint8 side, uint256 size, uint256 leverage, uint256 price)
        external
        override
    {
        lastId += 1;
        positions[lastId] = Pos(account, market, side, size, leverage, price, true);
    }

    function close(address account, uint256 id, uint256) external override {
        Pos storage p = positions[id];
        require(p.open && p.account == account, "closed");
        p.open = false;
        uint256 margin = (p.size * 1e18) / p.leverage;
        uint256 bal = usdc.balanceOf(address(this));
        if (margin > bal) margin = bal;
        if (margin > 0) usdc.transfer(account, margin);
    }
}
