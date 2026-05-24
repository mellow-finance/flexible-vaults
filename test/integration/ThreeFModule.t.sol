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
        module.push(request, type(uint128).max, 0);
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

    // ─── currentNonce / lastIssuedNonce ──────────────────────────────────────

    function testCurrentNonce_Fresh_NO_CI() external {
        address request = _createRequest();
        assertEq(module.currentNonce(request), IOfferReceiver(request).nonce(address(module)));
        assertEq(module.currentNonce(request), 0);
        assertEq(module.lastIssuedNonce(request), 0);
    }

    // ─── view helpers ─────────────────────────────────────────────────────────

    function testMintAuthorization_Zero_NO_CI() external {
        address request = _createRequest();
        (uint128 pt, uint128 yt) = IRequest(request).mintAuthorization(address(module));
        assertEq(pt, 0);
        assertEq(yt, 0);
    }

    function testBalancesOf_Zero_NO_CI() external {
        address request = _createRequest();
        (uint128 pt, uint128 yt) = IRequest(request).balancesOf(address(module));
        assertEq(pt, 0);
        assertEq(yt, 0);
    }

    function testBalance_NoPositions_NO_CI() external view {
        assertEq(module.allowedRequestsCount(), 0);
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
        vm.expectRevert(IThreeFModule.InsufficientAuthorization.selector);
        module.push(request, type(uint128).max, 0);
    }

    function testPush_Happy_NO_CI() external {
        address request = _createRequest();
        uint128 authPt = 1000 * uint128(USDC_UNIT);
        uint128 authYt = 100 * uint128(USDC_UNIT);

        _pushIntoRequest(request, authPt, authYt);

        (uint128 pt,) = IRequest(request).balancesOf(address(module));
        assertGt(pt, 0);
        assertEq(IERC20(USDC).balanceOf(address(module)), 0);
    }

    // ─── pull flow ────────────────────────────────────────────────────────────
    //
    // Full pull flow:
    //   1. Curator calls module.authorizeOffer → module stores ERC-1271 authorization.
    //   2. CONSUMER (holds _ROLE_CONSUMER on the Request) calls request.consume(offer, "", ptAmount).
    //   3. Request validates ERC-1271: calls module.isValidSignature → returns magic.
    //   4. Request calls module.onRequestConsumed (callback) → module approves USDC to request.
    //   5. Request does safeTransferFrom(module → request, ptAmount), mints PT/YT to module.

    function testAuthorizeOffer_ZeroDuration_NO_CI() external {
        address request = _createRequest();
        vm.prank(curator);
        vm.expectRevert(IThreeFModule.ZeroValue.selector);
        module.authorizeOffer(request, 500 * USDC_UNIT, 50 * USDC_UNIT, 0);
    }

    function testAuthorizeOffer_Happy_NO_CI() external {
        address request = _createRequest();

        vm.prank(curator);
        (, bytes32 offerHash) = module.authorizeOffer(request, 500 * USDC_UNIT, 50 * USDC_UNIT, 1 hours);

        assertEq(module.isValidSignature(offerHash, ""), bytes4(0x1626ba7e));
    }

    function testPull_Happy_NO_CI() external {
        address request = _createRequest();

        uint256 amount = 1000 * USDC_UNIT;
        uint256 expectedReturn = 100 * USDC_UNIT;
        uint256 duration = 1 hours;
        uint256 ptAmount = amount; // full fill

        deal(USDC, address(module), amount);

        vm.prank(curator);
        (Offer memory offer, bytes32 offerHash) = module.authorizeOffer(request, amount, expectedReturn, duration);

        vm.prank(CONSUMER);
        uint256 ytAmount = IRequest(request).consume(offer, "", ptAmount);

        (uint128 pt, uint128 yt) = IRequest(request).balancesOf(address(module));
        assertEq(pt, ptAmount);
        assertEq(ytAmount, expectedReturn);
        assertGt(yt, 0);

        assertEq(IERC20(USDC).balanceOf(address(module)), 0);
        assertEq(IERC20(USDC).allowance(address(module), request), 0);
        assertEq(module.isValidSignature(offerHash, ""), bytes4(0xffffffff));
    }

    function testPull_TwoOffers_NO_CI() external {
        // Each 3F offer can be consumed once — the nonce advances after each consume.
        // Two separate authorizations with consecutive nonces simulate incremental lending.
        address request = _createRequest();
        uint256 duration = 1 hours;

        // ── First offer: 400 USDC ─────────────────────────────────────────────
        uint256 amount1 = 400 * USDC_UNIT;
        deal(USDC, address(module), amount1);
        vm.prank(curator);
        (Offer memory offer1,) = module.authorizeOffer(request, amount1, 40 * USDC_UNIT, duration);

        vm.prank(CONSUMER);
        IRequest(request).consume(offer1, "", amount1);

        assertEq(IOfferReceiver(request).nonce(address(module)), offer1.nonce);

        // ── Second offer: 600 USDC (nonce auto-incremented) ───────────────────
        uint256 amount2 = 600 * USDC_UNIT;
        deal(USDC, address(module), amount2);
        vm.prank(curator);
        (Offer memory offer2,) = module.authorizeOffer(request, amount2, 60 * USDC_UNIT, duration);

        vm.prank(CONSUMER);
        IRequest(request).consume(offer2, "", amount2);

        // Both fills complete — combined PT/YT position
        (uint128 pt, uint128 yt) = IRequest(request).balancesOf(address(module));
        assertGt(pt, 0);
        assertGt(yt, 0);
        assertEq(IERC20(USDC).balanceOf(address(module)), 0);
    }

    // ─── burn flow ────────────────────────────────────────────────────────────

    function testBurn_NotRepaid_NO_CI() external {
        address request = _createRequest();
        _pushIntoRequest(request, 1000 * uint128(USDC_UNIT), 100 * uint128(USDC_UNIT));

        vm.prank(curator);
        vm.expectRevert(IThreeFModule.NotRepaid.selector);
        module.burn(request);
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
        module.burn(request);

        assertGt(IERC20(USDC).balanceOf(address(module)), moduleBefore);
    }
}
