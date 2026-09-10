// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IKredxoRiskPolicy} from "./IKredxoRiskPolicy.sol";
import {KredxoTradingAccount} from "./KredxoTradingAccount.sol";
import {
    KredxoAccountNotBound,
    KredxoInsufficientAllocation,
    KredxoInsufficientLiquidity,
    KredxoInsufficientUtilization,
    KredxoUnauthorizedReceiver,
    KredxoZeroAddress,
    KredxoZeroAmount
} from "./KredxoErrors.sol";

/// @title KredxoCreditVault
/// @notice LP USDC vault. Distinguishes TVL, allocated credit, and utilization.
/// @dev Allocation reserves capacity. It does not transfer USDC. Utilization does.
///      Interest grows unpaid debt and NAV so LPs earn yield from utilized credit.
contract KredxoCreditVault is AccessControl, ReentrancyGuard, ERC20 {
    using SafeERC20 for IERC20;

    bytes32 public constant ALLOCATOR_ROLE = keccak256("ALLOCATOR_ROLE");

    string public constant NAME = "KredxoCreditVault";
    uint64 public constant PHASE = 10;

    uint256 public constant WAD = 1e18;
    uint256 public constant BASE_APR = 8e16; // 8%
    uint256 public constant UTIL_PREMIUM_MAX = 5e16; // 5% at 100% utilization
    int256 public constant RISK_PREMIUM_LOW = -8e15; // -0.8% → 7.2% at idle
    uint256 public constant RISK_PREMIUM_ELEVATED = 2e16;
    uint256 public constant RISK_PREMIUM_HIGH = 4e16;
    uint256 public constant RISK_PREMIUM_CRITICAL = 65e15; // 6.5%

    address public immutable REGISTRY;
    IERC20 public immutable USDC;

    address public riskPolicy;

    uint256 public allocatedCredit;
    uint256 public utilizedCredit;
    uint256 public interestAccrued;

    mapping(address trader => uint256 amount) public allocatedOf;
    mapping(address trader => uint256 amount) public utilizedOf;
    mapping(address trader => uint256 amount) public interestOf;
    mapping(address trader => uint256 timestamp) public lastAccrued;
    mapping(address trader => address account) public accountOf;

    event Deposit(address indexed lp, uint256 assets, uint256 shares);
    event Withdraw(address indexed lp, uint256 assets, uint256 shares);
    event CreditAllocated(address indexed trader, uint256 amount);
    event CreditReleased(address indexed trader, uint256 amount);
    event CreditUtilized(address indexed trader, uint256 amount);
    event CreditIssued(address indexed trader, uint256 amount);
    event CreditAdjusted(address indexed trader, uint256 oldCredit, uint256 newCredit);
    event RepaymentMade(address indexed trader, uint256 amount);
    event TradingAccountBound(address indexed trader, address indexed account);
    event RiskPolicyBound(address indexed policy);
    event InterestAccrued(address indexed trader, uint256 amount, uint256 apr);

    constructor(address registry_, address usdc_, address admin_) ERC20("Kredxo Vault Share", "kUSDC") {
        if (registry_ == address(0) || usdc_ == address(0) || admin_ == address(0)) {
            revert KredxoZeroAddress();
        }
        REGISTRY = registry_;
        USDC = IERC20(usdc_);
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(ALLOCATOR_ROLE, admin_);
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function totalShares() public view returns (uint256) {
        return totalSupply();
    }

    /// @notice LP NAV = idle USDC + outstanding draws + accrued interest.
    function totalAssets() public view returns (uint256) {
        return USDC.balanceOf(address(this)) + utilizedCredit + interestAccrued;
    }

    function setRiskPolicy(address policy_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (policy_ == address(0)) revert KredxoZeroAddress();
        riskPolicy = policy_;
        emit RiskPolicyBound(policy_);
    }

    function utilizationWad() public view returns (uint256) {
        uint256 assets = totalAssets();
        if (assets == 0) return 0;
        return (utilizedCredit * WAD) / assets;
    }

    function riskPremiumWad(uint8 level) public pure returns (int256) {
        if (level == 0) return RISK_PREMIUM_LOW;
        if (level == 2) return int256(RISK_PREMIUM_ELEVATED);
        if (level == 3) return int256(RISK_PREMIUM_HIGH);
        if (level >= 4) return int256(RISK_PREMIUM_CRITICAL);
        return 0;
    }

    function borrowApr(address trader) public view returns (uint256) {
        int256 apr = int256(BASE_APR) + riskPremiumWad(_riskLevel(trader))
            + int256((UTIL_PREMIUM_MAX * utilizationWad()) / WAD);
        if (apr < 0) return 0;
        return uint256(apr);
    }

    function pendingInterest(address trader) public view returns (uint256) {
        uint256 principal = utilizedOf[trader];
        uint256 started = lastAccrued[trader];
        if (principal == 0 || started == 0 || block.timestamp <= started) return 0;
        uint256 elapsed = block.timestamp - started;
        return (principal * borrowApr(trader) * elapsed) / (365 days * WAD);
    }

    function debtOf(address trader) public view returns (uint256) {
        return utilizedOf[trader] + interestOf[trader] + pendingInterest(trader);
    }

    function accrueInterest(address trader) public returns (uint256 interest) {
        interest = pendingInterest(trader);
        lastAccrued[trader] = block.timestamp;
        if (interest == 0) return 0;
        interestOf[trader] += interest;
        interestAccrued += interest;
        emit InterestAccrued(trader, interest, borrowApr(trader));
    }

    /// @notice Unreserved capacity that is also sitting as idle USDC.
    function availableLiquidity() public view returns (uint256) {
        uint256 assets = totalAssets();
        uint256 unreserved = assets > allocatedCredit ? assets - allocatedCredit : 0;
        uint256 idle = USDC.balanceOf(address(this));
        return idle < unreserved ? idle : unreserved;
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        uint256 supply = totalSupply();
        uint256 nav = totalAssets();
        if (supply == 0 || nav == 0) return assets;
        return (assets * supply) / nav;
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        uint256 supply = totalSupply();
        if (supply == 0) return 0;
        return (shares * totalAssets()) / supply;
    }

    function deposit(uint256 assets) external nonReentrant returns (uint256 shares) {
        if (assets == 0) revert KredxoZeroAmount();
        shares = convertToShares(assets);
        if (shares == 0) revert KredxoZeroAmount();

        USDC.safeTransferFrom(msg.sender, address(this), assets);
        _mint(msg.sender, shares);

        emit Deposit(msg.sender, assets, shares);
    }

    function withdraw(uint256 shares) external nonReentrant returns (uint256 assets) {
        if (shares == 0) revert KredxoZeroAmount();
        assets = convertToAssets(shares);
        if (assets == 0) revert KredxoZeroAmount();
        if (assets > availableLiquidity()) revert KredxoInsufficientLiquidity();

        _burn(msg.sender, shares);
        USDC.safeTransfer(msg.sender, assets);

        emit Withdraw(msg.sender, assets, shares);
    }

    function allocateCredit(address trader, uint256 amount) external onlyRole(ALLOCATOR_ROLE) {
        if (trader == address(0)) revert KredxoZeroAddress();
        if (amount == 0) revert KredxoZeroAmount();
        if (amount > availableLiquidity()) revert KredxoInsufficientLiquidity();

        allocatedOf[trader] += amount;
        allocatedCredit += amount;

        emit CreditAllocated(trader, amount);
        emit CreditIssued(trader, amount);
    }

    function releaseCredit(address trader, uint256 amount) external onlyRole(ALLOCATOR_ROLE) {
        if (trader == address(0)) revert KredxoZeroAddress();
        if (amount == 0) revert KredxoZeroAmount();

        uint256 unused = allocatedOf[trader] - utilizedOf[trader];
        if (amount > unused) revert KredxoInsufficientAllocation();

        uint256 oldCredit = allocatedOf[trader];
        allocatedOf[trader] = oldCredit - amount;
        allocatedCredit -= amount;

        emit CreditReleased(trader, amount);
        emit CreditAdjusted(trader, oldCredit, allocatedOf[trader]);
    }

    function setTradingAccount(address trader, address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (trader == address(0) || account == address(0)) revert KredxoZeroAddress();
        KredxoTradingAccount bound = KredxoTradingAccount(account);
        if (bound.VAULT() != address(this) || bound.TRADER() != trader) revert KredxoAccountNotBound();
        accountOf[trader] = account;
        emit TradingAccountBound(trader, account);
    }

    /// @dev If a trading account is bound, USDC may only go there — never to the trader wallet.
    function utilizeCredit(address trader, address to, uint256 amount) external nonReentrant {
        if (trader == address(0) || to == address(0)) revert KredxoZeroAddress();
        if (amount == 0) revert KredxoZeroAmount();

        address registered = accountOf[trader];
        if (registered != address(0)) {
            if (to != registered) revert KredxoUnauthorizedReceiver();
            if (msg.sender != registered) _checkRole(ALLOCATOR_ROLE);
        } else {
            _checkRole(ALLOCATOR_ROLE);
        }

        accrueInterest(trader);

        uint256 unused = allocatedOf[trader] - utilizedOf[trader];
        if (amount > unused) revert KredxoInsufficientAllocation();
        if (amount > USDC.balanceOf(address(this))) revert KredxoInsufficientLiquidity();

        utilizedOf[trader] += amount;
        utilizedCredit += amount;
        if (lastAccrued[trader] == 0) lastAccrued[trader] = block.timestamp;
        USDC.safeTransfer(to, amount);

        emit CreditUtilized(trader, amount);
    }

    function repay(address trader, uint256 amount) external nonReentrant {
        if (trader == address(0)) revert KredxoZeroAddress();
        if (amount == 0) revert KredxoZeroAmount();

        accrueInterest(trader);
        uint256 owed = utilizedOf[trader] + interestOf[trader];
        if (amount > owed) revert KredxoInsufficientUtilization();

        USDC.safeTransferFrom(msg.sender, address(this), amount);

        uint256 interestPay = amount <= interestOf[trader] ? amount : interestOf[trader];
        interestOf[trader] -= interestPay;
        interestAccrued -= interestPay;

        uint256 principalPay = amount - interestPay;
        if (principalPay > 0) {
            utilizedOf[trader] -= principalPay;
            utilizedCredit -= principalPay;
        }

        emit RepaymentMade(trader, amount);
    }

    function _riskLevel(address trader) internal view returns (uint8) {
        if (riskPolicy == address(0)) return 1;
        IKredxoRiskPolicy.Policy memory stored = IKredxoRiskPolicy(riskPolicy).policyOf(trader);
        if (!stored.active) return 1;
        return stored.riskLevel;
    }
}
