// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Test} from "forge-std/Test.sol";

import {IOracle} from "../src/interfaces/oracles/IOracle.sol";
import {SyncRedeemQueue} from "../src/queues/SyncRedeemQueue.sol";

/*//////////////////////////////////////////////////////////////
                              MOCKS
    The mocks are intentionally minimal: they expose the exact
    selectors SyncRedeemQueue calls on its collaborators, without
    inheriting the full interfaces. The contract under test is the
    real one -- only its environment is simulated.
//////////////////////////////////////////////////////////////*/

contract MockToken {
    string public name = "Mock";
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 a) external {
        balanceOf[to] += a;
        totalSupply += a;
    }

    function transfer(address to, uint256 a) external returns (bool) {
        balanceOf[msg.sender] -= a;
        balanceOf[to] += a;
        return true;
    }

    function approve(address s, uint256 a) external returns (bool) {
        allowance[msg.sender][s] = a;
        return true;
    }

    function transferFrom(address f, address t, uint256 a) external returns (bool) {
        uint256 al = allowance[f][msg.sender];
        if (al != type(uint256).max) {
            allowance[f][msg.sender] = al - a;
        }
        balanceOf[f] -= a;
        balanceOf[t] += a;
        return true;
    }
}

contract MockOracle {
    mapping(address => IOracle.DetailedReport) internal _reports;

    function setReport(address asset, uint224 priceD18, uint32 ts, bool suspicious) external {
        _reports[asset] = IOracle.DetailedReport(priceD18, ts, suspicious);
    }

    function getReport(address asset) external view returns (IOracle.DetailedReport memory) {
        return _reports[asset];
    }
}

contract MockFeeManager {
    uint256 public feeD6;
    address public feeRecipient;

    constructor(address r) {
        feeRecipient = r;
    }

    function setFee(uint256 f) external {
        feeD6 = f;
    }

    function calculateRedeemFee(uint256 amount) external view returns (uint256) {
        return (amount * feeD6) / 1e6;
    }
}

contract MockShareManager {
    uint256 public totalShares;
    mapping(address => uint256) public shares;

    function mint(address to, uint256 s) external {
        shares[to] += s;
        totalShares += s;
    }

    function burn(address from, uint256 s) external {
        shares[from] -= s;
        totalShares -= s;
    }
}

contract MockRiskManager {
    int256 public vaultBalance;

    function modifyVaultBalance(address, int256 delta) external {
        vaultBalance += delta;
    }
}

/// Stands in for the vault. Implements only what SyncRedeemQueue calls.
contract MockVault {
    MockToken public token;
    MockOracle internal _oracle;
    MockFeeManager internal _feeManager;
    MockShareManager internal _shareManager;
    MockRiskManager internal _riskManager;
    bool public paused;

    constructor(MockToken t, MockOracle o, MockFeeManager f, MockShareManager s, MockRiskManager r) {
        token = t;
        _oracle = o;
        _feeManager = f;
        _shareManager = s;
        _riskManager = r;
    }

    function oracle() external view returns (address) {
        return address(_oracle);
    }

    function feeManager() external view returns (address) {
        return address(_feeManager);
    }

    function shareManager() external view returns (address) {
        return address(_shareManager);
    }

    function riskManager() external view returns (address) {
        return address(_riskManager);
    }

    function isPausedQueue(address) external view returns (bool) {
        return paused;
    }

    function setPaused(bool p) external {
        paused = p;
    }

    function hasRole(bytes32, address) external pure returns (bool) {
        return true;
    }

    function getLiquidAssets() external view returns (uint256) {
        return token.balanceOf(address(this));
    }

    /// Mirrors ShareModule.callHook for a redeem queue: gather (no-op here,
    /// the vault already holds the liquidity) then forward to the queue.
    function callHook(uint256 assets) external {
        token.transfer(msg.sender, assets);
    }
}

/*//////////////////////////////////////////////////////////////
                             HANDLER
//////////////////////////////////////////////////////////////*/

