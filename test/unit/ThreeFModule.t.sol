// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Test.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {Offer} from "../../src/interfaces/external/3F/IOfferReceiver.sol";
import {IRequest} from "../../src/interfaces/external/3F/IRequest.sol";
import {IRequestCallback} from "../../src/interfaces/external/3F/IRequestCallback.sol";
import {IWhitelist} from "../../src/interfaces/external/3F/IWhitelist.sol";
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

    function eip712Domain()
        external
        view
        returns (
            bytes1 fields,
            string memory name_,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        )
    {
        return (bytes1(0x0f), "MockRequest", "0.0.1", block.chainid, address(this), bytes32(0), new uint256[](0));
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

    bool public overrideMintResult;
    uint128 public mintPtResult;
    uint128 public mintYtResult;

    function setMintResult(uint128 pt, uint128 yt) external {
        mintPtResult = pt;
        mintYtResult = yt;
        overrideMintResult = true;
    }

    function mint(uint128, uint128) external {
        IERC20(assetAddr).transferFrom(msg.sender, address(this), authPt);
        _balPt += overrideMintResult ? mintPtResult : authPt;
        _balYt += overrideMintResult ? mintYtResult : authYt;
    }

    /// @dev Simulates the real Request.consume() flow:
    ///      1. Compute EIP-712 hash (same formula as ThreeFModule._hashOffer)
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
        makerNonce = offer.nonce; // mirrors real 3F: _nonces[maker] = offer.nonce
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

    function testAllowRequest_AssetMismatch() external {
        MockRequest req2 = new MockRequest();
        req2.setAsset(address(0xdead)); // wrong asset
        factory.set(address(req2), true);
        whitelist.set(address(req2), IWhitelist.WhitelistStatus.Whitelisted);

        vm.prank(admin);
        vm.expectRevert(IThreeFModule.AssetMismatch.selector);
        module.allowRequest(address(req2));
    }

    function testAllowRequest_RequestNotWhitelisted() external {
        MockRequest req2 = new MockRequest();
        req2.setAsset(address(token));
        factory.set(address(req2), true);
        // not added to whitelist → NotWhitelisted status

        vm.prank(admin);
        vm.expectRevert(IThreeFModule.RequestNotWhitelisted.selector);
        module.allowRequest(address(req2));
    }

    function testAllowRequest_AlreadyAllowed() external {
        // setUp already calls allowRequest once; a second call reverts
        vm.prank(admin);
        vm.expectRevert(IThreeFModule.RequestAlreadyAllowed.selector);
        module.allowRequest(address(request));
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

    function testDisallowRequest_NotAllowed() external {
        // request not in allow set — remove() returns false → RequestNotAllowed
        vm.prank(admin);
        module.disallowRequest(address(request)); // first call succeeds

        vm.prank(admin);
        vm.expectRevert(IThreeFModule.RequestNotAllowed.selector);
        module.disallowRequest(address(request)); // already removed
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

    function testDisallowRequest_CancelsOffers() external {
        // Issue two offers then disallow — lastIssuedNonce=2 should be set on-chain
        _authorizeOffer(80e18, 8e18, 1 hours, 0);
        _authorizeOffer(60e18, 6e18, 1 hours, 0);
        assertEq(module.lastIssuedNonce(address(request)), 2);

        vm.expectEmit(true, false, false, true, address(module));
        emit IThreeFModule.OfferCancelled(address(request), 2);

        vm.prank(admin);
        module.disallowRequest(address(request));

        assertEq(request.makerNonce(), 2);
    }

    function testDisallowRequest_NoPendingOffers_NoEvent() external {
        // No offers issued → _cancelOffers is a no-op; OfferCancelled must not be emitted
        vm.recordLogs();
        vm.prank(admin);
        module.disallowRequest(address(request));

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 cancelledSig = keccak256("OfferCancelled(address,uint256)");
        for (uint256 i = 0; i < logs.length; i++) {
            assertNotEq(logs[i].topics[0], cancelledSig, "unexpected OfferCancelled emitted");
        }
    }

    function testDisallowRequest_AllConsumed_NoEvent() external {
        // Issue and consume nonce 1 → onChainNonce==lastIssuedNonce → nothing to cancel
        request.setYtReturn(8e18);
        (Offer memory offer,) = _authorizeOffer(80e18, 8e18, 1 hours, 80e18);
        request.consume(offer, "", 80e18); // advances onChainNonce to 1

        vm.recordLogs();
        vm.prank(admin);
        module.disallowRequest(address(request));

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 cancelledSig = keccak256("OfferCancelled(address,uint256)");
        for (uint256 i = 0; i < logs.length; i++) {
            assertNotEq(logs[i].topics[0], cancelledSig, "unexpected OfferCancelled emitted");
        }
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
        module.push(address(request), type(uint128).max, 0);
    }

    function testPush_RequestNotAllowed() external {
        vm.prank(admin);
        module.disallowRequest(address(request));
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.RequestNotAllowed.selector);
        module.push(address(request), type(uint128).max, 0);
    }

    function testPush_RequestNotWhitelisted() external {
        factory.set(address(request), false);
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.RequestNotWhitelisted.selector);
        module.push(address(request), type(uint128).max, 0);
    }

    function testPush_InsufficientAuthorization() external {
        // maxPt == 0 means no authorization exists — essential pre-check before approving
        request.setMintAuth(0, 0);
        token.mint(address(module), 100e18);
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.InsufficientAuthorization.selector);
        module.push(address(request), type(uint128).max, 0);
    }

    function testPush_InsufficientBalance() external {
        // setUp: authPt=100e18; fund with one less than authPt
        token.mint(address(module), 100e18 - 1);
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.InsufficientBalance.selector);
        module.push(address(request), type(uint128).max, 0);
    }

    function testPush_Happy() external {
        // setUp: authPt=100e18, authYt=10e18; pass exact expected values
        token.mint(address(module), 100e18);
        request.setBalances(0, 0);

        vm.expectEmit(true, false, false, true, address(module));
        emit IThreeFModule.Pushed(address(request), 100e18, 10e18, 100e18, 10e18);

        vm.prank(curator);
        module.push(address(request), 100e18, 10e18);

        assertEq(token.balanceOf(address(module)), 0);
        assertEq(token.balanceOf(address(request)), 100e18);
        assertEq(token.allowance(address(module), address(request)), 0);
    }

    function testPush_InsufficientAuthorization_AuthPtExceedsMaxPt() external {
        // Pre-mint: authPt=100e18 but caller only accepts 90e18 → revert before mint
        token.mint(address(module), 100e18);
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.InsufficientAuthorization.selector);
        module.push(address(request), 90e18, 10e18); // maxPt=90 < authPt=100
    }

    function testPush_InsufficientAuthorization_AuthYtBelowMinYt() external {
        // Pre-mint: authYt=10e18 but caller wants at least 20e18 → revert before mint
        token.mint(address(module), 100e18);
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.InsufficientAuthorization.selector);
        module.push(address(request), 100e18, 20e18); // minYt=20 > authYt=10
    }

    function testPush_SlippageExceeded_ExcessPt() external {
        // Post-mint: mock credits more PT than authPt → ptMinted > authPt
        request.setMintResult(200e18, 10e18); // authPt=100e18 but mock adds 200e18
        token.mint(address(module), 100e18);
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.SlippageExceeded.selector);
        module.push(address(request), type(uint128).max, 0);
    }

    function testPush_SlippageExceeded_InsufficientYt() external {
        // Post-mint: mock credits less YT than authYt → ytMinted < authYt
        request.setMintResult(100e18, 5e18); // authYt=10e18 but mock adds 5e18
        token.mint(address(module), 100e18);
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.SlippageExceeded.selector);
        module.push(address(request), type(uint128).max, 0);
    }

    function testPush_DoesNotDuplicateActiveRequest() external {
        token.mint(address(module), 100e18);
        vm.prank(curator);
        module.push(address(request), type(uint128).max, 0);

        token.mint(address(module), 100e18);
        vm.prank(curator);
        module.push(address(request), type(uint128).max, 0); // no revert — idempotent
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

    /// Calls authorizeOffer and returns the Offer and hash straight from the module's return values.
    function _authorizeOffer(uint256 amount, uint256 expectedReturn, uint256 duration, uint256 fundAmount)
        internal
        returns (Offer memory offer, bytes32 offerHash)
    {
        if (fundAmount > 0) {
            token.mint(address(module), fundAmount);
        }
        vm.prank(curator);
        (offer, offerHash) = module.authorizeOffer(address(request), amount, expectedReturn, duration);
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
        vm.prank(curator);
        (Offer memory offer, bytes32 offerHash) = module.authorizeOffer(address(request), 80e18, 8e18, 1 hours);

        assertEq(offer.maker, address(module));
        assertEq(offer.amount, 80e18);
        assertEq(offer.expectedReturn, 8e18);
        assertEq(offer.nonce, 1);
        assertTrue(offer.useCallback);
        assertEq(module.isValidSignature(offerHash, ""), bytes4(0x1626ba7e));
        assertEq(module.isValidSignature(keccak256("other"), ""), bytes4(0xffffffff));
    }

    function testAuthorizeOffer_SequentialNonces() external {
        // Option C: each call gets a unique nonce even with no consume in between.
        (, bytes32 hash1) = _authorizeOffer(80e18, 8e18, 1 hours, 0);
        (, bytes32 hash2) = _authorizeOffer(60e18, 6e18, 1 hours, 0);
        assertNotEq(hash1, hash2); // distinct hashes — both live simultaneously
        assertEq(module.isValidSignature(hash1, ""), bytes4(0x1626ba7e));
        assertEq(module.isValidSignature(hash2, ""), bytes4(0x1626ba7e));
        assertEq(module.lastIssuedNonce(address(request)), 2);
    }

    function testAuthorizeOffer_AfterCancelUsesHigherNonce() external {
        (, bytes32 hash1) = _authorizeOffer(80e18, 8e18, 1 hours, 0);
        // cancel nonce 1
        vm.prank(curator);
        module.cancelOffers(address(request), 1);
        // next authorize starts from max(lastIssuedNonce=1, onChainNonce=1) + 1 = 2
        (, bytes32 hash2) = _authorizeOffer(80e18, 8e18, 1 hours, 0);
        assertNotEq(hash1, hash2);
        // hash1 still in authorizedOffers — stale but 3F's own nonce check blocks consumption
        assertEq(module.isValidSignature(hash1, ""), bytes4(0x1626ba7e));
        assertEq(module.isValidSignature(hash2, ""), bytes4(0x1626ba7e));
    }

    // ─── isValidSignature ─────────────────────────────────────────────────────

    function testIsValidSignature_NoAuthorization() external view {
        assertEq(module.isValidSignature(keccak256("test"), ""), bytes4(0xffffffff));
    }

    function testIsValidSignature_RemainsValidAfterDewhitelist() external {
        // isValidSignature only checks maxPt > 0; whitelist/allow status is enforced in onRequestConsumed.
        (, bytes32 offerHash) = _authorizeOffer(80e18, 8e18, 1 hours, 0);
        assertEq(module.isValidSignature(offerHash, ""), bytes4(0x1626ba7e));

        factory.set(address(request), false); // de-whitelist does not change isValidSignature
        assertEq(module.isValidSignature(offerHash, ""), bytes4(0x1626ba7e));
    }

    // isValidSignature returning magic is verified implicitly by testPull_Happy
    // via MockRequest.consume() which requires the magic value to proceed.

    // ─── onRequestConsumed ────────────────────────────────────────────────────

    function testOnRequestConsumed_PrincipalZero() external {
        (Offer memory offer,) = _authorizeOffer(80e18, 8e18, 1 hours, 80e18);
        vm.prank(address(request));
        vm.expectRevert(IThreeFModule.ZeroValue.selector);
        module.onRequestConsumed(offer, "", 0, 0);
    }

    function testOnRequestConsumed_OfferExpired() external {
        (Offer memory offer,) = _authorizeOffer(80e18, 8e18, 1 hours, 80e18);
        vm.warp(offer.expiration + 1);
        vm.prank(address(request));
        vm.expectRevert(IThreeFModule.OfferExpired.selector);
        module.onRequestConsumed(offer, "", 80e18, 8e18);
    }

    function testOnRequestConsumed_ExceedsPtAuthorization() external {
        (Offer memory offer,) = _authorizeOffer(80e18, 8e18, 1 hours, 100e18);
        vm.prank(address(request));
        vm.expectRevert(IThreeFModule.ExceedsPtAuthorization.selector);
        module.onRequestConsumed(offer, "", 80e18 + 1, 8e18); // principal > maxPt
    }

    function testOnRequestConsumed_InsufficientYt() external {
        // Full fill: yield must be >= minYt
        (Offer memory offer,) = _authorizeOffer(80e18, 8e18, 1 hours, 80e18);
        vm.prank(address(request));
        vm.expectRevert(IThreeFModule.InsufficientYt.selector);
        module.onRequestConsumed(offer, "", 80e18, 7e18); // 7e18 < 8e18 floor
    }

    function testOnRequestConsumed_InsufficientBalance() external {
        // Fund with one less than the principal being consumed
        (Offer memory offer,) = _authorizeOffer(80e18, 8e18, 1 hours, 79e18); // 79e18 < 80e18
        vm.prank(address(request));
        vm.expectRevert(IThreeFModule.InsufficientBalance.selector);
        module.onRequestConsumed(offer, "", 80e18, 8e18);
    }

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

    function testOnRequestConsumed_ApprovesAndClearsAuth() external {
        (Offer memory offer, bytes32 offerHash) = _authorizeOffer(80e18, 8e18, 1 hours, 80e18);

        vm.prank(address(request));
        module.onRequestConsumed(offer, "", 80e18, 8e18); // full fill, yield = minYt

        assertEq(token.allowance(address(module), address(request)), 80e18);
        assertEq(module.isValidSignature(offerHash, ""), bytes4(0xffffffff)); // deleted
    }

    function testOnRequestConsumed_PartialFill_DeletesAuth() external {
        // The 3F nonce advances on consume — same offer hash is unreplayable regardless of fill size.
        (Offer memory offer, bytes32 offerHash) = _authorizeOffer(80e18, 8e18, 1 hours, 80e18);

        vm.prank(address(request));
        module.onRequestConsumed(offer, "", 50e18, 5e18);

        assertEq(token.allowance(address(module), address(request)), 50e18);
        assertEq(module.isValidSignature(offerHash, ""), bytes4(0xffffffff)); // always deleted
    }

    // ─── pull flow (end-to-end via MockRequest.consume) ───────────────────────

    function testPull_Happy() external {
        uint256 ptAmount = 50e18;
        uint256 ytAmount = 8e18;
        request.setYtReturn(ytAmount);
        (Offer memory offer, bytes32 offerHash) = _authorizeOffer(80e18, 8e18, 1 hours, 100e18);

        vm.expectEmit(true, true, false, true, address(module));
        emit IThreeFModule.OfferConsumed(address(request), offerHash, offer, ptAmount, ytAmount);

        request.consume(offer, "", ptAmount);

        assertEq(token.balanceOf(address(module)), 100e18 - ptAmount);
        assertEq(token.balanceOf(address(request)), ptAmount);
        assertEq(token.allowance(address(module), address(request)), 0);
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

        // Auth deleted after first consume — second consume fails at ERC-1271 check
        token.mint(address(module), ptAmount);
        vm.expectRevert("MockRequest: bad sig");
        request.consume(offer, "", ptAmount);
    }

    // ─── currentNonce / lastIssuedNonce ──────────────────────────────────────

    function testCurrentNonce_Default() external view {
        assertEq(module.currentNonce(address(request)), 0);
    }

    function testCurrentNonce_AfterOnChainAdvances() external {
        request.setMakerNonce(5);
        assertEq(module.currentNonce(address(request)), 5);
    }

    function testCurrentNonce_PendingOfferCount() external {
        // pending = lastIssuedNonce - currentNonce
        _authorizeOffer(80e18, 8e18, 1 hours, 0); // lastIssued=1, onChain=0 → 1 pending
        assertEq(module.lastIssuedNonce(address(request)) - module.currentNonce(address(request)), 1);
        _authorizeOffer(60e18, 6e18, 1 hours, 0); // lastIssued=2, onChain=0 → 2 pending
        assertEq(module.lastIssuedNonce(address(request)) - module.currentNonce(address(request)), 2);
    }

    function testLastIssuedNonce_InitiallyZero() external view {
        assertEq(module.lastIssuedNonce(address(request)), 0);
    }

    function testLastIssuedNonce_IncrementsWithEachAuthorize() external {
        _authorizeOffer(80e18, 8e18, 1 hours, 0);
        assertEq(module.lastIssuedNonce(address(request)), 1);
        _authorizeOffer(60e18, 6e18, 1 hours, 0);
        assertEq(module.lastIssuedNonce(address(request)), 2);
        _authorizeOffer(40e18, 4e18, 1 hours, 0);
        assertEq(module.lastIssuedNonce(address(request)), 3);
    }

    function testLastIssuedNonce_ResumesAfterOnChainAdvance() external {
        // If on-chain nonce overtakes lastIssuedNonce (e.g. by direct setNonce), next offer jumps ahead.
        _authorizeOffer(80e18, 8e18, 1 hours, 0); // lastIssued=1
        request.setMakerNonce(5); // onChain=5 > lastIssued=1
        (Offer memory offer,) = _authorizeOffer(80e18, 8e18, 1 hours, 0);
        assertEq(offer.nonce, 6); // max(1,5)+1
        assertEq(module.lastIssuedNonce(address(request)), 6);
    }

    function testNextNonce_OfferConsumedUsesCorrectNonce() external {
        request.setYtReturn(5e18);
        request.setMakerNonce(3); // onChainNonce = 3; next offer gets nonce 4
        (Offer memory offer,) = _authorizeOffer(80e18, 8e18, 1 hours, 100e18);
        assertEq(offer.nonce, 4);
        request.consume(offer, "", 50e18);
        assertEq(token.balanceOf(address(request)), 50e18);
    }

    // ─── cancelOffers ──────────────────────────────────────────────────────────

    function testCancelOffer_NotCaller() external {
        _authorizeOffer(80e18, 8e18, 1 hours, 0); // issue nonce 1
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, stranger, PULL_ROLE)
        );
        module.cancelOffers(address(request), 1);
    }

    function testCancelOffer_RequestNotAllowed() external {
        _authorizeOffer(80e18, 8e18, 1 hours, 0);
        vm.prank(admin);
        module.disallowRequest(address(request));
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.RequestNotAllowed.selector);
        module.cancelOffers(address(request), 1);
    }

    function testCancelOffer_RequestNotWhitelisted() external {
        _authorizeOffer(80e18, 8e18, 1 hours, 0);
        factory.set(address(request), false);
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.RequestNotWhitelisted.selector);
        module.cancelOffers(address(request), 1);
    }

    function testCancelOffer_NonceTooLow_AlreadyAtOnChain() external {
        // targetNonce == onChainNonce: already at or below the current chain state
        _authorizeOffer(80e18, 8e18, 1 hours, 0);
        vm.prank(curator);
        module.cancelOffers(address(request), 1); // onChainNonce advances to 1
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.NonceTooLow.selector);
        module.cancelOffers(address(request), 1); // targetNonce == onChainNonce → NonceTooLow
    }

    function testCancelOffer_NonceTooLow_BelowOnChain() external {
        // Advance on-chain nonce externally past a previously issued nonce
        _authorizeOffer(80e18, 8e18, 1 hours, 0); // lastIssued=1
        request.setMakerNonce(3); // onChainNonce=3 > lastIssued=1; issue more
        _authorizeOffer(80e18, 8e18, 1 hours, 0); // lastIssued=4
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.NonceTooLow.selector);
        module.cancelOffers(address(request), 2); // 2 <= onChainNonce(3) → NonceTooLow
    }

    function testCancelOffer_NonceNotIssued() external {
        _authorizeOffer(80e18, 8e18, 1 hours, 0); // lastIssued=1
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.NonceNotIssued.selector);
        module.cancelOffers(address(request), 2); // never issued
    }

    function testCancelOffer_NonceNotIssued_WhenNoOffersIssued() external {
        // lastIssuedNonce=0, any targetNonce > 0 is NonceNotIssued
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.NonceNotIssued.selector);
        module.cancelOffers(address(request), 1);
    }

    function testCancelOffer_Happy_Single() external {
        _authorizeOffer(80e18, 8e18, 1 hours, 0); // nonce 1
        vm.prank(curator);
        module.cancelOffers(address(request), 1);
        assertEq(request.makerNonce(), 1);
        assertEq(request.lastSetNonce(), 1);
    }

    function testCancelOffer_Happy_Partial() external {
        // Issue 3 offers; cancel only the first two
        _authorizeOffer(80e18, 8e18, 1 hours, 0); // nonce 1
        _authorizeOffer(60e18, 6e18, 1 hours, 0); // nonce 2
        (, bytes32 h3) = _authorizeOffer(40e18, 4e18, 1 hours, 0); // nonce 3
        vm.prank(curator);
        module.cancelOffers(address(request), 2); // cancel nonces 1,2; nonce 3 still live
        assertEq(request.makerNonce(), 2);
        assertEq(module.isValidSignature(h3, ""), bytes4(0x1626ba7e));
    }

    function testCancelOffer_Happy_All() external {
        (, bytes32 h1) = _authorizeOffer(80e18, 8e18, 1 hours, 0);
        (, bytes32 h2) = _authorizeOffer(60e18, 6e18, 1 hours, 0);
        (, bytes32 h3) = _authorizeOffer(40e18, 4e18, 1 hours, 0);
        vm.prank(curator);
        module.cancelOffers(address(request), 3); // cancel all — onChainNonce=3
        assertEq(request.makerNonce(), 3);
        // entries remain in storage; 3F's _validateOffer nonce check blocks actual consumption
        assertEq(module.isValidSignature(h1, ""), bytes4(0x1626ba7e));
        assertEq(module.isValidSignature(h2, ""), bytes4(0x1626ba7e));
        assertEq(module.isValidSignature(h3, ""), bytes4(0x1626ba7e));
    }

    function testCancelOffer_EmitsOfferCancelled() external {
        _authorizeOffer(80e18, 8e18, 1 hours, 0);
        vm.expectEmit(true, false, false, true, address(module));
        emit IThreeFModule.OfferCancelled(address(request), 1);
        vm.prank(curator);
        module.cancelOffers(address(request), 1);
    }

    function testCancelOffer_NextAuthorizeUsesHigherNonce() external {
        _authorizeOffer(80e18, 8e18, 1 hours, 0); // lastIssued=1
        vm.prank(curator);
        module.cancelOffers(address(request), 1); // onChainNonce=1
        // max(lastIssued=1, onChain=1) + 1 = 2
        (Offer memory offer,) = _authorizeOffer(80e18, 8e18, 1 hours, 0);
        assertEq(offer.nonce, 2);
    }

    // ─── burn ─────────────────────────────────────────────────────────────────

    function _setupBurn() internal {
        uint128 authPt = 100e18;
        uint128 authYt = 10e18;
        token.mint(address(module), authPt);
        vm.prank(curator);
        module.push(address(request), type(uint128).max, 0);
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
        module.burn(address(request));
    }

    function testBurn_AssetMismatch() external {
        _setupBurn();
        request.setAsset(address(0xdead)); // change after push
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.AssetMismatch.selector);
        module.burn(address(request));
    }

    function testBurn_RequestWrongFactory() external {
        _setupBurn();
        factory.set(address(request), false); // not from known factory
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.RequestWrongFactory.selector);
        module.burn(address(request));
    }

    function testBurn_NotRepaid() external {
        _setupBurn();
        request.setRepaid(false);
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.NotRepaid.selector);
        module.burn(address(request));
    }

    function testBurn_CannotWithdraw() external {
        _setupBurn();
        request.setCanWithdraw(false);
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.WithdrawalNotAllowed.selector);
        module.burn(address(request));
    }

    function testBurn_Happy() external {
        uint256 totalOut = 100e18;
        _setupBurn();

        vm.expectEmit(true, false, false, true, address(module));
        emit IThreeFModule.Burned(address(request), 100e18, 10e18, 90e18, 10e18);

        vm.prank(curator);
        module.burn(address(request));

        assertEq(token.balanceOf(address(module)), totalOut);
        assertEq(token.allowance(address(module), address(request)), 0);
    }

    function testBurn_ClearsLingeringApproval() external {
        _setupBurn();
        // Simulate a leftover approval (e.g. from a previously failed consume)
        vm.prank(address(module));
        token.approve(address(request), 999e18);
        assertGt(token.allowance(address(module), address(request)), 0);

        vm.prank(curator);
        module.burn(address(request));

        assertEq(token.allowance(address(module), address(request)), 0);
    }

    // ─── allowedRequests ──────────────────────────────────────────────────────

    function testAllowedRequestsCount() external {
        assertEq(module.allowedRequestsCount(), 1); // setUp allowed one request
        MockRequest request2 = new MockRequest();
        request2.setAsset(address(token));
        factory.set(address(request2), true);
        whitelist.set(address(request2), IWhitelist.WhitelistStatus.Whitelisted);
        vm.prank(admin);
        module.allowRequest(address(request2));
        assertEq(module.allowedRequestsCount(), 2);
    }

    function testAllowedRequestAt() external view {
        assertEq(module.allowedRequestAt(0), address(request));
    }

    function testAllowedRequests_DisallowDecrements() external {
        assertEq(module.allowedRequestsCount(), 1);
        vm.prank(admin);
        module.disallowRequest(address(request));
        assertEq(module.allowedRequestsCount(), 0);
    }

    // ─── view helpers ─────────────────────────────────────────────────────────

    function testMintAuthorization() external view {
        (uint128 pt, uint128 yt) = IRequest(address(request)).mintAuthorization(address(module));
        assertEq(pt, 100e18);
        assertEq(yt, 10e18);
    }

    function testBalancesOf() external {
        request.setBalances(42e18, 7e18);
        (uint128 pt, uint128 yt) = IRequest(address(request)).balancesOf(address(module));
        assertEq(pt, 42e18);
        assertEq(yt, 7e18);
    }

    function testConvertToAssets() external {
        request.setBalances(60e18, 20e18);
        (uint128 pt, uint128 yt) = IRequest(address(request)).balancesOf(address(module));
        (uint256 pAssets, uint256 yAssets) = IRequest(address(request)).convertToAssets(pt, yt);
        assertEq(pAssets, 60e18);
        assertEq(yAssets, 20e18);
    }
}
