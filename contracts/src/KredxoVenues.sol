// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Venue ids and official Monad addresses (Kuru docs + Perpl api-docs).
/// @dev Kredxo vault USDC on testnet is Circle `CIRCLE_TESTNET_USDC`, which is not Kuru or Perpl collateral.
library KredxoVenues {
    uint8 internal constant INTERNAL = 0;
    uint8 internal constant PERPL = 1;
    uint8 internal constant KURU = 2;

    uint8 internal constant OPEN_PERP = 0;
    uint8 internal constant CLOSE_PERP = 1;
    uint8 internal constant SWAP = 2;

    address internal constant PERPL_MARKET = address(uint160(0xFE12));
    address internal constant KURU_MARKET = address(uint160(0xFE13));

    uint256 internal constant MONAD_TESTNET = 10143;
    uint256 internal constant MONAD_MAINNET = 143;

    /// @dev Circle official Monad Testnet USDC — Kredxo vault token (tokenlist-testnet.json).
    address internal constant CIRCLE_TESTNET_USDC = 0x534b2f3A21130d7a60830c2Df862319e593943A3;

    /// @dev docs.kuru.io Contract-addresses — Testnet.
    address internal constant KURU_TESTNET_ROUTER = 0x7EFbE105Ca7415dE98F96622173458ac1c054630;
    address internal constant KURU_TESTNET_USDC = 0x3bA3d39AFcf8bb994f7964B3e0171Ea2Ba361570;
    address internal constant KURU_TESTNET_MON_USDC = 0xa241896A7Dbe8a550D2E5fF7A914bB1989ceD2D9;

    /// @dev docs.kuru.io Contract-addresses — Mainnet.
    address internal constant KURU_MAINNET = 0xd651346d7c789536ebf06dc72aE3C8502cd695CC;
    address internal constant KURU_MAINNET_USDC = 0x754704Bc059F8C67012fEd69BC8A327a5aafb603;

    /// @dev PerplFoundation/api-docs Network Configuration.
    address internal constant PERPL_TESTNET = 0x1964C32f0bE608E7D29302AFF5E61268E72080cc;
    address internal constant PERPL_TESTNET_USD = 0xdF5B718d8FcC173335185a2a1513eE8151e3c027;
    /// @dev docs.perpl.xyz developer overview — testnet aUSD (Agora).
    address internal constant PERPL_TESTNET_AUSD = 0xa9012a055bd4e0eDfF8Ce09f960291C09D5322dC;
    address internal constant PERPL_MAINNET = 0x34B6552d57a35a1D042CcAe1951BD1C370112a6F;
    address internal constant PERPL_MAINNET_AUSD = 0x00000000eFE302BEAA2b3e6e1b18d08D69a9012a;
}
