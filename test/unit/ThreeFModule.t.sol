// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Test.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {Offer} from "../../scripts/common/interfaces/3F/IOfferReceiver.sol";
import {IWhitelist} from "../../scripts/common/interfaces/3F/IWhitelist.sol";
import {IThreeFModule} from "../../src/interfaces/utils/IThreeFModule.sol";
import "../../src/utils/ThreeFModule.sol";

// ─── Mocks ────────────────────────────────────────────────────────────────────

contract MockToken is ERC20 {
    constructor() ERC20("Mock", "MTK") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function test() internal pure {}
}

contract MockWhitelist {
    mapping(address => IWhitelist.WhitelistStatus) private _status;

    function set(address a, IWhitelist.WhitelistStatus s) external {
        _status[a] = s;
    }

    function isWhitelisted(address a) external view returns (IWhitelist.WhitelistStatus) {
        return _status[a];
    }

    function test() internal pure {}
}

contract MockRequestFactory {
    mapping(address => bool) private _isRequest;

    function set(address r, bool v) external {
        _isRequest[r] = v;
    }

    function isRequest(address r) external view returns (bool) {
        return _isRequest[r];
    }

    function test() internal pure {}
}

contract MockRequest {
    address public assetAddr;
    bool public _isRepaid;
    bool public _canWithdraw;
    uint128 public authPt;
    uint128 public authYt;
    uint128 public _balPt;
    uint128 public _balYt;
    uint256 public ytReturn;
    uint256 public burnPtS;
    uint256 public burnYtS;
    uint256 public burnPA;
    uint256 public burnYA;
    uint256 public lastNonce;

    function setAsset(address a) external {
        assetAddr = a;
    }

    function setRepaid(bool v) external {
        _isRepaid = v;
    }

    function setCanWithdraw(bool v) external {
        _canWithdraw = v;
    }

    function setMintAuth(uint128 pt, uint128 yt) external {
        authPt = pt;
        authYt = yt;
    }

    function setBalances(uint128 pt, uint128 yt) external {
        _balPt = pt;
        _balYt = yt;
    }

    function setYtReturn(uint256 v) external {
        ytReturn = v;
    }

    function setBurnReturn(uint256 pts, uint256 yts, uint256 pa, uint256 ya) external {
        burnPtS = pts;
        burnYtS = yts;
        burnPA = pa;
        burnYA = ya;
    }

    function asset() external view returns (address) {
        return assetAddr;
    }

    function isRepaid() external view returns (bool) {
        return _isRepaid;
    }

    function canWithdraw() external view returns (bool) {
        return _canWithdraw;
    }

    function mintAuthorization(address) external view returns (uint128, uint128) {
        return (authPt, authYt);
    }

    function balancesOf(address) external view returns (uint128, uint128) {
        return (_balPt, _balYt);
    }

    function convertToAssets(uint256 pt, uint256 yt) external pure returns (uint256, uint256) {
        return (pt, yt);
    }

    function mint(uint128, uint128) external {
        IERC20(assetAddr).transferFrom(msg.sender, address(this), authPt);
        _balPt += authPt;
    }

    function consume(Offer calldata offer, bytes calldata, uint256 ptAmount) external returns (uint256) {
        bytes4 magic = IERC1271(offer.maker).isValidSignature(keccak256(abi.encode(offer)), "");
        require(magic == bytes4(0x1626ba7e), "MockRequest: bad sig");
        IERC20(assetAddr).transferFrom(offer.maker, address(this), ptAmount);
        _balPt += uint128(ptAmount);
        return ytReturn;
    }

    function burnAll(address, address receiver) external returns (uint256, uint256, uint256, uint256) {
        uint256 total = burnPA + burnYA;
        if (total > 0) {
            IERC20(assetAddr).transfer(receiver, total);
        }
        _balPt = 0;
        _balYt = 0;
        return (burnPtS, burnYtS, burnPA, burnYA);
    }

    function setNonce(uint256 n) external {
        lastNonce = n;
    }

    function test() internal pure {}
}

// ─── Test ─────────────────────────────────────────────────────────────────────

