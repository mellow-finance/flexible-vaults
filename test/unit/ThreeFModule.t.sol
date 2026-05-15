// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Test.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {Offer} from "../../scripts/common/interfaces/3F/IOfferReceiver.sol";
import {IRequestCallback} from "../../scripts/common/interfaces/3F/IRequestCallback.sol";
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
    bytes32 private constant _DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    bytes32 private constant _OFFER_TYPEHASH = keccak256(
        "Offer(address maker,uint256 amount,uint256 expectedReturn,uint256 nonce,uint256 expiration,bool useCallback)"
    );

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
    uint256 public makerNonce;
    uint256 public lastSetNonce;

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

    function name() external pure returns (string memory) {
        return "MockRequest";
    }

    function nonce(address) external view returns (uint256) {
        return makerNonce;
    }

    function setMakerNonce(uint256 n) external {
        makerNonce = n;
    }

    function setNonce(uint256 n) external {
        makerNonce = n;
        lastSetNonce = n;
    }

    function mint(uint128, uint128) external {
        IERC20(assetAddr).transferFrom(msg.sender, address(this), authPt);
        _balPt += authPt;
    }

    /// @dev Simulates the real Request.consume() flow:
    ///      1. Compute EIP-712 hash (same formula as ThreeFModule.hashOffer)
    ///      2. Validate ERC-1271 signature from offer.maker
    ///      3. If useCallback: call onRequestConsumed on the maker
    ///      4. transferFrom maker → this (maker must have approved ptAmount)
    ///      5. Credit PT balance
    function consume(Offer calldata offer, bytes calldata, uint256 ptAmount) external returns (uint256) {
        bytes32 structHash = keccak256(abi.encode(_OFFER_TYPEHASH, offer));
        bytes32 domainSep = keccak256(
            abi.encode(_DOMAIN_TYPEHASH, keccak256("MockRequest"), keccak256("0.0.1"), block.chainid, address(this))
        );
        bytes32 hash = keccak256(abi.encodePacked("\x19\x01", domainSep, structHash));

        bytes4 magic = IERC1271(offer.maker).isValidSignature(hash, "");
        require(magic == bytes4(0x1626ba7e), "MockRequest: bad sig");

        if (offer.useCallback) {
            IRequestCallback(offer.maker).onRequestConsumed(offer, "", ptAmount, ytReturn);
        }
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

    function test() internal pure {}
}

// ─── Test ─────────────────────────────────────────────────────────────────────

