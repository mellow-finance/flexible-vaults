// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Test} from "forge-std/Test.sol";

import {IOracle} from "../src/interfaces/oracles/IOracle.sol";
import {SyncDepositQueue} from "../src/queues/SyncDepositQueue.sol";

/*//////////////////////////////////////////////////////////////
                              MOCKS

    Same approach as SyncRedeemQueueInvariants: the contract under
    test is the real one, only its collaborators are simulated. The
    mocks expose the exact selectors SyncDepositQueue calls, without
    inheriting the full interfaces.
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

    function calculateDepositFee(uint256 amount) external view returns (uint256) {
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

    function isDepositorWhitelisted(address, bytes32[] calldata) external pure returns (bool) {
        return true;
    }
}

contract MockRiskManager {
    int256 public vaultBalance;

    function modifyVaultBalance(address, int256 delta) external {
        vaultBalance += delta;
    }
}

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

    /// On the deposit path ShareModule.callHook only delegates to the hook and
    /// does not move assets back to the queue, so this is a no-op.
    function callHook(uint256) external {}
}

/*//////////////////////////////////////////////////////////////
                             HANDLER
//////////////////////////////////////////////////////////////*/

contract Handler is Test {
    SyncDepositQueue public queue;
    MockVault public vault;
    MockToken public token;
    MockOracle public oracle;
    MockShareManager public shareManager;
    MockFeeManager public feeManager;

    address[3] internal actors = [address(0xA1), address(0xA2), address(0xA3)];

    uint256 public ghost_sharesMintedToDepositors;
    uint256 public ghost_grossSharesAtRawPrice;
    uint256 public ghost_assetsPulledFromDepositors;
    uint256 public ghost_depositCount;

    constructor(SyncDepositQueue q, MockVault v, MockToken t, MockOracle o, MockShareManager sm, MockFeeManager fm) {
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

    function _price() internal view returns (uint224) {
        return oracle.getReport(address(token)).priceD18;
    }

    function h_deposit(uint256 actorSeed, uint256 assets) external {
        address a = _actor(actorSeed);
        assets = bound(assets, 1e6, 1e24);
        uint224 priceD18 = _price();
        if (priceD18 == 0) {
            return;
        }

        token.mint(a, assets);
        uint256 sharesBefore = shareManager.shares(a);
        uint256 assetsBefore = token.balanceOf(a);

        vm.startPrank(a);
        token.approve(address(queue), assets);
        bytes32[] memory proof = new bytes32[](0);
        try queue.deposit(uint224(assets), address(0), proof) {
            ghost_sharesMintedToDepositors += shareManager.shares(a) - sharesBefore;
            // What the deposited assets would buy at the UNPENALISED oracle price.
            ghost_grossSharesAtRawPrice += (assets * uint256(priceD18)) / 1 ether;
            ghost_assetsPulledFromDepositors += assetsBefore - token.balanceOf(a);
            ghost_depositCount++;
        } catch {}
        vm.stopPrank();
    }

    function h_setPrice(uint256 p) external {
        uint224 priceD18 = uint224(bound(p, 1e15, 1e21));
        oracle.setReport(address(token), priceD18, uint32(block.timestamp), false);
    }

    function h_warp(uint256 dt) external {
        dt = bound(dt, 1, 3 days);
        vm.warp(block.timestamp + dt);
        oracle.setReport(address(token), _price(), uint32(block.timestamp), false);
    }

    function h_setFee(uint256 f) external {
        feeManager.setFee(bound(f, 0, 1e5));
    }
}

/*//////////////////////////////////////////////////////////////
                            INVARIANTS

    Two properties, both demonstrated by mutation testing to fail
    when a real defect is introduced into SyncDepositQueue:

      * invert the penalty into a bonus -> noFreeShares fails
      * skip the transfer to the vault  -> assetsReachTheVault fails
//////////////////////////////////////////////////////////////*/

contract SyncDepositQueueInvariants is Test {
    SyncDepositQueue public queue;
    MockVault public vault;
    MockToken public token;
    MockOracle public oracle;
    MockShareManager public shareManager;
    MockFeeManager public feeManager;
    MockRiskManager public riskManager;
    Handler public handler;

    uint256 constant PENALTY_D6 = 1e4; // 1%
    uint32 constant MAX_AGE = 1 days;

    function setUp() public {
        vm.warp(1800000000);

        token = new MockToken();
        oracle = new MockOracle();
        shareManager = new MockShareManager();
        feeManager = new MockFeeManager(address(0xFEE));
        riskManager = new MockRiskManager();
        vault = new MockVault(token, oracle, feeManager, shareManager, riskManager);

        SyncDepositQueue impl = new SyncDepositQueue("SyncDepositQueue", 1);
        bytes memory params = abi.encode(PENALTY_D6, MAX_AGE);
        bytes memory init =
            abi.encodeCall(SyncDepositQueue.initialize, (abi.encode(address(token), address(vault), params)));
        queue = SyncDepositQueue(payable(address(new ERC1967Proxy(address(impl), init))));

        oracle.setReport(address(token), 1e18, uint32(block.timestamp), false);

        handler = new Handler(queue, vault, token, oracle, shareManager, feeManager);

        bytes4[] memory sel = new bytes4[](4);
        sel[0] = Handler.h_deposit.selector;
        sel[1] = Handler.h_setPrice.selector;
        sel[2] = Handler.h_warp.selector;
        sel[3] = Handler.h_setFee.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: sel}));
        targetContract(address(handler));
    }

    /// Liveness. Without this a green campaign proves nothing: the handler
    /// swallows reverts, so every deposit could be failing silently.
    function test_HarnessActuallyDeposits() public {
        address a = address(0xA1);
        token.mint(a, 1e18);

        vm.startPrank(a);
        token.approve(address(queue), 1e18);
        bytes32[] memory proof = new bytes32[](0);
        queue.deposit(uint224(1e18), address(0), proof);
        vm.stopPrank();

        uint256 got = shareManager.shares(a);
        assertGt(got, 0, "no shares were minted");
        // 1% penalty at price 1e18 => strictly fewer shares than the raw price.
        assertLt(got, 1e18, "shares were not reduced by the penalty");
        assertEq(token.balanceOf(address(vault)), 1e18, "assets did not reach the vault");
        emit log_named_uint("shares minted for 1e18 assets", got);
    }

    /// A depositor must never receive more shares than their assets were worth
    /// at the *unpenalised* oracle price. The deposit penalty and the deposit
    /// fee should make the minted amount strictly smaller; equality is only
    /// reachable when both are zero.
    function invariant_noFreeShares() public view {
        assertLe(
            handler.ghost_sharesMintedToDepositors(),
            handler.ghost_grossSharesAtRawPrice(),
            "depositor minted more shares than the raw price would give"
        );
    }

    /// Every asset taken from a depositor must end up in the vault. The queue
    /// pulls to itself and forwards; it must never retain a balance.
    function invariant_assetsReachTheVault() public view {
        assertEq(
            token.balanceOf(address(vault)),
            handler.ghost_assetsPulledFromDepositors(),
            "assets pulled from depositors did not all reach the vault"
        );
        assertEq(token.balanceOf(address(queue)), 0, "queue retained assets");
    }
}