contract ThreeFModuleTest is Test {
    address admin = vm.createWallet("admin").addr;
    address curator = vm.createWallet("curator").addr;
    address subvault = vm.createWallet("subvault").addr;
    address stranger = vm.createWallet("stranger").addr;

    MockToken token;
    MockWhitelist whitelist;
    MockRequestFactory factory;
    MockRequest request;
    ThreeFModule module;

    function setUp() public {
        token = new MockToken();
        whitelist = new MockWhitelist();
        factory = new MockRequestFactory();
        request = new MockRequest();

        request.setAsset(address(token));
        request.setMintAuth(100e18, 10e18);
        factory.set(address(request), true);
        whitelist.set(address(request), IWhitelist.WhitelistStatus.Whitelisted);

        ThreeFModule impl = new ThreeFModule("Mellow", 1, address(token));
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(impl), admin, new bytes(0));
        module = ThreeFModule(address(proxy));
        module.initialize(_initData(admin, subvault, address(whitelist), address(factory), curator));
    }

    function _initData(address admin_, address subvault_, address whitelist_, address factory_, address curator_)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(admin_, subvault_, whitelist_, factory_, curator_);
    }

    function _offer(uint256 amount, uint256 nonce) internal view returns (Offer memory) {
        return Offer({
            maker: address(module),
            amount: amount,
            expectedReturn: amount / 10,
            nonce: nonce,
            expiration: block.timestamp + 1 hours,
            useCallback: false
        });
    }

    // ─── constructor ──────────────────────────────────────────────────────────

    function testConstructor() external {
        ThreeFModule impl = new ThreeFModule("Mellow", 1, address(token));
        assertEq(impl.asset(), address(token));
    }

    function testConstructor_ZeroAsset() external {
        vm.expectRevert(IThreeFModule.ZeroValue.selector);
        new ThreeFModule("Mellow", 1, address(0));
    }

    // ─── initialize ───────────────────────────────────────────────────────────

    function testInitialize_StorageAndRoles() external view {
        /// @dev module is already initialized in setUp(), this just checks the storage values and roles were set correctly.
        assertEq(module.subvault(), subvault);
        assertEq(module.whitelist(), address(whitelist));
        assertEq(module.requestFactory(), address(factory));
        assertEq(module.asset(), address(token));
        assertTrue(module.hasRole(module.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(module.hasRole(module.CALLER_ROLE(), curator));
    }

    function testInitialize_DoubleInit() external {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        module.initialize(_initData(admin, subvault, address(whitelist), address(factory), curator));
    }

    function testInitialize_ZeroAdmin() external {
        _expectZeroValueOnFreshProxy(address(0), subvault, address(whitelist), address(factory), curator);
    }

    function testInitialize_ZeroSubvault() external {
        _expectZeroValueOnFreshProxy(admin, address(0), address(whitelist), address(factory), curator);
    }

    function testInitialize_ZeroWhitelist() external {
        _expectZeroValueOnFreshProxy(admin, subvault, address(0), address(factory), curator);
    }

    function testInitialize_ZeroFactory() external {
        _expectZeroValueOnFreshProxy(admin, subvault, address(whitelist), address(0), curator);
    }

    function testInitialize_ZeroCurator() external {
        _expectZeroValueOnFreshProxy(admin, subvault, address(whitelist), address(factory), address(0));
    }

    function _expectZeroValueOnFreshProxy(
        address admin_,
        address subvault_,
        address whitelist_,
        address factory_,
        address curator_
    ) internal {
        ThreeFModule impl = new ThreeFModule("Mellow", 2, address(token));
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(impl), admin, new bytes(0));
        vm.expectRevert(IThreeFModule.ZeroValue.selector);
        ThreeFModule(address(proxy)).initialize(_initData(admin_, subvault_, whitelist_, factory_, curator_));
    }

    // ─── isRequestAllowed ─────────────────────────────────────────────────────

    function testIsRequestAllowed_BothValid() external view {
        assertTrue(module.isRequestAllowed(address(request)));
    }

    function testIsRequestAllowed_NotInFactory() external {
        factory.set(address(request), false);
        assertFalse(module.isRequestAllowed(address(request)));
    }

    function testIsRequestAllowed_NotWhitelisted() external {
        whitelist.set(address(request), IWhitelist.WhitelistStatus.NotWhitelisted);
        assertFalse(module.isRequestAllowed(address(request)));
    }

    function testIsRequestAllowed_PausedWhitelisted() external {
        whitelist.set(address(request), IWhitelist.WhitelistStatus.PausedWhitelisted);
        assertFalse(module.isRequestAllowed(address(request)));
    }

    function testIsRequestAllowed_PausedNotWhitelisted() external {
        whitelist.set(address(request), IWhitelist.WhitelistStatus.PausedNotWhitelisted);
        assertFalse(module.isRequestAllowed(address(request)));
    }

    function testIsRequestAllowed_Unknown() external view {
        assertFalse(module.isRequestAllowed(address(0xdead)));
    }

    // ─── pushAssets ───────────────────────────────────────────────────────────

    function testPushAssets_NotSubvault() external {
        vm.prank(stranger);
        vm.expectRevert(IThreeFModule.NotSubvault.selector);
        module.pushAssets(1e18);
    }

    function testPushAssets_Happy() external {
        uint256 amount = 100e18;
        token.mint(subvault, amount);
        vm.startPrank(subvault);
        token.approve(address(module), amount);
        module.pushAssets(amount);
        vm.stopPrank();
        assertEq(token.balanceOf(address(module)), amount);
        assertEq(token.balanceOf(subvault), 0);
    }

    // ─── pullAssets ───────────────────────────────────────────────────────────

    function testPullAssets_NotSubvault() external {
        vm.prank(stranger);
        vm.expectRevert(IThreeFModule.NotSubvault.selector);
        module.pullAssets(1e18);
    }

    function testPullAssets_Happy() external {
        uint256 amount = 50e18;
        token.mint(address(module), amount);
        vm.prank(subvault);
        module.pullAssets(amount);
        assertEq(token.balanceOf(subvault), amount);
        assertEq(token.balanceOf(address(module)), 0);
    }

    // ─── push ─────────────────────────────────────────────────────────────────

    function testPush_NotCaller() external {
        uint128 authPt = 100e18;
        token.mint(address(module), authPt);
        bytes32 callerRole = module.CALLER_ROLE();
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, stranger, callerRole)
        );
        module.push(address(request), authPt, 10e18);
    }

    function testPush_RequestNotAllowed() external {
        factory.set(address(request), false);
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.NotAllowedRequest.selector);
        module.push(address(request), 100e18, 10e18);
    }

    function testPush_AssetMismatch() external {
        request.setAsset(address(0xdead));
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.AssetMismatch.selector);
        module.push(address(request), 100e18, 10e18);
    }

    function testPush_InsufficientPtAuthorization() external {
        uint128 maxPt = 100e18;
        uint128 minYt = 10e18;
        request.setMintAuth(maxPt - 1, minYt); // authPt one below maxPt
        token.mint(address(module), 200e18);
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.InsufficientPtAuthorization.selector);
        module.push(address(request), maxPt, minYt);
    }

    function testPush_InsufficientYtAuthorization() external {
        uint128 maxPt = 100e18;
        uint128 minYt = 10e18;
        request.setMintAuth(maxPt, minYt - 1); // authYt one below minYt
        token.mint(address(module), 200e18);
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.InsufficientYtAuthorization.selector);
        module.push(address(request), maxPt, minYt);
    }

    function testPush_InsufficientBalance() external {
        uint128 maxPt = 100e18;
        token.mint(address(module), maxPt - 1); // one below authPt
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.InsufficientBalance.selector);
        module.push(address(request), maxPt, 10e18);
    }

    function testPush_Happy() external {
        uint128 maxPt = 100e18;
        uint128 minYt = 10e18;
        token.mint(address(module), maxPt);
        request.setBalances(0, 0);

        vm.expectEmit(true, false, false, true, address(module));
        emit IThreeFModule.Pushed(address(request), maxPt, minYt, maxPt, 0);

        vm.prank(curator);
        module.push(address(request), maxPt, minYt);

        assertEq(token.balanceOf(address(module)), 0);
        assertEq(token.balanceOf(address(request)), maxPt);
        assertEq(token.allowance(address(module), address(request)), 0);
        assertEq(module.activeRequestsCount(), 1);
        assertEq(module.activeRequestAt(0), address(request));
    }

    function testPush_DoesNotDuplicateActiveRequest() external {
        uint128 maxPt = 100e18;
        uint128 minYt = 10e18;
        token.mint(address(module), maxPt);
        vm.prank(curator);
        module.push(address(request), maxPt, minYt);

        token.mint(address(module), maxPt);
        vm.prank(curator);
        module.push(address(request), maxPt, minYt);

        assertEq(module.activeRequestsCount(), 1);
    }

    // ─── pull ─────────────────────────────────────────────────────────────────

    function testPull_NotCaller() external {
        uint256 ptAmount = 50e18;
        token.mint(address(module), 100e18);
        Offer memory offer = _offer(80e18, 1);
        bytes32 callerRole = module.CALLER_ROLE();
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, stranger, callerRole)
        );
        module.pull(address(request), offer, ptAmount, 1e18);
    }

    function testPull_RequestNotAllowed() external {
        uint256 ptAmount = 50e18;
        factory.set(address(request), false);
        token.mint(address(module), 100e18);
        Offer memory offer = _offer(80e18, 1);
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.NotAllowedRequest.selector);
        module.pull(address(request), offer, ptAmount, 1e18);
    }

    function testPull_AssetMismatch() external {
        uint256 ptAmount = 50e18;
        request.setAsset(address(0xdead));
        token.mint(address(module), 100e18);
        Offer memory offer = _offer(80e18, 1);
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.AssetMismatch.selector);
        module.pull(address(request), offer, ptAmount, 1e18);
    }

    function testPull_InvalidMaker() external {
        uint256 ptAmount = 50e18;
        token.mint(address(module), 100e18);
        Offer memory offer = _offer(80e18, 1);
        offer.maker = stranger;
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.InvalidMaker.selector);
        module.pull(address(request), offer, ptAmount, 1e18);
    }

    function testPull_CallbackNotAllowed() external {
        uint256 ptAmount = 50e18;
        token.mint(address(module), 100e18);
        Offer memory offer = _offer(80e18, 1);
        offer.useCallback = true;
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.CallbackNotAllowed.selector);
        module.pull(address(request), offer, ptAmount, 1e18);
    }

    function testPull_Expired() external {
        uint256 ptAmount = 50e18;
        token.mint(address(module), 100e18);
        Offer memory offer = _offer(80e18, 1);
        offer.expiration = block.timestamp - 1;
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.OfferExpired.selector);
        module.pull(address(request), offer, ptAmount, 1e18);
    }

    function testPull_ExceedsAmount() external {
        uint256 ptAmount = 50e18;
        token.mint(address(module), 100e18);
        Offer memory offer = _offer(ptAmount - 1, 1); // offer.amount one below ptAmount
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.ExceedsOfferAmount.selector);
        module.pull(address(request), offer, ptAmount, 1e18);
    }

    function testPull_StaleNonce() external {
        uint256 ptAmount = 50e18;
        token.mint(address(module), 100e18);
        Offer memory offer = _offer(80e18, 0); // nonce=0, stored=0
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.StaleNonce.selector);
        module.pull(address(request), offer, ptAmount, 1e18);
    }

    function testPull_InsufficientBalance() external {
        uint256 ptAmount = 50e18;
        token.mint(address(module), ptAmount - 1); // one below ptAmount
        Offer memory offer = _offer(80e18, 1);
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.InsufficientBalance.selector);
        module.pull(address(request), offer, ptAmount, 1e18);
    }

    function testPull_InsufficientYt() external {
        uint256 ptAmount = 50e18;
        uint256 minYt = 5e18;
        token.mint(address(module), 100e18);
        request.setYtReturn(minYt - 1); // one below minYt
        Offer memory offer = _offer(80e18, 1);
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.InsufficientYt.selector);
        module.pull(address(request), offer, ptAmount, minYt);
    }

    function testPull_Happy() external {
        uint256 ptAmount = 50e18;
        uint256 ytAmount = 8e18;
        token.mint(address(module), 100e18);
        request.setYtReturn(ytAmount);
        Offer memory offer = _offer(80e18, 1);

        vm.expectEmit(true, false, false, true, address(module));
        emit IThreeFModule.Pulled(address(request), ptAmount, ytAmount);

        vm.prank(curator);
        module.pull(address(request), offer, ptAmount, 1e18);

        assertEq(token.balanceOf(address(module)), 50e18);
        assertEq(token.balanceOf(address(request)), ptAmount);
        assertEq(token.allowance(address(module), address(request)), 0);
        assertEq(module.activeRequestsCount(), 1);
    }

    function testPull_PartialFill() external {
        uint256 ptAmount = 30e18;
        token.mint(address(module), 100e18);
        request.setYtReturn(3e18);
        Offer memory offer = _offer(80e18, 1); // pull only 30 of 80

        vm.prank(curator);
        module.pull(address(request), offer, ptAmount, 1e18);

        assertEq(token.balanceOf(address(module)), 100e18 - ptAmount);
        assertEq(token.balanceOf(address(request)), ptAmount);
    }

    function testPull_NonceAdvancesAfterCancel() external {
        uint256 ptAmount = 50e18;
        vm.prank(curator);
        module.cancelOffer(address(request)); // stored nonce → 1

        token.mint(address(module), 100e18);
        request.setYtReturn(5e18);

        Offer memory stale = _offer(80e18, 1); // nonce=1 == stored
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.StaleNonce.selector);
        module.pull(address(request), stale, ptAmount, 1e18);

        Offer memory fresh = _offer(80e18, 2); // nonce=2 > stored=1
        vm.prank(curator);
        module.pull(address(request), fresh, ptAmount, 1e18);
        assertEq(token.balanceOf(address(request)), ptAmount);
    }

    // ─── isValidSignature ─────────────────────────────────────────────────────

    function testIsValidSignature_OutsidePull() external view {
        assertEq(module.isValidSignature(keccak256("test"), ""), bytes4(0xffffffff));
    }

    function testIsValidSignature_UnauthorizedCaller() external {
        // Non-whitelisted caller even if flag were set externally — returns INVALID
        vm.prank(stranger);
        assertEq(module.isValidSignature(keccak256("test"), ""), bytes4(0xffffffff));
    }

    // isValidSignature returning magic value during pull is verified implicitly
    // by testPull_Happy: mock request validates it inside consume() and reverts if wrong.

    // ─── burn ─────────────────────────────────────────────────────────────────

    function _setupBurn() internal {
        uint128 authPt = 100e18;
        uint128 authYt = 10e18;
        token.mint(address(module), authPt);
        vm.prank(curator);
        module.push(address(request), authPt, authYt);
        request.setRepaid(true);
        request.setCanWithdraw(true);
        request.setBurnReturn(authPt, authYt, 90e18, authYt); // pAssets+yAssets = 100
    }

    function testBurn_NotCaller() external {
        _setupBurn();
        bytes32 callerRole = module.CALLER_ROLE();
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, stranger, callerRole)
        );
        module.burn(address(request), 0);
    }

    function testBurn_RequestNotAllowed() external {
        _setupBurn();
        factory.set(address(request), false);
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.NotAllowedRequest.selector);
        module.burn(address(request), 0);
    }

    function testBurn_NotRepaid() external {
        _setupBurn();
        request.setRepaid(false);
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.NotRepaid.selector);
        module.burn(address(request), 0);
    }

    function testBurn_CannotWithdraw() external {
        _setupBurn();
        request.setCanWithdraw(false);
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.WithdrawalNotAllowed.selector);
        module.burn(address(request), 0);
    }

    function testBurn_InsufficientOutput() external {
        _setupBurn(); // returns pAssets=90e18 + yAssets=10e18 = 100e18 total
        uint256 actualOutput = 90e18 + 10e18;
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.InsufficientOutput.selector);
        module.burn(address(request), actualOutput + 1); // one above actual
    }

    function testBurn_Happy() external {
        uint256 totalOut = 100e18;
        _setupBurn();

        vm.expectEmit(true, false, false, true, address(module));
        emit IThreeFModule.Burned(address(request), 100e18, 10e18, 90e18, 10e18);

        vm.prank(curator);
        module.burn(address(request), totalOut);

        assertEq(token.balanceOf(address(module)), totalOut); // assets returned to module
        assertEq(module.activeRequestsCount(), 0);
        assertEq(token.allowance(address(module), address(request)), 0);
    }

    function testBurn_ZeroMinAssetOut() external {
        _setupBurn();
        vm.prank(curator);
        module.burn(address(request), 0); // no slippage check
        assertEq(module.activeRequestsCount(), 0);
    }

    // ─── cancelOffer ──────────────────────────────────────────────────────────

    function testCancelOffer_NotCaller() external {
        bytes32 callerRole = module.CALLER_ROLE();
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, stranger, callerRole)
        );
        module.cancelOffer(address(request));
    }

    function testCancelOffer_RequestNotAllowed() external {
        factory.set(address(request), false);
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.NotAllowedRequest.selector);
        module.cancelOffer(address(request));
    }

    function testCancelOffer_Happy() external {
        assertEq(module.nonce(address(request)), 0);

        vm.prank(curator);
        module.cancelOffer(address(request));
        assertEq(module.nonce(address(request)), 1);
        assertEq(request.lastNonce(), 1);

        vm.prank(curator);
        module.cancelOffer(address(request));
        assertEq(module.nonce(address(request)), 2);
        assertEq(request.lastNonce(), 2);
    }

    function testCancelOffer_PerRequestIndependence() external {
        MockRequest request2 = new MockRequest();
        request2.setAsset(address(token));
        factory.set(address(request2), true);
        whitelist.set(address(request2), IWhitelist.WhitelistStatus.Whitelisted);

        vm.prank(curator);
        module.cancelOffer(address(request)); // nonce[request]=1

        assertEq(module.nonce(address(request)), 1);
        assertEq(module.nonce(address(request2)), 0); // unaffected
    }

    // ─── balance / view helpers ───────────────────────────────────────────────

    function testBalance_Empty() external view {
        assertEq(module.balance(0, 10), 0);
    }

    function testBalance_SingleRequest() external {
        uint128 authPt = 100e18;
        token.mint(address(module), authPt);
        vm.prank(curator);
        module.push(address(request), authPt, 10e18);
        // convertToAssets returns (balPt, balYt) = (authPt, 0)
        assertEq(module.balance(0, 10), authPt);
    }

    function testBalance_Pagination() external {
        MockRequest request2 = new MockRequest();
        request2.setAsset(address(token));
        request2.setMintAuth(50e18, 5e18);
        factory.set(address(request2), true);
        whitelist.set(address(request2), IWhitelist.WhitelistStatus.Whitelisted);

        token.mint(address(module), 150e18);
        vm.startPrank(curator);
        module.push(address(request), 100e18, 10e18);
        module.push(address(request2), 50e18, 5e18);
        vm.stopPrank();

        assertEq(module.activeRequestsCount(), 2);
        assertEq(module.balance(0, 2), 150e18);
        assertEq(module.balance(0, 1) + module.balance(1, 1), 150e18);
        assertEq(module.balance(2, 10), 0); // offset past end
    }

    function testBalance_LimitClamp() external {
        uint128 authPt = 100e18;
        token.mint(address(module), authPt);
        vm.prank(curator);
        module.push(address(request), authPt, 10e18);
        // limit=100 but only 1 request — should not revert
        assertEq(module.balance(0, 100), authPt);
    }

    function testMintAuthorization() external view {
        (uint128 pt, uint128 yt) = module.mintAuthorization(address(request));
        assertEq(pt, 100e18);
        assertEq(yt, 10e18);
    }

    function testBalancesOf() external {
        request.setBalances(42e18, 7e18);
        (uint128 pt, uint128 yt) = module.balancesOf(address(request));
        assertEq(pt, 42e18);
        assertEq(yt, 7e18);
    }

    function testConvertToAssets() external {
        request.setBalances(60e18, 20e18);
        (uint256 pAssets, uint256 yAssets) = module.convertToAssets(address(request));
        assertEq(pAssets, 60e18);
        assertEq(yAssets, 20e18);
    }
}