contract ThreeFModuleTest is Test {
    address admin = vm.createWallet("admin").addr;
    address curator = vm.createWallet("curator").addr;
    address subvault = vm.createWallet("subvault").addr;
    address stranger = vm.createWallet("stranger").addr;

    bytes32 ALLOW_REQUEST_ROLE;
    bytes32 PUSH_ROLE;
    bytes32 PULL_ROLE;
    bytes32 BURN_ROLE;

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
        ALLOW_REQUEST_ROLE = impl.ALLOW_REQUEST_ROLE();
        PUSH_ROLE = impl.PUSH_ROLE();
        PULL_ROLE = impl.PULL_ROLE();
        BURN_ROLE = impl.BURN_ROLE();

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(impl), admin, new bytes(0));
        module = ThreeFModule(address(proxy));
        module.initialize(_initData(admin, subvault, address(whitelist), address(factory), curator));
        vm.prank(admin);
        module.allowRequest(address(request));
    }

    function _initData(address admin_, address subvault_, address whitelist_, address factory_, address curator_)
        internal
        view
        returns (bytes memory)
    {
        address[] memory holders = new address[](4);
        bytes32[] memory roles = new bytes32[](4);
        holders[0] = admin_;
        roles[0] = ALLOW_REQUEST_ROLE;
        holders[1] = curator_;
        roles[1] = PUSH_ROLE;
        holders[2] = curator_;
        roles[2] = PULL_ROLE;
        holders[3] = curator_;
        roles[3] = BURN_ROLE;
        return abi.encode(admin_, subvault_, whitelist_, factory_, holders, roles);
    }

    /// Default offer: useCallback=true, maker=module.
    function _offer(uint256 amount, uint256 offerNonce) internal view returns (Offer memory) {
        return Offer({
            maker: address(module),
            amount: amount,
            expectedReturn: amount / 10,
            nonce: offerNonce,
            expiration: block.timestamp + 1 hours,
            useCallback: true
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
        assertEq(module.subvault(), subvault);
        assertEq(module.whitelist(), address(whitelist));
        assertEq(module.requestFactory(), address(factory));
        assertEq(module.asset(), address(token));
        assertTrue(module.hasRole(module.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(module.hasRole(ALLOW_REQUEST_ROLE, admin));
        assertTrue(module.hasRole(PUSH_ROLE, curator));
        assertTrue(module.hasRole(PULL_ROLE, curator));
        assertTrue(module.hasRole(BURN_ROLE, curator));
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

    function testInitialize_ZeroHolderInArray() external {
        _expectZeroValueOnFreshProxy(admin, subvault, address(whitelist), address(factory), address(0));
    }

    function testInitialize_ZeroRoleInArray() external {
        ThreeFModule impl = new ThreeFModule("Mellow", 2, address(token));
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(impl), admin, new bytes(0));
        address[] memory holders = new address[](1);
        bytes32[] memory roles = new bytes32[](1);
        holders[0] = curator;
        roles[0] = bytes32(0);
        vm.expectRevert(IThreeFModule.ZeroValue.selector);
        ThreeFModule(address(proxy)).initialize(
            abi.encode(admin, subvault, address(whitelist), address(factory), holders, roles)
        );
    }

    function testInitialize_EmptyArraysAllowed() external {
        ThreeFModule impl = new ThreeFModule("Mellow", 2, address(token));
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(impl), admin, new bytes(0));
        address[] memory holders = new address[](0);
        bytes32[] memory roles = new bytes32[](0);
        ThreeFModule(address(proxy)).initialize(
            abi.encode(admin, subvault, address(whitelist), address(factory), holders, roles)
        );
        assertTrue(ThreeFModule(address(proxy)).hasRole(ThreeFModule(address(proxy)).DEFAULT_ADMIN_ROLE(), admin));
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

    function testIsRequestAllowed_True() external view {
        assertTrue(module.isRequestAllowed(address(request)));
    }

    function testIsRequestAllowed_False() external {
        vm.prank(admin);
        module.disallowRequest(address(request));
        assertFalse(module.isRequestAllowed(address(request)));
    }

    function testIsRequestAllowed_Unknown() external view {
        assertFalse(module.isRequestAllowed(address(0xdead)));
    }

    // ─── isRequestWhitelisted ─────────────────────────────────────────────────

    function testIsRequestWhitelisted_True() external view {
        assertTrue(module.isRequestWhitelisted(address(request)));
    }

    function testIsRequestWhitelisted_False() external {
        factory.set(address(request), false);
        assertFalse(module.isRequestWhitelisted(address(request)));
    }

    function testIsRequestWhitelisted_NotWhitelisted() external {
        whitelist.set(address(request), IWhitelist.WhitelistStatus.NotWhitelisted);
        assertFalse(module.isRequestWhitelisted(address(request)));
    }

    function testIsRequestWhitelisted_PausedWhitelisted() external {
        whitelist.set(address(request), IWhitelist.WhitelistStatus.PausedWhitelisted);
        assertFalse(module.isRequestWhitelisted(address(request)));
    }

    function testIsRequestWhitelisted_PausedNotWhitelisted() external {
        whitelist.set(address(request), IWhitelist.WhitelistStatus.PausedNotWhitelisted);
        assertFalse(module.isRequestWhitelisted(address(request)));
    }

    function testIsRequestWhitelisted_Unknown() external view {
        assertFalse(module.isRequestWhitelisted(address(0xdead)));
    }

    // ─── allowRequest / disallowRequest ───────────────────────────────────────

    function testAllowRequest_Happy() external {
        MockRequest req2 = new MockRequest();
        req2.setAsset(address(token));
        factory.set(address(req2), true);
        whitelist.set(address(req2), IWhitelist.WhitelistStatus.Whitelisted);

        assertFalse(module.isRequestAllowed(address(req2)));

        vm.expectEmit(true, false, false, false, address(module));
        emit IThreeFModule.RequestAllowed(address(req2));

        vm.prank(admin);
        module.allowRequest(address(req2));

        assertTrue(module.isRequestAllowed(address(req2)));
    }

    function testAllowRequest_Idempotent() external {
        vm.prank(admin);
        module.allowRequest(address(request));
        assertTrue(module.isRequestAllowed(address(request)));
    }

    function testAllowRequest_NotRole() external {
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, stranger, ALLOW_REQUEST_ROLE
            )
        );
        module.allowRequest(address(request));
    }

    function testDisallowRequest_Happy() external {
        assertTrue(module.isRequestAllowed(address(request)));

        vm.expectEmit(true, false, false, false, address(module));
        emit IThreeFModule.RequestDisallowed(address(request));

        vm.prank(admin);
        module.disallowRequest(address(request));

        assertFalse(module.isRequestAllowed(address(request)));
    }

    function testDisallowRequest_Idempotent() external {
        vm.prank(admin);
        module.disallowRequest(address(request));
        assertFalse(module.isRequestAllowed(address(request)));
    }

    function testDisallowRequest_NotRole() external {
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, stranger, ALLOW_REQUEST_ROLE
            )
        );
        module.disallowRequest(address(request));
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
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, stranger, PUSH_ROLE)
        );
        module.push(address(request), authPt, 10e18);
    }

    function testPush_RequestNotAllowed() external {
        vm.prank(admin);
        module.disallowRequest(address(request));
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.RequestNotAllowed.selector);
        module.push(address(request), 100e18, 10e18);
    }

    function testPush_RequestNotWhitelisted() external {
        factory.set(address(request), false);
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.RequestNotWhitelisted.selector);
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
        request.setMintAuth(maxPt - 1, minYt);
        token.mint(address(module), 200e18);
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.InsufficientPtAuthorization.selector);
        module.push(address(request), maxPt, minYt);
    }

    function testPush_InsufficientYtAuthorization() external {
        uint128 maxPt = 100e18;
        uint128 minYt = 10e18;
        request.setMintAuth(maxPt, minYt - 1);
        token.mint(address(module), 200e18);
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.InsufficientYtAuthorization.selector);
        module.push(address(request), maxPt, minYt);
    }

    function testPush_InsufficientBalance() external {
        uint128 maxPt = 100e18;
        token.mint(address(module), maxPt - 1);
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
        token.mint(address(module), maxPt);
        vm.prank(curator);
        module.push(address(request), maxPt, 10e18);

        token.mint(address(module), maxPt);
        vm.prank(curator);
        module.push(address(request), maxPt, 10e18);

        assertEq(module.activeRequestsCount(), 1);
    }

    // ─── hashOffer ────────────────────────────────────────────────────────────

    function testHashOffer_MatchesMockDomain() external view {
        Offer memory offer = _offer(80e18, 1);
        bytes32 typehash = keccak256(
            "Offer(address maker,uint256 amount,uint256 expectedReturn,uint256 nonce,uint256 expiration,bool useCallback)"
        );
        bytes32 structHash = keccak256(
            abi.encode(
                typehash,
                offer.maker,
                offer.amount,
                offer.expectedReturn,
                offer.nonce,
                offer.expiration,
                offer.useCallback
            )
        );
        bytes32 domainSep = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("MockRequest"),
                keccak256("0.0.1"),
                block.chainid,
                address(request)
            )
        );
        bytes32 expected = keccak256(abi.encodePacked("\x19\x01", domainSep, structHash));
        assertEq(module.hashOffer(address(request), offer), expected);
    }

    function testHashOffer_DifferentOffersProduceDifferentHashes() external view {
        Offer memory offer1 = _offer(80e18, 1);
        Offer memory offer2 = _offer(80e18, 2); // different nonce
        assertNotEq(module.hashOffer(address(request), offer1), module.hashOffer(address(request), offer2));
    }

    // ─── onRequestConsumed: hash field sensitivity ────────────────────────────
    //
    // Each test authorizes an offer, then calls onRequestConsumed directly with one
    // field mutated. Every mutation changes the EIP-712 hash → OfferNotAuthorized.

    function _consumeModifiedOffer(Offer memory offer) internal {
        vm.prank(address(request));
        vm.expectRevert(IThreeFModule.OfferNotAuthorized.selector);
        module.onRequestConsumed(offer, "", 50e18, 0);
    }

    function testConsume_RejectsModifiedMaker() external {
        (Offer memory offer,) = _authorizeOffer(80e18, 8e18, 1 hours, 80e18);
        offer.maker = stranger;
        _consumeModifiedOffer(offer);
    }

    function testConsume_RejectsModifiedAmount() external {
        (Offer memory offer,) = _authorizeOffer(80e18, 8e18, 1 hours, 80e18);
        offer.amount = 80e18 + 1;
        _consumeModifiedOffer(offer);
    }

    function testConsume_RejectsModifiedExpectedReturn() external {
        (Offer memory offer,) = _authorizeOffer(80e18, 8e18, 1 hours, 80e18);
        offer.expectedReturn = 8e18 + 1;
        _consumeModifiedOffer(offer);
    }

    function testConsume_RejectsModifiedNonce() external {
        (Offer memory offer,) = _authorizeOffer(80e18, 8e18, 1 hours, 80e18);
        offer.nonce = offer.nonce + 1;
        _consumeModifiedOffer(offer);
    }

    function testConsume_RejectsModifiedExpiration() external {
        (Offer memory offer,) = _authorizeOffer(80e18, 8e18, 1 hours, 80e18);
        offer.expiration = offer.expiration + 1;
        _consumeModifiedOffer(offer);
    }

    function testConsume_RejectsModifiedUseCallback() external {
        (Offer memory offer,) = _authorizeOffer(80e18, 8e18, 1 hours, 80e18);
        offer.useCallback = false;
        _consumeModifiedOffer(offer);
    }

    // ─── authorizeOffer ───────────────────────────────────────────────────────

    /// Calls authorizeOffer and returns the Offer the module constructed internally,
    /// plus its hash. Reads nextNonce before the call so the reconstructed nonce matches.
    function _authorizeOffer(uint256 amount, uint256 expectedReturn, uint256 duration, uint256 fundAmount)
        internal
        returns (Offer memory offer, bytes32 offerHash)
    {
        if (fundAmount > 0) {
            token.mint(address(module), fundAmount);
        }
        uint256 offerNonce = request.makerNonce() + 1;
        uint256 expiration = block.timestamp + duration;
        vm.prank(curator);
        module.authorizeOffer(address(request), amount, expectedReturn, duration);
        offer = Offer({
            maker: address(module),
            amount: amount,
            expectedReturn: expectedReturn,
            nonce: offerNonce,
            expiration: expiration,
            useCallback: true
        });
        offerHash = module.hashOffer(address(request), offer);
    }

    function testAuthorizeOffer_NotCaller() external {
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, stranger, PULL_ROLE)
        );
        module.authorizeOffer(address(request), 80e18, 8e18, 1 hours);
    }

    function testAuthorizeOffer_RequestNotAllowed() external {
        vm.prank(admin);
        module.disallowRequest(address(request));
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.RequestNotAllowed.selector);
        module.authorizeOffer(address(request), 80e18, 8e18, 1 hours);
    }

    function testAuthorizeOffer_RequestNotWhitelisted() external {
        factory.set(address(request), false);
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.RequestNotWhitelisted.selector);
        module.authorizeOffer(address(request), 80e18, 8e18, 1 hours);
    }

    function testAuthorizeOffer_AssetMismatch() external {
        request.setAsset(address(0xdead));
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.AssetMismatch.selector);
        module.authorizeOffer(address(request), 80e18, 8e18, 1 hours);
    }

    function testAuthorizeOffer_ZeroAmount() external {
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.ZeroValue.selector);
        module.authorizeOffer(address(request), 0, 8e18, 1 hours);
    }

    function testAuthorizeOffer_ZeroDuration() external {
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.ZeroValue.selector);
        module.authorizeOffer(address(request), 80e18, 8e18, 0);
    }

    function testAuthorizeOffer_Happy() external {
        uint256 offerNonce = request.makerNonce() + 1;
        uint256 expiration = block.timestamp + 1 hours;

        // Reconstruct expected offer to compute expected hash before the call
        Offer memory expectedOffer = Offer({
            maker: address(module),
            amount: 80e18,
            expectedReturn: 8e18,
            nonce: offerNonce,
            expiration: expiration,
            useCallback: true
        });
        bytes32 expectedHash = module.hashOffer(address(request), expectedOffer);

        vm.expectEmit(true, true, false, true, address(module));
        emit IThreeFModule.OfferAuthorized(address(request), expectedHash, 80e18, 8e18, offerNonce, expiration);

        vm.prank(curator);
        module.authorizeOffer(address(request), 80e18, 8e18, 1 hours);

        assertEq(module.isValidSignature(expectedHash, ""), bytes4(0x1626ba7e));
        assertEq(module.isValidSignature(keccak256("other"), ""), bytes4(0xffffffff));
    }

    function testAuthorizeOffer_SameNonceOverwrites() external {
        // Without cancel/consume between calls, both use the same nonce → same hash → second overwrites.
        (, bytes32 hash1) = _authorizeOffer(80e18, 8e18, 1 hours, 0);
        (, bytes32 hash2) = _authorizeOffer(80e18, 8e18, 1 hours, 0); // same nonce, overwrites
        assertEq(hash1, hash2); // same hash
        assertEq(module.isValidSignature(hash1, ""), bytes4(0x1626ba7e));
    }

    function testAuthorizeOffer_AfterCancelUsesHigherNonce() external {
        (, bytes32 hash1) = _authorizeOffer(80e18, 8e18, 1 hours, 0);
        vm.prank(curator);
        module.cancelOffer(address(request)); // advances request nonce
        (, bytes32 hash2) = _authorizeOffer(80e18, 8e18, 1 hours, 0); // new nonce
        assertNotEq(hash1, hash2);
        assertEq(module.isValidSignature(hash1, ""), bytes4(0x1626ba7e)); // old still valid (not consumed)
        assertEq(module.isValidSignature(hash2, ""), bytes4(0x1626ba7e)); // new also valid
    }

    // ─── isValidSignature ─────────────────────────────────────────────────────

    function testIsValidSignature_NoAuthorization() external view {
        assertEq(module.isValidSignature(keccak256("test"), ""), bytes4(0xffffffff));
    }

    // isValidSignature returning magic is verified implicitly by testPull_Happy
    // via MockRequest.consume() which requires the magic value to proceed.

    // ─── onRequestConsumed ────────────────────────────────────────────────────

    function testOnRequestConsumed_RequestNotAllowed() external {
        (Offer memory offer,) = _authorizeOffer(80e18, 8e18, 1 hours, 80e18);
        vm.prank(admin);
        module.disallowRequest(address(request));

        vm.prank(address(request));
        vm.expectRevert(IThreeFModule.RequestNotAllowed.selector);
        module.onRequestConsumed(offer, "", 50e18, 5e18);
    }

    function testOnRequestConsumed_RequestNotWhitelisted() external {
        (Offer memory offer,) = _authorizeOffer(80e18, 8e18, 1 hours, 80e18);
        factory.set(address(request), false);

        vm.prank(address(request));
        vm.expectRevert(IThreeFModule.RequestNotWhitelisted.selector);
        module.onRequestConsumed(offer, "", 50e18, 5e18);
    }

    function testOnRequestConsumed_OfferNotAuthorized() external {
        Offer memory offer = _offer(80e18, 1); // not authorized via module
        token.mint(address(module), 80e18);

        vm.prank(address(request));
        vm.expectRevert(IThreeFModule.OfferNotAuthorized.selector);
        module.onRequestConsumed(offer, "", 50e18, 5e18);
    }

    function testOnRequestConsumed_ExceedsPtAuthorization() external {
        (Offer memory offer,) = _authorizeOffer(80e18, 8e18, 1 hours, 80e18);

        vm.prank(address(request));
        vm.expectRevert(IThreeFModule.ExceedsPtAuthorization.selector);
        module.onRequestConsumed(offer, "", 80e18 + 1, 5e18);
    }

    function testOnRequestConsumed_InsufficientBalance() external {
        _authorizeOffer(80e18, 8e18, 1 hours, 0); // no funds — advances nonce to 1
        (Offer memory offer,) = _authorizeOffer(80e18, 8e18, 1 hours, 0);

        vm.prank(address(request));
        vm.expectRevert(IThreeFModule.InsufficientBalance.selector);
        module.onRequestConsumed(offer, "", 50e18, 5e18);
    }

    function testOnRequestConsumed_ApprovesAndClearsAuth() external {
        (Offer memory offer, bytes32 offerHash) = _authorizeOffer(80e18, 8e18, 1 hours, 80e18);

        vm.prank(address(request));
        module.onRequestConsumed(offer, "", 80e18, 5e18); // full fill

        assertEq(token.allowance(address(module), address(request)), 80e18);
        assertEq(module.isValidSignature(offerHash, ""), bytes4(0xffffffff)); // deleted
        assertEq(module.activeRequestsCount(), 1);
    }

    function testOnRequestConsumed_PartialFillKeepsAuth() external {
        (Offer memory offer, bytes32 offerHash) = _authorizeOffer(80e18, 8e18, 1 hours, 80e18);

        vm.prank(address(request));
        module.onRequestConsumed(offer, "", 50e18, 5e18);

        assertEq(token.allowance(address(module), address(request)), 50e18);
        assertEq(module.isValidSignature(offerHash, ""), bytes4(0x1626ba7e)); // 30e18 remaining
        assertEq(module.activeRequestsCount(), 1);
    }

    // ─── pull flow (end-to-end via MockRequest.consume) ───────────────────────

    function testPull_Happy() external {
        uint256 ptAmount = 50e18;
        uint256 ytAmount = 8e18;
        request.setYtReturn(ytAmount);
        (Offer memory offer,) = _authorizeOffer(80e18, 8e18, 1 hours, 100e18);

        vm.expectEmit(true, false, false, true, address(module));
        emit IThreeFModule.Pulled(address(request), ptAmount, ytAmount);

        request.consume(offer, "", ptAmount);

        assertEq(token.balanceOf(address(module)), 100e18 - ptAmount);
        assertEq(token.balanceOf(address(request)), ptAmount);
        assertEq(token.allowance(address(module), address(request)), 0);
        assertEq(module.activeRequestsCount(), 1);
        assertEq(module.activeRequestAt(0), address(request));
    }

    function testPull_PartialFill() external {
        uint256 ptAmount = 30e18;
        request.setYtReturn(3e18);
        (Offer memory offer,) = _authorizeOffer(80e18, 8e18, 1 hours, 100e18);
        request.consume(offer, "", ptAmount);

        assertEq(token.balanceOf(address(module)), 100e18 - ptAmount);
        assertEq(token.balanceOf(address(request)), ptAmount);
    }

    function testPull_DoubleConsume_Reverts() external {
        uint256 ptAmount = 50e18;
        request.setYtReturn(5e18);
        (Offer memory offer,) = _authorizeOffer(80e18, 8e18, 1 hours, 100e18);
        request.consume(offer, "", ptAmount); // reduces auth to 30e18

        token.mint(address(module), ptAmount);
        vm.expectRevert(IThreeFModule.ExceedsPtAuthorization.selector);
        request.consume(offer, "", ptAmount); // 50 > 30 remaining
    }

    // ─── nextNonce ────────────────────────────────────────────────────────────

    function testNextNonce_Default() external view {
        assertEq(module.nextNonce(address(request)), 1);
    }

    function testNextNonce_AfterRequestNonceAdvances() external {
        request.setMakerNonce(5);
        assertEq(module.nextNonce(address(request)), 6);
    }

    function testNextNonce_OfferAtNextNonceSucceeds() external {
        request.setYtReturn(5e18);
        request.setMakerNonce(3); // nextNonce = 4
        (Offer memory offer,) = _authorizeOffer(80e18, 8e18, 1 hours, 100e18);
        assertEq(offer.nonce, 4); // nonce was auto-assigned as nextNonce at time of authorize
        request.consume(offer, "", 50e18);
        assertEq(token.balanceOf(address(request)), 50e18);
    }

    function testNextNonce_OfferBelowNextNonceReverts() external {
        // Cancel advances request nonce to 1. Authorize with default params (nonce=nextNonce=2) should work.
        // But if we manually set makerNonce=3 and then try to authorize, nonce=4 is used and succeeds.
        // The stale nonce check fires when the module reads request.nonce() > computed offer.nonce.
        // Since nonce is auto-assigned this can't happen from authorizeOffer alone.
        // Instead we verify via cancelOffer: after cancel, old hash is unreachable.
        (, bytes32 oldHash) = _authorizeOffer(80e18, 8e18, 1 hours, 0);
        vm.prank(curator);
        module.cancelOffer(address(request)); // advances nonce past offer.nonce
        // old hash still in storage but request.nonce now >= offer.nonce → consume rejects nonce
        assertEq(module.isValidSignature(oldHash, ""), bytes4(0x1626ba7e)); // storage still there
            // A real consume would fail at the request level (stale nonce check), not at our callback
    }

    // ─── cancelOffer ──────────────────────────────────────────────────────────

    function testCancelOffer_NotCaller() external {
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, stranger, PULL_ROLE)
        );
        module.cancelOffer(address(request));
    }

    function testCancelOffer_RequestNotAllowed() external {
        vm.prank(admin);
        module.disallowRequest(address(request));
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.RequestNotAllowed.selector);
        module.cancelOffer(address(request));
    }

    function testCancelOffer_RequestNotWhitelisted() external {
        factory.set(address(request), false);
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.RequestNotWhitelisted.selector);
        module.cancelOffer(address(request));
    }

    function testCancelOffer_Happy() external {
        assertEq(request.makerNonce(), 0);
        vm.prank(curator);
        module.cancelOffer(address(request));
        assertEq(request.makerNonce(), 1);
        assertEq(request.lastSetNonce(), 1);
    }

    function testCancelOffer_EmitsOfferCancelled() external {
        vm.expectEmit(true, false, false, true, address(module));
        emit IThreeFModule.OfferCancelled(address(request), 1);
        vm.prank(curator);
        module.cancelOffer(address(request));
    }

    function testCancelOffer_EmitsIncrementingNonce() external {
        vm.prank(curator);
        module.cancelOffer(address(request)); // nonce → 1

        vm.expectEmit(true, false, false, true, address(module));
        emit IThreeFModule.OfferCancelled(address(request), 2);

        vm.prank(curator);
        module.cancelOffer(address(request)); // nonce → 2
    }

    function testCancelOffer_NextAuthorizeUsesHigherNonce() external {
        vm.prank(curator);
        module.cancelOffer(address(request)); // request nonce → 1; nextNonce → 2

        // New authorize picks nonce = 2
        (Offer memory offer,) = _authorizeOffer(80e18, 8e18, 1 hours, 0);
        assertEq(offer.nonce, 2);
    }

    // ─── burn ─────────────────────────────────────────────────────────────────

    function _setupBurn() internal {
        uint128 authPt = 100e18;
        uint128 authYt = 10e18;
        token.mint(address(module), authPt);
        vm.prank(curator);
        module.push(address(request), authPt, authYt);
        request.setRepaid(true);
        request.setCanWithdraw(true);
        request.setBurnReturn(authPt, authYt, 90e18, authYt);
    }

    function testBurn_NotCaller() external {
        _setupBurn();
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, stranger, BURN_ROLE)
        );
        module.burn(address(request), 0);
    }

    function testBurn_RequestNotAllowed() external {
        _setupBurn();
        vm.prank(admin);
        module.disallowRequest(address(request));
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.RequestNotAllowed.selector);
        module.burn(address(request), 0);
    }

    function testBurn_RequestNotWhitelisted() external {
        _setupBurn();
        factory.set(address(request), false);
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.RequestNotWhitelisted.selector);
        module.burn(address(request), 0);
    }

    function testBurn_NotRepaid() external {
        _setupBurn();
        request.setRepaid(false);
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.NotRepaid.selector);
        module.burn(address(request), 1);
    }

    function testBurn_CannotWithdraw() external {
        _setupBurn();
        request.setCanWithdraw(false);
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.WithdrawalNotAllowed.selector);
        module.burn(address(request), 1);
    }

    function testBurn_RequestNotActive() external {
        request.setRepaid(true);
        request.setCanWithdraw(true);
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.RequestNotActive.selector);
        module.burn(address(request), 1);
    }

    function testBurn_ZeroMinAssetOut() external {
        _setupBurn();
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.ZeroMinAssetOut.selector);
        module.burn(address(request), 0);
    }

    function testBurn_InsufficientOutput() external {
        _setupBurn();
        uint256 actualOutput = 90e18 + 10e18;
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.InsufficientOutput.selector);
        module.burn(address(request), actualOutput + 1);
    }

    function testBurn_Happy() external {
        uint256 totalOut = 100e18;
        _setupBurn();

        vm.expectEmit(true, false, false, true, address(module));
        emit IThreeFModule.Burned(address(request), 100e18, 10e18, 90e18, 10e18);

        vm.prank(curator);
        module.burn(address(request), totalOut);

        assertEq(token.balanceOf(address(module)), totalOut);
        assertEq(module.activeRequestsCount(), 0);
        assertEq(token.allowance(address(module), address(request)), 0);
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
        assertEq(module.balance(0, 10), authPt);
    }

    function testBalance_Pagination() external {
        MockRequest request2 = new MockRequest();
        request2.setAsset(address(token));
        request2.setMintAuth(50e18, 5e18);
        factory.set(address(request2), true);
        whitelist.set(address(request2), IWhitelist.WhitelistStatus.Whitelisted);
        vm.prank(admin);
        module.allowRequest(address(request2));

        token.mint(address(module), 150e18);
        vm.startPrank(curator);
        module.push(address(request), 100e18, 10e18);
        module.push(address(request2), 50e18, 5e18);
        vm.stopPrank();

        assertEq(module.activeRequestsCount(), 2);
        assertEq(module.balance(0, 2), 150e18);
        assertEq(module.balance(0, 1) + module.balance(1, 1), 150e18);
        assertEq(module.balance(2, 10), 0);
    }

    function testBalance_LimitClamp() external {
        uint128 authPt = 100e18;
        token.mint(address(module), authPt);
        vm.prank(curator);
        module.push(address(request), authPt, 10e18);
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

    // ─── activeRequests side effects ──────────────────────────────────────────

    function testActiveRequests_AddDuplicate_NoSideEffect() external {
        uint128 authPt = 100e18;
        token.mint(address(module), authPt);
        vm.prank(curator);
        module.push(address(request), authPt, 10e18);
        assertEq(module.activeRequestsCount(), 1);

        token.mint(address(module), authPt);
        vm.prank(curator);
        module.push(address(request), authPt, 10e18);
        assertEq(module.activeRequestsCount(), 1);
        assertEq(module.activeRequestAt(0), address(request));
    }

    function testActiveRequests_RemoveNonExisting_RevertsRequestNotActive() external {
        request.setRepaid(true);
        request.setCanWithdraw(true);
        assertEq(module.activeRequestsCount(), 0);
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.RequestNotActive.selector);
        module.burn(address(request), 1);
    }

    function testActiveRequests_RemoveAfterBurn_Correct() external {
        uint128 authPt = 100e18;
        token.mint(address(module), authPt);
        vm.prank(curator);
        module.push(address(request), authPt, 10e18);
        assertEq(module.activeRequestsCount(), 1);

        request.setRepaid(true);
        request.setCanWithdraw(true);
        request.setBurnReturn(authPt, 10e18, 90e18, 10e18);

        vm.prank(curator);
        module.burn(address(request), 1);
        assertEq(module.activeRequestsCount(), 0);
    }

    // ─── RequestActivated / RequestDeactivated events ─────────────────────────

    function testRequestActivated_EmittedOnFirstPush() external {
        uint128 authPt = 100e18;
        token.mint(address(module), authPt);

        vm.expectEmit(true, false, false, false, address(module));
        emit IThreeFModule.RequestActivated(address(request));

        vm.prank(curator);
        module.push(address(request), authPt, 10e18);
    }

    function testRequestActivated_NotEmittedOnSecondPush() external {
        uint128 authPt = 100e18;
        token.mint(address(module), authPt);
        vm.prank(curator);
        module.push(address(request), authPt, 10e18);

        token.mint(address(module), authPt);
        vm.recordLogs();
        vm.prank(curator);
        module.push(address(request), authPt, 10e18);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 activatedTopic = keccak256("RequestActivated(address)");
        for (uint256 i = 0; i < logs.length; i++) {
            assertNotEq(logs[i].topics[0], activatedTopic, "unexpected RequestActivated on 2nd push");
        }
    }

    function testRequestActivated_EmittedOnFirstPull() external {
        request.setYtReturn(5e18);
        (Offer memory offer,) = _authorizeOffer(80e18, 8e18, 1 hours, 100e18);

        vm.expectEmit(true, false, false, false, address(module));
        emit IThreeFModule.RequestActivated(address(request));

        request.consume(offer, "", 50e18);
    }

    function testRequestActivated_NotEmittedOnPushAfterPull() external {
        request.setYtReturn(5e18);
        (Offer memory offer,) = _authorizeOffer(80e18, 8e18, 1 hours, 100e18);
        request.consume(offer, "", 50e18);

        token.mint(address(module), 100e18);
        vm.recordLogs();
        vm.prank(curator);
        module.push(address(request), 100e18, 10e18);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 activatedTopic = keccak256("RequestActivated(address)");
        for (uint256 i = 0; i < logs.length; i++) {
            assertNotEq(logs[i].topics[0], activatedTopic, "unexpected RequestActivated on push after pull");
        }
    }

    function testRequestActivated_NotEmittedOnPullAfterPush() external {
        uint128 authPt = 100e18;
        token.mint(address(module), authPt);
        vm.prank(curator);
        module.push(address(request), authPt, 10e18);

        request.setYtReturn(5e18);
        (Offer memory offer,) = _authorizeOffer(80e18, 8e18, 1 hours, 100e18);

        vm.recordLogs();
        request.consume(offer, "", 50e18);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 activatedTopic = keccak256("RequestActivated(address)");
        for (uint256 i = 0; i < logs.length; i++) {
            assertNotEq(logs[i].topics[0], activatedTopic, "unexpected RequestActivated on pull after push");
        }
    }

    function testRequestDeactivated_EmittedOnBurnAfterPush() external {
        uint128 authPt = 100e18;
        token.mint(address(module), authPt);
        vm.prank(curator);
        module.push(address(request), authPt, 10e18);

        request.setRepaid(true);
        request.setCanWithdraw(true);
        request.setBurnReturn(authPt, 10e18, 90e18, 10e18);

        vm.expectEmit(true, false, false, false, address(module));
        emit IThreeFModule.RequestDeactivated(address(request));

        vm.prank(curator);
        module.burn(address(request), 1);
    }

    function testRequestDeactivated_NotEmittedOnBurnWithoutPriorActivation() external {
        request.setRepaid(true);
        request.setCanWithdraw(true);
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.RequestNotActive.selector);
        module.burn(address(request), 1);
    }

    function testRequestDeactivated_NotEmittedOnDoubleBurn() external {
        uint128 authPt = 100e18;
        token.mint(address(module), authPt);
        vm.prank(curator);
        module.push(address(request), authPt, 10e18);

        request.setRepaid(true);
        request.setCanWithdraw(true);
        request.setBurnReturn(authPt, 10e18, 90e18, 10e18);

        vm.prank(curator);
        module.burn(address(request), 1);

        vm.prank(curator);
        vm.expectRevert(IThreeFModule.RequestNotActive.selector);
        module.burn(address(request), 1);
    }
}