contract Handler is Test {
    SyncRedeemQueue public queue;
    MockVault public vault;
    MockToken public token;
    MockOracle public oracle;
    MockShareManager public shareManager;
    MockFeeManager public feeManager;

    address[3] internal actors = [address(0xA1), address(0xA2), address(0xA3)];

    // Ghosts, in asset units.
    uint256 public ghost_assetsPaidOut;
    uint256 public ghost_grossValueBurned; // shares burned valued at the price used
    uint256 public ghost_redeemCount;
    uint256 public ghost_maxUsageSeen;

    constructor(SyncRedeemQueue q, MockVault v, MockToken t, MockOracle o, MockShareManager sm, MockFeeManager fm) {
        queue = q;
        vault = v;
        token = t;
        oracle = o;
        shareManager = sm;
        feeManager = fm;
    }

    function _actor(uint256 seed) internal view returns (address) {
        return actors[seed % 3];
    }

    function _price() internal view returns (uint224 p) {
        IOracle.DetailedReport memory r = oracle.getReport(address(token));
        return r.priceD18;
    }

    function h_redeem(uint256 actorSeed, uint256 shares) external {
        address a = _actor(actorSeed);
        uint256 bal = shareManager.shares(a);
        if (bal == 0) {
            return;
        }
        shares = bound(shares, 1, bal);

        uint224 priceD18 = _price();
        if (priceD18 == 0) {
            return;
        }

        uint256 before = token.balanceOf(a);
        vm.prank(a);
        try queue.redeem(shares, a) {
            uint256 paid = token.balanceOf(a) - before;
            ghost_assetsPaidOut += paid;
            // What the burned shares were worth at the very price the queue used.
            ghost_grossValueBurned += Math_mulDiv(shares, 1 ether, priceD18);
            ghost_redeemCount++;
            (,, uint256 usage,,) = queue.syncRedeemParams();
            if (usage > ghost_maxUsageSeen) {
                ghost_maxUsageSeen = usage;
            }
        } catch {}
    }

    /// Oracle moves, including sharply, but always fresh and non-suspicious so
    /// that redeem is reachable.
    function h_setPrice(uint256 p) external {
        uint224 priceD18 = uint224(bound(p, 1e15, 1e21));
        oracle.setReport(address(token), priceD18, uint32(block.timestamp), false);
    }

    function h_warp(uint256 dt) external {
        dt = bound(dt, 1, 3 days);
        vm.warp(block.timestamp + dt);
        // keep the report fresh so the staleness guard is not the binding
        // constraint for every action
        oracle.setReport(address(token), _price(), uint32(block.timestamp), false);
    }

    function h_setFee(uint256 f) external {
        feeManager.setFee(bound(f, 0, 1e5)); // up to 10%
    }

    function h_topUpVault(uint256 amt) external {
        token.mint(address(vault), bound(amt, 0, 1e24));
    }

    function Math_mulDiv(uint256 x, uint256 y, uint256 d) internal pure returns (uint256) {
        return (x * y) / d;
    }
}

/*//////////////////////////////////////////////////////////////
                            INVARIANTS

    Two properties only. Both are demonstrated by mutation testing to
    fail when a real defect is introduced into SyncRedeemQueue:

      * invert the penalty into a bonus  -> noValueExtraction fails
      * delete the daily-limit check     -> usageBoundedByDailyLimit fails

    Two further properties (share-supply conservation, vault solvency)
    were written, caught neither mutation, and were removed rather than
    shipped as coverage they do not provide.
//////////////////////////////////////////////////////////////*/

