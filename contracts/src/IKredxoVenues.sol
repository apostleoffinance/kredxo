// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IKredxoPerplVenue {
    function open(address account, address market, uint8 side, uint256 size, uint256 leverage, uint256 price)
        external;
    function close(address account, uint256 id, uint256 price) external;
}

interface IKredxoKuruVenue {
    function swap(address recipient, address tokenOut, uint256 amountIn, uint256 minOut)
        external
        returns (uint256 amountOut);
}

interface IKuruRouter {
    function anyToAnySwap(
        address[] calldata marketAddresses,
        bool[] calldata isBuy,
        bool[] calldata nativeSend,
        address debitToken,
        address creditToken,
        uint256 amount,
        uint256 minAmountOut
    ) external payable returns (uint256 amountOut);
}

interface IKredxoRouterAllow {
    function isVenueTarget(address target) external view returns (bool);
}

interface IKredxoAccountSpender {
    function payVenue(address target, uint256 amount) external;
    function payVenueToken(address token, address target, uint256 amount) external;
    function TRADER() external view returns (address);
    function executeTrade(address market, uint8 side, uint256 size, uint256 leverage, uint256 price)
        external
        returns (uint256 id);
    function closePosition(uint256 id, uint256 price) external returns (int256 pnl);
}
