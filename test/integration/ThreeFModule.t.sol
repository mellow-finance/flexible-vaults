// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Test.sol";

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IOfferReceiver, Offer} from "../../scripts/common/interfaces/3F/IOfferReceiver.sol";
import {IRequest} from "../../scripts/common/interfaces/3F/IRequest.sol";
import {IRequestFactory} from "../../scripts/common/interfaces/3F/IRequestFactory.sol";
import {IWhitelist} from "../../scripts/common/interfaces/3F/IWhitelist.sol";
import {IThreeFModule} from "../../src/interfaces/utils/IThreeFModule.sol";
import "../../src/utils/ThreeFModule.sol";

contract ThreeFModuleIntegration is Test {
    // ─── 3F Protocol (mainnet) ────────────────────────────────────────────────

    address constant REQUEST_FACTORY = 0xDE293185e96a42F4c7d1C6479407920b19012Ca5;
    address constant REQUEST_WHITELIST = 0x3FcD87948cBF46605D6ded0ed56d3daCcd9daf9e;
    address constant WHITELIST_OWNER = 0x9e2f211E5e8cAaD07F2E2210928Aa274b458042D;
    address constant OPERATOR = 0x2C47E654116ccFc27a4beE06Dd9D8610Df840f83;
    address constant PULLER = 0x4e013ca8fF612a58F53C822904cDD0eC538a4A4F;
    address constant CONSUMER = 0x2ADaC155B8Decc03D4F5f003d4A02af05Dc74398;

    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    uint256 constant USDC_UNIT = 1e6;

    // ─── Actors ───────────────────────────────────────────────────────────────

    address admin = vm.createWallet("admin").addr;
    address curator = vm.createWallet("curator").addr;
    address subvault = vm.createWallet("subvault").addr;

    ThreeFModule module;

    function setUp() public {
        ThreeFModule impl = new ThreeFModule("Mellow", 1, USDC);
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(impl), admin, new bytes(0));
        module = ThreeFModule(address(proxy));

        address[] memory holders = new address[](4);
        bytes32[] memory roles = new bytes32[](4);
        holders[0] = admin;
        roles[0] = impl.ALLOW_REQUEST_ROLE();
        holders[1] = curator;
        roles[1] = impl.PUSH_ROLE();
        holders[2] = curator;
        roles[2] = impl.PULL_ROLE();
        holders[3] = curator;
        roles[3] = impl.BURN_ROLE();
        module.initialize(abi.encode(admin, subvault, REQUEST_WHITELIST, REQUEST_FACTORY, holders, roles));
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────

    /// Deploys a fresh Request via the 3F factory (pranks OPERATOR). No whitelist, no allow.
    function _deployRequest() internal returns (address request) {
        vm.prank(OPERATOR);
        (request,,) = IRequestFactory(REQUEST_FACTORY).createRequest(
            OPERATOR, PULLER, CONSUMER, USDC, "mellow-int", "MINT", uint64(block.timestamp + 90 days), uint40(0)
        );
    }

    /// Whitelists a request in the 3F registry (pranks WHITELIST_OWNER).
    function _whitelistRequest(address request) internal {
        address[] memory batch = new address[](1);
        batch[0] = request;
        vm.prank(WHITELIST_OWNER);
        IWhitelist(REQUEST_WHITELIST).whitelist(batch);
    }

    /// Deploy + whitelist + allow in module. Ready for push/pull/burn.
    function _createRequest() internal returns (address request) {
        request = _deployRequest();
        _whitelistRequest(request);
        vm.prank(admin);
        module.allowRequest(request);
    }

    /// Authorize minting on `request`, fund the module, and push.
    function _pushIntoRequest(address request, uint128 authPt, uint128 authYt) internal {
        vm.prank(OPERATOR);
        IRequest(request).authorizeMinting(address(module), authPt, authYt);
        deal(USDC, address(module), authPt);
        vm.prank(curator);
        module.push(request, authPt, authYt);
    }

    /// Simulate OPERATOR repaying `request` and marking it as repaid.
    function _repayRequest(address request, uint256 amount) internal {
        deal(USDC, OPERATOR, amount);
        vm.startPrank(OPERATOR);
        IERC20(USDC).approve(request, amount);
        IRequest(request).repay(amount);
        IRequest(request).setRepaid(0, type(uint256).max);
        vm.stopPrank();
    }

    // ─── Deployment ───────────────────────────────────────────────────────────

    function testDeploy_NO_CI() external view {
        assertEq(module.asset(), USDC);
        assertEq(module.subvault(), subvault);
        assertEq(module.whitelist(), REQUEST_WHITELIST);
        assertEq(module.requestFactory(), REQUEST_FACTORY);
        assertTrue(module.hasRole(module.ALLOW_REQUEST_ROLE(), admin));
        assertTrue(module.hasRole(module.PUSH_ROLE(), curator));
        assertTrue(module.hasRole(module.PULL_ROLE(), curator));
        assertTrue(module.hasRole(module.BURN_ROLE(), curator));
        assertTrue(module.hasRole(module.DEFAULT_ADMIN_ROLE(), admin));
    }

    // ─── allowRequest / disallowRequest ──────────────────────────────────────

    function testAllowRequest_NO_CI() external {
        address request = _deployRequest();
        _whitelistRequest(request);

        assertFalse(module.isRequestAllowed(request));
        vm.prank(admin);
        module.allowRequest(request);
        assertTrue(module.isRequestAllowed(request));
    }

    function testDisallowRequest_NO_CI() external {
        address request = _createRequest();

        assertTrue(module.isRequestAllowed(request));
        vm.prank(admin);
        module.disallowRequest(request);
        assertFalse(module.isRequestAllowed(request));
    }

    // ─── isRequestWhitelisted ────────────────────────────────────────────────

    function testIsRequestWhitelisted_True_NO_CI() external {
        address request = _createRequest();
        assertTrue(module.isRequestAllowed(request));
        assertTrue(module.isRequestWhitelisted(request));
    }

    function testIsRequestWhitelisted_NotWhitelisted_NO_CI() external {
        address request = _deployRequest(); // factory-created, not whitelisted
        assertFalse(module.isRequestAllowed(request));
        assertFalse(module.isRequestWhitelisted(request));
    }

    // ─── pushAssets / pullAssets ──────────────────────────────────────────────

    function testPushAssets_NO_CI() external {
        uint256 amount = 1000 * USDC_UNIT;
        deal(USDC, subvault, amount);

        vm.startPrank(subvault);
        IERC20(USDC).approve(address(module), amount);
        module.pushAssets(amount);
        vm.stopPrank();

        assertEq(IERC20(USDC).balanceOf(address(module)), amount);
        assertEq(IERC20(USDC).balanceOf(subvault), 0);
    }

    function testPushAssets_PullAssets_NO_CI() external {
        uint256 amount = 1000 * USDC_UNIT;
        deal(USDC, subvault, amount);

        vm.startPrank(subvault);
        IERC20(USDC).approve(address(module), amount);
        module.pushAssets(amount);
        module.pullAssets(amount);
        vm.stopPrank();

        assertEq(IERC20(USDC).balanceOf(subvault), amount);
        assertEq(IERC20(USDC).balanceOf(address(module)), 0);
    }

    // ─── nextNonce ────────────────────────────────────────────────────────────

    function testNextNonce_Fresh_NO_CI() external {
        address request = _createRequest();
        assertEq(module.nextNonce(request), IOfferReceiver(request).nonce(address(module)) + 1);
        assertEq(module.nextNonce(request), 1);
    }

    // ─── view helpers ─────────────────────────────────────────────────────────

    function testMintAuthorization_Zero_NO_CI() external {
        address request = _createRequest();
        (uint128 pt, uint128 yt) = module.mintAuthorization(request);
        assertEq(pt, 0);
        assertEq(yt, 0);
    }

    function testBalancesOf_Zero_NO_CI() external {
        address request = _createRequest();
        (uint128 pt, uint128 yt) = module.balancesOf(request);
        assertEq(pt, 0);
        assertEq(yt, 0);
    }

    function testBalance_NoPositions_NO_CI() external view {
        assertEq(module.balance(0, 10), 0);
    }

    function testIsValidSignature_OutsidePull_NO_CI() external view {
        assertEq(module.isValidSignature(keccak256("test"), ""), bytes4(0xffffffff));
    }

    // ─── push flow ────────────────────────────────────────────────────────────

    function testPush_NoAuthorization_NO_CI() external {
        address request = _createRequest();
        uint128 maxPt = 1000 * uint128(USDC_UNIT);
        deal(USDC, address(module), maxPt);

        vm.prank(curator);
        vm.expectRevert(IThreeFModule.InsufficientPtAuthorization.selector);
        module.push(request, maxPt, 1);
    }

    function testPush_InsufficientYtAuthorization_NO_CI() external {
        address request = _createRequest();
        uint128 authPt = 1000 * uint128(USDC_UNIT);
        uint128 authYt = 10 * uint128(USDC_UNIT);
        uint128 minYt = authYt + 1; // one above what the operator authorized

        vm.prank(OPERATOR);
        IRequest(request).authorizeMinting(address(module), authPt, authYt);
        deal(USDC, address(module), authPt);

        vm.prank(curator);
        vm.expectRevert(IThreeFModule.InsufficientYtAuthorization.selector);
        module.push(request, authPt, minYt);
    }

    function testPush_Happy_NO_CI() external {
        address request = _createRequest();
        uint128 authPt = 1000 * uint128(USDC_UNIT);
        uint128 authYt = 100 * uint128(USDC_UNIT);

        _pushIntoRequest(request, authPt, authYt);

        (uint128 pt,) = module.balancesOf(request);
        assertGt(pt, 0);
        assertEq(module.activeRequestsCount(), 1);
        assertEq(module.activeRequestAt(0), request);
        assertEq(IERC20(USDC).balanceOf(address(module)), 0);
    }

    // ─── pull flow ────────────────────────────────────────────────────────────
    //
    // The real Request.consume() enforces that msg.sender holds the consumer role,
    // which is a separate 3F-side entity — not the maker. Since our module is both
    // maker (offer.maker == address(module)) and the caller of consume(), the happy
    // path cannot succeed against real mainnet contracts. Pre-consume validation is
    // fully covered by the unit test suite via MockRequest.

    function testPull_StaleNonce_NO_CI() external {
        address request = _createRequest();
        deal(USDC, address(module), 1000 * USDC_UNIT);

        Offer memory offer = Offer({
            maker: address(module),
            amount: 500 * USDC_UNIT,
            expectedReturn: 50 * USDC_UNIT,
            nonce: 0, // request.nonce(module) == 0 → 0 <= 0 → StaleNonce
            expiration: block.timestamp + 1 hours,
            useCallback: false
        });

        vm.prank(curator);
        vm.expectRevert(IThreeFModule.StaleNonce.selector);
        module.pull(request, offer, 500 * USDC_UNIT, 1);
    }

    // ─── burn flow ────────────────────────────────────────────────────────────

    function testBurn_RequestNotActive_NO_CI() external {
        address request = _createRequest();

        // No push/pull done — request is allowed+whitelisted but not active
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.RequestNotActive.selector);
        module.burn(request, 1);
    }

    function testBurn_ZeroMinAssetOut_NO_CI() external {
        address request = _createRequest();
        _pushIntoRequest(request, 1000 * uint128(USDC_UNIT), 100 * uint128(USDC_UNIT));

        // Active but minAssetOut == 0 — checked before isRepaid
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.ZeroMinAssetOut.selector);
        module.burn(request, 0);
    }

    function testBurn_NotRepaid_NO_CI() external {
        address request = _createRequest();
        _pushIntoRequest(request, 1000 * uint128(USDC_UNIT), 100 * uint128(USDC_UNIT));

        vm.prank(curator);
        vm.expectRevert(IThreeFModule.NotRepaid.selector);
        module.burn(request, 1);
    }

    function testBurn_InsufficientOutput_NO_CI() external {
        address request = _createRequest();
        uint128 authPt = 1000 * uint128(USDC_UNIT);
        uint128 authYt = 100 * uint128(USDC_UNIT);

        _pushIntoRequest(request, authPt, authYt);
        _repayRequest(request, authPt);

        vm.prank(curator);
        vm.expectRevert(IThreeFModule.InsufficientOutput.selector);
        module.burn(request, type(uint256).max);
    }

    function testBurn_Happy_NO_CI() external {
        address request = _createRequest();
        uint128 authPt = 1000 * uint128(USDC_UNIT);
        uint128 authYt = 100 * uint128(USDC_UNIT);

        _pushIntoRequest(request, authPt, authYt);
        _repayRequest(request, authPt);

        assertTrue(IRequest(request).isRepaid());
        assertTrue(IRequest(request).canWithdraw());

        uint256 moduleBefore = IERC20(USDC).balanceOf(address(module));
        vm.prank(curator);
        module.burn(request, 1);

        assertGt(IERC20(USDC).balanceOf(address(module)), moduleBefore);
        assertEq(module.activeRequestsCount(), 0);
    }
}
