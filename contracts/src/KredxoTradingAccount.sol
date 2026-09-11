// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IKredxoCreditVault} from "./IKredxoCreditVault.sol";
import {IKredxoRiskPolicy} from "./IKredxoRiskPolicy.sol";
import {IKredxoRouterAllow} from "./IKredxoVenues.sol";
import {
    KredxoAccountInactive,
    KredxoInsufficientCredit,
    KredxoPolicyBound,
    KredxoPolicyExpired,
    KredxoPositionClosed,
    KredxoTradeRejected,
    KredxoUnauthorized,
    KredxoWithdrawalsDisabled,
    KredxoZeroAddress,
    KredxoZeroAmount
} from "./KredxoErrors.sol";

/// @title KredxoTradingAccount
/// @notice Controlled credit account with a single onchain execution venue.
/// @dev Phase 8: when `riskPolicy` is bound, live policy is the only trading authority.
contract KredxoTradingAccount is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    string public constant NAME = "KredxoTradingAccount";
    uint64 public constant PHASE = 4;

    uint256 public constant LEVERAGE_WAD = 1e18;
    uint8 public constant SIDE_LONG = 0;
    uint8 public constant SIDE_SHORT = 1;

    string public constant REASON_INACTIVE = "account inactive";
    string public constant REASON_MARKET = "market not allowed";
    string public constant REASON_CREDIT = "credit available exceeded";
    string public constant REASON_LEVERAGE = "leverage exceeds max";
    string public constant REASON_EXPOSURE = "exposure exceeds position limit";
    string public constant REASON_DAILY_LOSS = "daily loss limit exceeded";
    string public constant REASON_SIDE = "invalid side";
    string public constant REASON_POLICY = "policy expired";

    address public immutable REGISTRY;
    address public immutable VAULT;
    address public immutable TRADER;
    address public riskPolicy;

    struct CreditAccount {
        address trader;
        uint256 creditLimit;
        uint256 usedCredit;
        uint256 collateral;
        uint256 maxLeverage;
        uint256 dailyLossLimit;
        bool active;
    }

    struct Position {
        address market;
        uint8 side;
        uint256 size;
        uint256 entryPrice;
        uint256 leverage;
        uint256 margin;
        int256 pnl;
        bool open;
    }

    uint256 private _creditLimit;
    uint256 public usedCredit;
    uint256 public collateral;
    uint256 private _maxLeverage;
    uint256 private _dailyLossLimit;
    bool public active;

    uint256 public lockedMargin;
    uint256 public dailyLoss;
    uint256 public dailyLossStartedAt;

    uint256 public positionCount;
    mapping(uint256 id => Position) public positions;
    mapping(address market => bool) public marketAllowed;
    mapping(address market => uint256) public positionLimit;
    mapping(address market => uint256) public exposureOf;
    address public executionRouter;
    mapping(address venue => uint256) public paidToVenue;

    event AccountActivated(address indexed trader, uint256 creditLimit, uint256 maxLeverage, uint256 dailyLossLimit);
    event AccountDeactivated(address indexed trader);
    event LimitsUpdated(uint256 creditLimit, uint256 maxLeverage, uint256 dailyLossLimit);
    event RiskPolicyBound(address indexed policy);
    event CreditDrawn(address indexed trader, uint256 amount);
    event CollateralDeposited(address indexed from, uint256 amount);
    event CreditRepaid(address indexed trader, uint256 amount);
    event MarketUpdated(address indexed market, bool allowed, uint256 positionLimit_);
    event TradeApproved(address indexed trader, address market, uint256 size);
    event TradeRejected(address indexed trader, string reason);
    event PositionClosed(address indexed trader, uint256 indexed id, int256 pnl);
    event ExecutionRouterSet(address indexed router);
    event VenuePaid(address indexed target, uint256 amount);
    event VenuePaidToken(address indexed token, address indexed target, uint256 amount);

    constructor(address registry_, address vault_, address trader_, address admin_) {
        if (registry_ == address(0) || vault_ == address(0) || trader_ == address(0) || admin_ == address(0)) {
            revert KredxoZeroAddress();
        }
        REGISTRY = registry_;
        VAULT = vault_;
        TRADER = trader_;
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(OPERATOR_ROLE, admin_);
    }

    function account() public view returns (CreditAccount memory) {
        return CreditAccount({
            trader: TRADER,
            creditLimit: creditLimit(),
            usedCredit: usedCredit,
            collateral: collateral,
            maxLeverage: maxLeverage(),
            dailyLossLimit: dailyLossLimit(),
            active: active
        });
    }

    function setRiskPolicy(address policy_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (policy_ == address(0)) revert KredxoZeroAddress();
        riskPolicy = policy_;
        emit RiskPolicyBound(policy_);
    }

    function setExecutionRouter(address router_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (router_ == address(0)) revert KredxoZeroAddress();
        executionRouter = router_;
        emit ExecutionRouterSet(router_);
    }

    /// @notice Move idle USDC to an allowlisted venue. Only the execution router. Not a trader withdrawal.
    function payVenue(address target, uint256 amount) external nonReentrant {
        if (msg.sender != executionRouter) revert KredxoUnauthorized();
        if (target == address(0) || amount == 0) revert KredxoZeroAmount();
        if (!IKredxoRouterAllow(executionRouter).isVenueTarget(target)) revert KredxoUnauthorized();
        if (!active) _reject(REASON_INACTIVE);
        _requireCurrentPolicyForTrade();
        if (amount > idleUsdc()) _reject(REASON_CREDIT);
        usdc().safeTransfer(target, amount);
        paidToVenue[target] += amount;
        emit VenuePaid(target, amount);
    }

    /// @notice Move a venue token from this account to an allowlisted target. Not a trader withdrawal.
    function payVenueToken(address token, address target, uint256 amount) external nonReentrant {
        if (msg.sender != executionRouter) revert KredxoUnauthorized();
        if (token == address(0) || target == address(0) || amount == 0) revert KredxoZeroAmount();
        if (token == address(usdc())) revert KredxoUnauthorized();
        if (!IKredxoRouterAllow(executionRouter).isVenueTarget(target)) revert KredxoUnauthorized();
        if (!active) _reject(REASON_INACTIVE);
        _requireCurrentPolicyForTrade();
        IERC20 asset = IERC20(token);
        if (asset.balanceOf(address(this)) < amount) _reject(REASON_CREDIT);
        asset.safeTransfer(target, amount);
        paidToVenue[target] += amount;
        emit VenuePaidToken(token, target, amount);
    }

    function creditLimit() public view returns (uint256) {
        if (riskPolicy != address(0)) return _policy().creditLimit;
        return _creditLimit;
    }

    function maxLeverage() public view returns (uint256) {
        if (riskPolicy != address(0)) return _policy().maxLeverage;
        return _maxLeverage;
    }

    function dailyLossLimit() public view returns (uint256) {
        if (riskPolicy != address(0)) return _policy().dailyLossLimit;
        return _dailyLossLimit;
    }

    function availableCredit() public view returns (uint256) {
        uint256 limit = creditLimit();
        if (limit <= usedCredit) return 0;
        return limit - usedCredit;
    }

    function idleUsdc() public view returns (uint256) {
        uint256 balance = usdc().balanceOf(address(this));
        if (balance <= lockedMargin) return 0;
        return balance - lockedMargin;
    }

    function usdc() public view returns (IERC20) {
        return IKredxoCreditVault(VAULT).USDC();
    }

    function activate(uint256 creditLimit_, uint256 maxLeverage_, uint256 dailyLossLimit_)
        external
        onlyRole(OPERATOR_ROLE)
    {
        if (creditLimit_ == 0 || maxLeverage_ == 0 || dailyLossLimit_ == 0) revert KredxoZeroAmount();
        _creditLimit = creditLimit_;
        _maxLeverage = maxLeverage_;
        _dailyLossLimit = dailyLossLimit_;
        active = true;
        emit AccountActivated(TRADER, creditLimit_, maxLeverage_, dailyLossLimit_);
    }

    function deactivate() external onlyRole(OPERATOR_ROLE) {
        active = false;
        emit AccountDeactivated(TRADER);
    }

    function setLimits(uint256 creditLimit_, uint256 maxLeverage_, uint256 dailyLossLimit_)
        external
        onlyRole(OPERATOR_ROLE)
    {
        if (riskPolicy != address(0)) revert KredxoPolicyBound();
        if (creditLimit_ == 0 || maxLeverage_ == 0 || dailyLossLimit_ == 0) revert KredxoZeroAmount();
        if (usedCredit > creditLimit_) revert KredxoInsufficientCredit();
        _creditLimit = creditLimit_;
        _maxLeverage = maxLeverage_;
        _dailyLossLimit = dailyLossLimit_;
        emit LimitsUpdated(creditLimit_, maxLeverage_, dailyLossLimit_);
    }

    function setMarket(address market, bool allowed, uint256 limit) external onlyRole(OPERATOR_ROLE) {
        if (riskPolicy != address(0)) revert KredxoPolicyBound();
        if (market == address(0)) revert KredxoZeroAddress();
        marketAllowed[market] = allowed;
        positionLimit[market] = limit;
        emit MarketUpdated(market, allowed, limit);
    }

    function draw(uint256 amount) external nonReentrant {
        if (!active) revert KredxoAccountInactive();
        _requireCurrentPolicyForDraw();
        _onlyTraderOrOperator();
        if (amount == 0) revert KredxoZeroAmount();
        if (amount > availableCredit()) revert KredxoInsufficientCredit();

        usedCredit += amount;
        IKredxoCreditVault(VAULT).utilizeCredit(TRADER, address(this), amount);
        emit CreditDrawn(TRADER, amount);
    }

    function depositCollateral(uint256 amount) external nonReentrant {
        if (amount == 0) revert KredxoZeroAmount();
        usdc().safeTransferFrom(msg.sender, address(this), amount);
        collateral += amount;
        emit CollateralDeposited(msg.sender, amount);
    }

    function repay(uint256 amount) external nonReentrant {
        _onlyTraderOrOperator();
        if (amount == 0) revert KredxoZeroAmount();
        IKredxoCreditVault vault_ = IKredxoCreditVault(VAULT);
        if (amount > vault_.debtOf(TRADER)) revert KredxoInsufficientCredit();
        if (amount > idleUsdc()) revert KredxoInsufficientCredit();

        IERC20 token = usdc();
        token.safeIncreaseAllowance(VAULT, amount);
        vault_.repay(TRADER, amount);
        usedCredit = vault_.utilizedOf(TRADER);
        emit CreditRepaid(TRADER, amount);
    }

    /// @param size Notional exposure in USDC (6 decimals).
    /// @param leverage WAD (1e18 = 1x).
    /// @param price Market price in WAD.
    function executeTrade(address market, uint8 side, uint256 size, uint256 leverage, uint256 price)
        external
        nonReentrant
        returns (uint256 id)
    {
        _onlyTraderOrOperator();
        _syncDailyLoss();

        if (!active) _reject(REASON_INACTIVE);
        _requireCurrentPolicyForTrade();
        if (market == address(0) || !_isMarketAllowed(market)) _reject(REASON_MARKET);
        if (side > SIDE_SHORT) _reject(REASON_SIDE);
        if (size == 0 || leverage == 0 || price == 0) revert KredxoZeroAmount();
        if (leverage > maxLeverage()) _reject(REASON_LEVERAGE);
        if (dailyLoss >= dailyLossLimit()) _reject(REASON_DAILY_LOSS);
        if (exposureOf[market] + size > _positionLimitOf(market)) _reject(REASON_EXPOSURE);

        uint256 margin = (size * LEVERAGE_WAD) / leverage;
        if (margin == 0 || margin > idleUsdc()) _reject(REASON_CREDIT);

        id = ++positionCount;
        positions[id] = Position({
            market: market,
            side: side,
            size: size,
            entryPrice: price,
            leverage: leverage,
            margin: margin,
            pnl: 0,
            open: true
        });
        exposureOf[market] += size;
        lockedMargin += margin;

        emit TradeApproved(TRADER, market, size);
    }

    function closePosition(uint256 id, uint256 price) external nonReentrant returns (int256 pnl) {
        _onlyTraderOrOperator();
        if (price == 0) revert KredxoZeroAmount();

        Position storage pos = positions[id];
        if (!pos.open) revert KredxoPositionClosed();

        pnl = _pnl(pos.side, pos.size, pos.entryPrice, price);
        pos.pnl = pnl;
        pos.open = false;

        exposureOf[pos.market] -= pos.size;
        lockedMargin -= pos.margin;

        if (pnl < 0) {
            _syncDailyLoss();
            uint256 loss = uint256(-pnl);
            if (loss > pos.margin) loss = pos.margin;
            dailyLoss += loss;
            IKredxoCreditVault vault_ = IKredxoCreditVault(VAULT);
            uint256 debt = vault_.debtOf(TRADER);
            uint256 available = idleUsdc();
            if (loss > available) loss = available;
            if (loss > debt) loss = debt;
            if (loss > 0) {
                usdc().safeIncreaseAllowance(VAULT, loss);
                vault_.repay(TRADER, loss);
                usedCredit = vault_.utilizedOf(TRADER);
            }
        }

        emit PositionClosed(TRADER, id, pnl);
    }

    function withdraw(address, uint256) external pure {
        revert KredxoWithdrawalsDisabled();
    }

    function withdrawCollateral(address, uint256) external pure {
        revert KredxoWithdrawalsDisabled();
    }

    function _onlyTraderOrOperator() internal view {
        if (msg.sender != TRADER && !hasRole(OPERATOR_ROLE, msg.sender)) revert KredxoUnauthorized();
    }

    function _policy() internal view returns (IKredxoRiskPolicy.Policy memory) {
        return IKredxoRiskPolicy(riskPolicy).policyOf(TRADER);
    }

    function _isMarketAllowed(address market) internal view returns (bool) {
        if (riskPolicy != address(0)) return IKredxoRiskPolicy(riskPolicy).marketAllowed(TRADER, market);
        return marketAllowed[market];
    }

    function _positionLimitOf(address market) internal view returns (uint256) {
        if (riskPolicy != address(0)) return IKredxoRiskPolicy(riskPolicy).positionLimit(TRADER, market);
        return positionLimit[market];
    }

    function _requireCurrentPolicyForDraw() internal view {
        if (riskPolicy == address(0)) return;
        if (!IKredxoRiskPolicy(riskPolicy).isCurrent(TRADER)) revert KredxoPolicyExpired();
    }

    function _requireCurrentPolicyForTrade() internal {
        if (riskPolicy == address(0)) return;
        if (!IKredxoRiskPolicy(riskPolicy).isCurrent(TRADER)) _reject(REASON_POLICY);
    }

    function _syncDailyLoss() internal {
        if (dailyLossStartedAt == 0 || block.timestamp >= dailyLossStartedAt + 1 days) {
            dailyLoss = 0;
            dailyLossStartedAt = block.timestamp;
        }
    }

    function _reject(string memory reason) internal {
        emit TradeRejected(TRADER, reason);
        revert KredxoTradeRejected(reason);
    }

    function _pnl(uint8 side, uint256 size, uint256 entryPrice, uint256 exitPrice) internal pure returns (int256) {
        int256 sized = int256(size);
        int256 entry = int256(entryPrice);
        int256 exit_ = int256(exitPrice);
        int256 delta = side == SIDE_LONG ? exit_ - entry : entry - exit_;
        return (sized * delta) / entry;
    }
}