contract SyncRedeemQueueInvariants is Test {
    SyncRedeemQueue public queue;
    MockVault public vault;
    MockToken public token;
    MockOracle public oracle;
    MockShareManager public shareManager;
    MockFeeManager public feeManager;
    MockRiskManager public riskManager;
    Handler public handler;

    uint256 constant PENALTY_D6 = 1e4; // 1%
    uint32 constant MAX_AGE = 1 days;
    // `_setSyncRedeemParams` enforces `dailyLimit % 24 hours == 0`. Since
    // 86400 = 2^7 * 3^3 * 5^2, only multiples of 86400 in raw units are
    // accepted -- see test_DailyLimitRejectsEveryRoundTokenAmount below.
    uint256 constant DAILY_LIMIT = 24 hours * 1e18; // 8.64e22 raw units

    function setUp() public {
        vm.warp(1800000000);

        token = new MockToken();
        oracle = new MockOracle();
        shareManager = new MockShareManager();
        feeManager = new MockFeeManager(address(0xFEE));
        riskManager = new MockRiskManager();
        vault = new MockVault(token, oracle, feeManager, shareManager, riskManager);

        SyncRedeemQueue impl = new SyncRedeemQueue("SyncRedeemQueue", 1);
        bytes memory params = abi.encode(PENALTY_D6, MAX_AGE, DAILY_LIMIT);
        bytes memory init =
            abi.encodeCall(SyncRedeemQueue.initialize, (abi.encode(address(token), address(vault), params)));
        queue = SyncRedeemQueue(payable(address(new ERC1967Proxy(address(impl), init))));

        oracle.setReport(address(token), 1e18, uint32(block.timestamp), false);

        // Fund actors with shares and the vault with liquidity.
        shareManager.mint(address(0xA1), 1e24);
        shareManager.mint(address(0xA2), 1e24);
        shareManager.mint(address(0xA3), 1e24);
        token.mint(address(vault), 1e30);

        handler = new Handler(queue, vault, token, oracle, shareManager, feeManager);

        bytes4[] memory sel = new bytes4[](5);
        sel[0] = Handler.h_redeem.selector;
        sel[1] = Handler.h_setPrice.selector;
        sel[2] = Handler.h_warp.selector;
        sel[3] = Handler.h_setFee.selector;
        sel[4] = Handler.h_topUpVault.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: sel}));
        targetContract(address(handler));
    }

    /// FINDING (informational/low): the daily limit cannot be set to any
    /// human-natural token amount.
    ///
    /// `_setSyncRedeemParams` requires `dailyLimit % 24 hours == 0`. That is
    /// there to make the decay division `dailyLimit * timespan / 24 hours`
    /// exact. But 86400 = 2^7 * 3^3 * 5^2 carries the factor 27, while any
    /// amount of the form N * 10^18 is built only from 2s and 5s. So every
    /// round figure an operator would reach for is rejected, and the nearest
    /// accepted value can be far from the intended one -- 86400e18 is 86x
    /// larger than a wanted 1000e18. The risk is not the revert, it is an
    /// operator settling on a rate limit far more permissive than intended.
    function test_DailyLimitRejectsEveryRoundTokenAmount() public {
        uint256[4] memory natural = [uint256(100e18), 500e18, 1000e18, 1000000e18];
        for (uint256 i = 0; i < natural.length; i++) {
            assertTrue(natural[i] % 24 hours != 0, "expected non-divisible");
            vm.expectRevert(); // InvalidDailyLimit()
            queue.setSyncRedeemParams(PENALTY_D6, MAX_AGE, natural[i]);
        }
        // Only raw multiples of 86400 are reachable.
        queue.setSyncRedeemParams(PENALTY_D6, MAX_AGE, 24 hours * 1e18);
        (,,, uint256 dailyLimit,) = queue.syncRedeemParams();
        assertEq(dailyLimit, 24 hours * 1e18);
    }

    /// Proves the harness reaches the code under test. The handler swallows
    /// reverts by design, so a green invariant campaign means nothing unless a
    /// redeem is shown to succeed and to move value in the expected direction.
    function test_HarnessActuallyRedeems() public {
        uint256 sharesBefore = shareManager.shares(address(0xA1));
        uint256 assetsBefore = token.balanceOf(address(0xA1));

        vm.prank(address(0xA1));
        queue.redeem(1e18, address(0xA1));

        uint256 burned = sharesBefore - shareManager.shares(address(0xA1));
        uint256 paid = token.balanceOf(address(0xA1)) - assetsBefore;

        assertEq(burned, 1e18, "shares were not burned");
        assertGt(paid, 0, "no assets were paid out");
        // 1% penalty at price 1e18 => strictly less than the gross value.
        assertLt(paid, 1e18, "payout was not reduced by the penalty");
        emit log_named_uint("assets paid for 1e18 shares", paid);

        (,, uint256 usage,,) = queue.syncRedeemParams();
        assertEq(usage, 1e18, "daily-limit usage was not charged");
    }

    /// A redeemer must never receive more asset value than the shares they
    /// burned were worth at the price the queue itself used. The penalty and
    /// the redeem fee should make the payout strictly smaller; equality is
    /// only reachable when both are zero.
    function invariant_noValueExtraction() public view {
        assertLe(
            handler.ghost_assetsPaidOut(),
            handler.ghost_grossValueBurned(),
            "redeemer extracted more than the burned shares were worth"
        );
    }

    /// The leaky-bucket accumulator must never exceed the configured cap,
    /// whatever the ordering of redeems, time warps and parameter changes.
    function invariant_usageBoundedByDailyLimit() public view {
        (,, uint256 usage, uint256 dailyLimit,) = queue.syncRedeemParams();
        assertLe(usage, dailyLimit, "daily-limit accumulator exceeded its cap");
    }
}
