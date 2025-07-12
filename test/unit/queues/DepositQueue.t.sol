// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../Fixture.t.sol";
import "../../Imports.sol";

contract DepositQueueTest is FixtureTest {
    address vaultAdmin = vm.createWallet("vaultAdmin").addr;
    address vaultProxyAdmin = vm.createWallet("vaultProxyAdmin").addr;
    address asset;
    address[] assetsDefault;

    function setUp() external {
        asset = address(new MockERC20());
        assetsDefault.push(asset);
    }

    function testDeposit() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        DepositQueue queue = DepositQueue(addDepositQueue(deployment, vaultProxyAdmin, asset));
        IOracle.SecurityParams memory securityParams = deployment.oracle.securityParams();

        uint224 amount = 1 ether;

        vm.expectRevert(abi.encodeWithSelector(IQueue.ZeroValue.selector));
        queue.deposit(0, address(0), new bytes32[](0));

        /// @dev push a report to set the initial price
        pushReport(deployment.oracle, IOracle.Report({asset: asset, priceD18: 1e18}));
        address user = vm.createWallet("user").addr;
        giveAssetsToUserAndApprove(user, amount, address(queue));

        assertEq(queue.claimableOf(user), 0, "Claimable amount should be zero before deposit");

        vm.prank(user);
        queue.deposit(amount, address(0), new bytes32[](0));

        (uint256 timestamp, uint256 assets) = queue.requestOf(user);
        assertEq(timestamp, block.timestamp, "Timestamp should match current block timestamp");
        assertEq(assets, amount, "Assets should match the deposited amount");

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IDepositQueue.PendingRequestExists.selector));
        queue.deposit(amount, address(0), new bytes32[](0));

        /// @dev update the price
        vm.warp(block.timestamp + Math.max(securityParams.timeout, securityParams.redeemInterval));
        pushReport(deployment.oracle, IOracle.Report({asset: asset, priceD18: 1e18}));

        uint256 claimable = queue.claimableOf(user);
        assertEq(claimable, amount, "Claimable amount should match the deposited amount");
    }

    function testClaim() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        DepositQueue queue = DepositQueue(addDepositQueue(deployment, vaultProxyAdmin, asset));
        IOracle.SecurityParams memory securityParams = deployment.oracle.securityParams();

        /// @dev push a report to set the initial price
        pushReport(deployment.oracle, IOracle.Report({asset: asset, priceD18: 1e18}));
        address user = vm.createWallet("user").addr;
        uint256 amount = 1 ether;

        makeDeposit(user, amount, queue);

        assertEq(queue.claimableOf(user), 0, "Claimable amount should be zero before deposit");
        assertEq(deployment.shareManager.activeSharesOf(user), 0, "User should have no shares before the price update");
        assertEq(
            deployment.shareManager.claimableSharesOf(user),
            0,
            "User should have no claimable shares before the price update"
        );

        /// @dev try to do claim
        assertFalse(queue.claim(user), "Claim should fail before the price update");

        /// @dev update the price
        vm.warp(block.timestamp + Math.max(securityParams.timeout, securityParams.redeemInterval));
        pushReport(deployment.oracle, IOracle.Report({asset: asset, priceD18: 1e18}));

        assertEq(queue.claimableOf(user), amount, "Claimable amount should match the deposited amount");
        assertEq(deployment.shareManager.activeSharesOf(user), 0, "User should have no shares before claiming");
        assertEq(
            deployment.shareManager.claimableSharesOf(user), amount, "User should have claimable shares before claiming"
        );

        /// @dev do actual claim
        assertTrue(queue.claim(user), "Claim should succeed after the price update");

        assertEq(queue.claimableOf(user), 0, "Claimable amount should be zero after claiming");
        assertEq(deployment.shareManager.activeSharesOf(user), amount, "User should have shares after claiming");
        assertEq(
            deployment.shareManager.claimableSharesOf(user), 0, "User should have no claimable shares after claiming"
        );
    }

    function testCancelDepositRequest() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        DepositQueue queue = DepositQueue(addDepositQueue(deployment, vaultProxyAdmin, asset));
        IOracle.SecurityParams memory securityParams = deployment.oracle.securityParams();

        /// @dev push a report to set the initial price
        pushReport(deployment.oracle, IOracle.Report({asset: asset, priceD18: 1e18}));

        address user = vm.createWallet("user").addr;
        uint256 amount = 1 ether;
        {
            /// @dev cancel before claimable
            vm.prank(user);
            vm.expectRevert(abi.encodeWithSelector(IDepositQueue.NoPendingRequest.selector));
            queue.cancelDepositRequest();

            makeDeposit(user, amount, queue);
            assertEq(queue.claimableOf(user), 0, "Claimable amount should be zero before deposit");

            (, uint256 assets) = queue.requestOf(user);
            assertEq(assets, amount, "Assets should match the deposited amount");

            vm.prank(user);
            queue.cancelDepositRequest();

            (, assets) = queue.requestOf(user);
            assertEq(assets, 0, "Assets should be zero after canceling the request");
            assertEq(queue.claimableOf(user), 0, "Claimable amount should match the deposited amount");
        }

        {
            /// @dev cancel after claimable
            makeDeposit(user, amount, queue);
            assertEq(queue.claimableOf(user), 0, "Claimable amount should be zero before deposit");

            (, uint256 assets) = queue.requestOf(user);
            assertEq(assets, amount, "Assets should match the deposited amount");

            vm.warp(block.timestamp + Math.max(securityParams.timeout, securityParams.redeemInterval));
            pushReport(deployment.oracle, IOracle.Report({asset: asset, priceD18: 1e18}));

            vm.prank(user);
            vm.expectRevert(abi.encodeWithSelector(IDepositQueue.ClaimableRequestExists.selector));
            queue.cancelDepositRequest();

            (, assets) = queue.requestOf(user);
            assertEq(assets, amount, "Assets should not be zero because the request is claimable");
            assertEq(queue.claimableOf(user), amount, "Claimable amount should match the deposited amount");
        }
    }

    function testDepositPausedQueue() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        DepositQueue queue = DepositQueue(addDepositQueue(deployment, vaultProxyAdmin, asset));

        /// @dev push a report to set the initial price
        pushReport(deployment.oracle, IOracle.Report({asset: asset, priceD18: 1e18}));

        address user = vm.createWallet("user").addr;
        uint224 amount = 1 ether;

        vm.startPrank(vaultAdmin);
        deployment.vault.grantRole(deployment.vault.SET_QUEUE_STATUS_ROLE(), vaultAdmin);
        deployment.vault.setQueueStatus(address(queue), true);
        vm.stopPrank();

        giveAssetsToUserAndApprove(user, amount, address(queue));
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IQueue.QueuePaused.selector));
        queue.deposit(amount, address(0), new bytes32[](0));
    }

    function testDepositNotAllowed() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        DepositQueue queue = DepositQueue(addDepositQueue(deployment, vaultProxyAdmin, asset));

        /// @dev push a report to set the initial price
        pushReport(deployment.oracle, IOracle.Report({asset: asset, priceD18: 1e18}));

        address user = vm.createWallet("user").addr;
        uint224 amount = 1 ether;

        vm.prank(vaultAdmin);
        deployment.shareManager.setFlags(
            IShareManager.Flags({
                hasMintPause: false,
                hasBurnPause: false,
                hasTransferPause: false,
                hasWhitelist: true,
                hasTransferWhitelist: false,
                globalLockup: 0,
                targetedLockup: 1 days
            })
        );

        vm.prank(vaultAdmin);
        deployment.shareManager.setAccountInfo(
            user,
            IShareManager.AccountInfo({
                canDeposit: false,
                canTransfer: true,
                isBlacklisted: false,
                lockedUntil: uint32(block.timestamp + 1 days)
            })
        );

        giveAssetsToUserAndApprove(user, amount, address(queue));
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IDepositQueue.DepositNotAllowed.selector));
        queue.deposit(amount, address(0), new bytes32[](0));

        vm.prank(vaultAdmin);
        deployment.shareManager.setAccountInfo(
            user,
            IShareManager.AccountInfo({
                canDeposit: true,
                canTransfer: true,
                isBlacklisted: false,
                lockedUntil: uint32(block.timestamp + 1 days)
            })
        );

        /// @dev just to make sure the deposit works after the account is allowed
        vm.prank(user);
        queue.deposit(amount, address(0), new bytes32[](0));
        (, uint256 assets) = queue.requestOf(user);
        assertEq(assets, amount, "Assets should match the deposited amount");
    }

    function testMintFees() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        FeeManager feeManager = deployment.feeManager;
        DepositQueue queue = DepositQueue(addDepositQueue(deployment, vaultProxyAdmin, asset));
        IOracle.SecurityParams memory securityParams = deployment.oracle.securityParams();

        /// @dev push a report to set the initial price
        pushReport(deployment.oracle, IOracle.Report({asset: asset, priceD18: 1e18}));

        address user = vm.createWallet("user").addr;
        uint224 amount = 1 ether;
        uint24 depositFee = 1e4; // 0.01%

        makeDeposit(user, amount, queue);

        vm.warp(block.timestamp + Math.max(securityParams.timeout, securityParams.redeemInterval));
        pushReport(deployment.oracle, IOracle.Report({asset: asset, priceD18: 1e18}));

        assertEq(
            deployment.shareManager.activeSharesOf(feeManager.feeRecipient()),
            0,
            "Fee recipient should have no shares in case of 0 fees"
        );

        vm.prank(vaultAdmin);
        feeManager.setFees(depositFee, 0, 0, 0);

        makeDeposit(user, amount, queue);

        vm.warp(block.timestamp + Math.max(securityParams.timeout, securityParams.redeemInterval));
        pushReport(deployment.oracle, IOracle.Report({asset: asset, priceD18: 1e18}));

        assertEq(
            deployment.shareManager.activeSharesOf(feeManager.feeRecipient()),
            Math.mulDiv(uint256(amount), depositFee, 1e6),
            "Fee recipient should have shares based on deposit fee"
        );
        assertEq(deployment.shareManager.activeSharesOf(user), amount, "User should have shares based on deposit fee");
        assertEq(
            deployment.shareManager.activeShares(),
            Math.mulDiv(uint256(amount), depositFee + 1e6, 1e6),
            "User should have shares based on deposit fee"
        );
    }

    function testMultipleDeposit() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        DepositQueue queue = DepositQueue(addDepositQueue(deployment, vaultProxyAdmin, asset));
        IOracle.SecurityParams memory securityParams = deployment.oracle.securityParams();

        /// @dev push a report to set the initial price
        pushReport(deployment.oracle, IOracle.Report({asset: asset, priceD18: 1e18}));

        address[] memory users = new address[](10);
        uint256 amount = 1 ether;
        for (uint256 i = 0; i < users.length; i++) {
            users[i] = vm.createWallet(string(abi.encodePacked("user", i))).addr;
            vm.warp(block.timestamp + i * 1 hours);
            makeDeposit(users[i], amount, queue);
            assertEq(queue.claimableOf(users[i]), 0, "Claimable amount should be zero");
        }
        vm.warp(block.timestamp + Math.max(securityParams.timeout, securityParams.redeemInterval));
        pushReport(deployment.oracle, IOracle.Report({asset: asset, priceD18: 1e18}));

        for (uint256 i = 0; i < users.length; i++) {
            assertEq(queue.claimableOf(users[i]), amount, "Claimable amount should not be zero");
        }
    }

    function testHandleReport() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        DepositQueue queue = DepositQueue(addDepositQueue(deployment, vaultProxyAdmin, asset));

        IOracle.SecurityParams memory securityParams = IOracle.SecurityParams({
            maxAbsoluteDeviation: 6e16,
            suspiciousAbsoluteDeviation: 2e16,
            maxRelativeDeviationD18: 4e16,
            suspiciousRelativeDeviationD18: 3e16,
            timeout: 1000,
            depositInterval: 3600,
            redeemInterval: 3600
        });

        vm.prank(deployment.vaultAdmin);
        deployment.oracle.setSecurityParams(securityParams);

        pushReport(deployment.oracle, IOracle.Report({asset: asset, priceD18: 1e18}));
        address user1 = vm.createWallet("user1").addr;
        address user2 = vm.createWallet("user2").addr;
        address user3 = vm.createWallet("user3").addr;
        uint256 amount = 1 ether;

        makeDeposit(user1, amount, queue);

        vm.warp(block.timestamp + securityParams.timeout);
        pushReport(deployment.oracle, IOracle.Report({asset: asset, priceD18: 1e18}));

        makeDeposit(user2, amount, queue);

        vm.warp(block.timestamp + securityParams.timeout);
        pushReport(deployment.oracle, IOracle.Report({asset: asset, priceD18: 1e18}));

        makeDeposit(user3, amount, queue);

        vm.warp(block.timestamp + securityParams.depositInterval - securityParams.timeout + 1);
        pushReport(deployment.oracle, IOracle.Report({asset: asset, priceD18: 1e18}));
    }

    function testRequestsExtend() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        DepositQueue queue = DepositQueue(addDepositQueue(deployment, vaultProxyAdmin, asset));

        IOracle.SecurityParams memory securityParams = IOracle.SecurityParams({
            maxAbsoluteDeviation: 6e16,
            suspiciousAbsoluteDeviation: 2e16,
            maxRelativeDeviationD18: 4e16,
            suspiciousRelativeDeviationD18: 3e16,
            timeout: 1000,
            depositInterval: 3600,
            redeemInterval: 3600
        });

        vm.prank(deployment.vaultAdmin);
        deployment.oracle.setSecurityParams(securityParams);
        /// @dev push a report to set the initial price
        pushReport(deployment.oracle, IOracle.Report({asset: asset, priceD18: 1e18}));

        address[] memory users = new address[](17);
        for (uint256 i = 0; i < users.length; i++) {
            users[i] = vm.createWallet(string(abi.encodePacked("user", i))).addr;
        }
        uint256 amount = 1 ether;
        for (uint256 i = 0; i < 16; i++) {
            users[i] = vm.createWallet(string(abi.encodePacked("user", i))).addr;
            vm.warp(block.timestamp + 1 hours);
            makeDeposit(users[i], amount, queue);
            assertEq(queue.claimableOf(users[i]), 0, "Claimable amount should be zero");
        }

        vm.warp(block.timestamp + 1 hours);
        makeDeposit(users[16], amount, queue);
        assertEq(queue.claimableOf(users[16]), 0, "Claimable amount should be zero");
    }

    function pushReport(Oracle oracle, IOracle.Report memory report) internal {
        IOracle.Report[] memory reports = new IOracle.Report[](1);
        reports[0] = report;
        vm.startPrank(vaultAdmin);
        oracle.submitReports(reports);
        try oracle.acceptReport(asset, report.priceD18, uint32(block.timestamp)) {}
        catch (bytes memory) {
            /// @dev catch case if report is not suspicious
        }
        vm.stopPrank();
    }

    function makeDeposit(address account, uint256 amount, DepositQueue queue) internal {
        giveAssetsToUserAndApprove(account, uint224(amount), address(queue));
        vm.prank(account);
        queue.deposit(uint224(amount), address(0), new bytes32[](0));
    }

    function giveAssetsToUserAndApprove(address account, uint224 amount, address spender) internal {
        vm.startPrank(account);
        MockERC20(asset).mint(account, amount);
        MockERC20(asset).approve(spender, amount);
        vm.stopPrank();
    }
}
