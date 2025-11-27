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
        SyncDepositQueue queue = SyncDepositQueue(addSyncDepositQueue(deployment, vaultProxyAdmin, asset));

        assertEq(queue.asset(), asset, "Asset should match the deployed asset");

        uint224 amount = 1 ether;

        vm.expectRevert(abi.encodeWithSelector(IQueue.ZeroValue.selector));
        queue.deposit(0, address(0), new bytes32[](0));

        /// @dev push a report to set the initial price
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));
        address user = vm.createWallet("user").addr;
        giveAssetsToUserAndApprove(user, amount, address(queue));

        vm.prank(user);
        queue.deposit(amount, address(0), new bytes32[](0));

        assertEq(deployment.shareManager.activeSharesOf(user), amount, "User should have shares after deposit");
        assertEq(IERC20(asset).balanceOf(address(user)), 0, "User should have no assets after deposit");
    }

    function testDepositETH() external {
        address[] memory assets = new address[](1);
        assets[0] = TransferLibrary.ETH;

        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assets);
        SyncDepositQueue queue = SyncDepositQueue(addSyncDepositQueue(deployment, vaultProxyAdmin, TransferLibrary.ETH));

        pushReport(deployment, IOracle.Report({asset: TransferLibrary.ETH, priceD18: 1e18}));

        uint224 amount = 1 ether;
        address user = vm.createWallet("user").addr;
        makeSyncDeposit(user, amount, queue);

        assertEq(deployment.shareManager.activeSharesOf(user), amount, "User should have shares after deposit");
    }

    function testDepositLimitExceeded() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        SyncDepositQueue queue = SyncDepositQueue(addSyncDepositQueue(deployment, vaultProxyAdmin, asset));

        uint224 amount = 1 ether;
        uint224 priceD18 = 1e18; // initial price
        int256 vaultLimit = 0;

        vm.prank(deployment.vaultAdmin);
        deployment.riskManager.setVaultLimit(vaultLimit); // Set vault limit to zero

        /// @dev push a report to set the initial price
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: priceD18}));
        address user = vm.createWallet("user").addr;
        giveAssetsToUserAndApprove(user, 10 * amount, address(queue));

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IRiskManager.LimitExceeded.selector, amount, vaultLimit));
        queue.deposit(amount, address(0), new bytes32[](0));

        vaultLimit = 1.5 ether;
        vm.prank(deployment.vaultAdmin);
        deployment.riskManager.setVaultLimit(vaultLimit); // Reset vault limit

        vm.prank(user);
        queue.deposit(amount, address(0), new bytes32[](0));

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IRiskManager.LimitExceeded.selector, 2 * amount, vaultLimit));
        queue.deposit(amount, address(0), new bytes32[](0));
    }

    function testFuzzDepositsOneUser(int16[100] calldata amountDeviation, int16[100] calldata deltaPrice) external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        SyncDepositQueue queue = SyncDepositQueue(addSyncDepositQueue(deployment, vaultProxyAdmin, asset));
        IOracle.SecurityParams memory securityParams = deployment.oracle.securityParams();

        uint224 priceD18 = 1e18; // initial price

        /// @dev push a report to set the initial price
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: priceD18}));

        address user = vm.createWallet("user").addr;
        uint224[] memory amounts = new uint224[](amountDeviation.length);

        vm.prank(deployment.vaultAdmin);
        deployment.riskManager.setVaultLimit(1e6 ether);

        giveAssetsToUserAndApprove(user, 1e6 ether, address(queue));

        uint224 shareTotal;

        for (uint256 i = 0; i < amountDeviation.length; i++) {
            amounts[i] = _applyDeltaX16(1 ether, amountDeviation[i]);
            vm.prank(user);
            queue.deposit(amounts[i], address(0), new bytes32[](0));

            // Price at current report
            uint224 shareExpected = amounts[i] * priceD18 / 1e18;

            shareTotal += shareExpected;

            priceD18 = _applyDeltaX16Price(priceD18, deltaPrice[i], securityParams);

            assertEq(deployment.shareManager.activeSharesOf(user), shareTotal, "User should have shares after claiming");
            assertEq(
                deployment.shareManager.activeShares(), shareTotal, "Vault should have active shares after claiming"
            );

            skip(Math.max(securityParams.timeout, securityParams.depositInterval));
            pushReport(deployment, IOracle.Report({asset: asset, priceD18: priceD18}));
        }
    }

    function testFuzzDepositsMultipleUsers(int16[256] calldata amountDeviation, int16[256] calldata deltaPrice)
        external
    {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        SyncDepositQueue queue = SyncDepositQueue(addSyncDepositQueue(deployment, vaultProxyAdmin, asset));
        IOracle.SecurityParams memory securityParams = deployment.oracle.securityParams();

        uint224 priceD18 = 1e18; // initial price

        /// @dev push a report to set the initial price
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: priceD18}));

        address[] memory user = new address[](amountDeviation.length);
        for (uint256 i = 0; i < amountDeviation.length; i++) {
            user[i] = address(uint160(uint256(keccak256(abi.encodePacked("user", i)))));
        }

        uint224[] memory amounts = new uint224[](amountDeviation.length);
        uint224[] memory shareExpected = new uint224[](amountDeviation.length);

        vm.prank(deployment.vaultAdmin);
        deployment.riskManager.setVaultLimit(1e6 ether);

        uint224 shareTotal;
        for (uint256 i = 0; i < amountDeviation.length; i++) {
            amounts[i] = _applyDeltaX16(1 ether, amountDeviation[i]);
            makeSyncDeposit(user[i], amounts[i], queue);

            // Price at current report
            shareExpected[i] = amounts[i] * priceD18 / 1e18;

            shareTotal += shareExpected[i];

            priceD18 = _applyDeltaX16Price(priceD18, deltaPrice[i], securityParams);

            assertEq(
                deployment.shareManager.activeSharesOf(user[i]),
                shareExpected[i],
                "User should have shares after claiming"
            );
            assertEq(
                deployment.shareManager.activeShares(), shareTotal, "Vault should have active shares after claiming"
            );

            skip(Math.max(securityParams.timeout, securityParams.depositInterval));
            pushReport(deployment, IOracle.Report({asset: asset, priceD18: priceD18}));
        }
    }

    function testFuzzDepositMultipleQueuesSingleAsset(int16[100] calldata amountDeviation, uint16 priceD6) external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);

        vm.prank(deployment.vaultAdmin);
        deployment.riskManager.setVaultLimit(1e6 ether);

        uint256 queueLength = amountDeviation.length;
        SyncDepositQueue[] memory queues = new SyncDepositQueue[](queueLength);
        uint224[] memory amounts = new uint224[](queueLength);

        for (uint256 i = 0; i < queueLength; i++) {
            queues[i] = SyncDepositQueue(addSyncDepositQueue(deployment, vaultProxyAdmin, asset));
            amounts[i] = _applyDeltaX16(1 ether, amountDeviation[i]);
        }

        uint224 priceD18 = uint224(1 ether + uint224(priceD6) * 1e12); // Convert to D18

        /// @dev push a report to set the initial price
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: priceD18}));
        address user = vm.createWallet("user").addr;
        uint224 totalShare;
        for (uint256 i = 0; i < queueLength; i++) {
            makeSyncDeposit(user, amounts[i], queues[i]);

            totalShare += amounts[i] * priceD18 / 1e18;

            assertEq(deployment.shareManager.activeSharesOf(user), totalShare, "User should have shares after deposit");
        }
    }

    function testFuzzDepositMultipleQueuesMultipleAssets(int16[10] calldata amountDeviation) external {
        uint256 assetsLength = amountDeviation.length;
        address[] memory assets = new address[](assetsLength);
        uint224[] memory priceInit = new uint224[](assetsLength);
        uint224[] memory amounts = new uint224[](assetsLength);
        SyncDepositQueue[] memory queue = new SyncDepositQueue[](assetsLength);

        for (uint256 i = 0; i < assetsLength; i++) {
            assets[i] = address(new MockERC20());
            priceInit[i] = 1e18; // Initial price for each asset
            amounts[i] = _applyDeltaX16(1e18, amountDeviation[i]); // Amount to deposit for each asset
        }

        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assets);

        vm.prank(deployment.vaultAdmin);
        deployment.riskManager.setVaultLimit(1e6 ether);

        address user = vm.createWallet("user").addr;

        uint224 totalShare;
        for (uint256 i = 0; i < assetsLength; i++) {
            queue[i] = SyncDepositQueue(addSyncDepositQueue(deployment, vaultProxyAdmin, assets[i]));
            /// @dev push a report to set the initial price
            pushReport(deployment, IOracle.Report({asset: assets[i], priceD18: priceInit[i]}));

            makeSyncDeposit(user, amounts[i], queue[i]);

            totalShare += amounts[i] * priceInit[i] / 1e18;

            assertEq(deployment.shareManager.activeSharesOf(user), totalShare, "User should have shares after deposit");
        }
    }

    /// @notice Tests that the final amount of deposited assets is correct after various number of deposits.
    function testDepositRequestAmountIntegrity(uint8 initialReports, uint8 users) external {
        vm.assume(initialReports > 0); // [1, 255]
        vm.assume(users > 1 && users <= 32); // [2, 32]

        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        SyncDepositQueue queue = SyncDepositQueue(addSyncDepositQueue(deployment, vaultProxyAdmin, asset));
        IOracle.SecurityParams memory securityParams = deployment.oracle.securityParams();

        /// @dev push initial reports to check that the length of the "prices" list does not affect the calculation
        for (uint8 i = 0; i < initialReports; i++) {
            skip(securityParams.timeout);
            pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));
        }

        assertEq(IERC20(asset).balanceOf(address(deployment.vault)), 0);

        uint224 amount = 1 ether;

        for (uint8 i = 0; i < users; i++) {
            skip(1 minutes);

            address user = vm.addr(i + 1);
            makeSyncDeposit(user, amount, queue);
        }

        assertEq(IERC20(asset).balanceOf(address(deployment.vault)), amount * users);
    }

    function testDepositPausedQueue() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        SyncDepositQueue queue = SyncDepositQueue(addSyncDepositQueue(deployment, vaultProxyAdmin, asset));

        /// @dev push a report to set the initial price
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));

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
        SyncDepositQueue queue = SyncDepositQueue(addSyncDepositQueue(deployment, vaultProxyAdmin, asset));

        /// @dev push a report to set the initial price
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));

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
                globalLockup: 0
            })
        );

        vm.prank(vaultAdmin);
        deployment.shareManager.setAccountInfo(
            user, IShareManager.AccountInfo({canDeposit: false, canTransfer: true, isBlacklisted: false})
        );

        giveAssetsToUserAndApprove(user, amount, address(queue));
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IDepositQueue.DepositNotAllowed.selector));
        queue.deposit(amount, address(0), new bytes32[](0));

        vm.prank(vaultAdmin);
        deployment.shareManager.setAccountInfo(
            user, IShareManager.AccountInfo({canDeposit: true, canTransfer: true, isBlacklisted: false})
        );

        /// @dev just to make sure the deposit works after the account is allowed
        vm.prank(user);
        queue.deposit(amount, address(0), new bytes32[](0));
        assertEq(deployment.shareManager.activeSharesOf(user), amount, "User should have shares after deposit");
    }

    function testMintFees() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        FeeManager feeManager = deployment.feeManager;
        SyncDepositQueue queue = SyncDepositQueue(addSyncDepositQueue(deployment, vaultProxyAdmin, asset));

        /// @dev push a report to set the initial price
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));

        address user = vm.createWallet("user").addr;
        uint224 amount = 1 ether;
        uint24 depositFee = 1e4; // 0.01%

        makeSyncDeposit(user, amount, queue);

        assertEq(
            deployment.shareManager.activeSharesOf(feeManager.feeRecipient()),
            0,
            "Fee recipient should have no shares in case of 0 fees"
        );
        assertEq(deployment.shareManager.activeSharesOf(user), amount, "User should have shares based on deposit fee");

        vm.prank(vaultAdmin);
        feeManager.setFees(depositFee, 0, 0, 0);

        makeSyncDeposit(user, amount, queue);

        uint256 feeShares = Math.mulDiv(uint256(amount), depositFee, 1e6);

        assertEq(
            deployment.shareManager.activeSharesOf(feeManager.feeRecipient()),
            feeShares,
            "Fee recipient should have shares based on deposit fee"
        );
        assertEq(
            deployment.shareManager.activeSharesOf(user),
            2 * amount - feeShares,
            "User should have shares based on deposit fee"
        );
    }

    function testMultipleDeposit() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        SyncDepositQueue queue = SyncDepositQueue(addSyncDepositQueue(deployment, vaultProxyAdmin, asset));

        /// @dev push a report to set the initial price
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));

        address[] memory users = new address[](10);
        uint256 amount = 1 ether;
        for (uint256 i = 0; i < users.length; i++) {
            users[i] = vm.createWallet(string(abi.encodePacked("user", i))).addr;
            makeSyncDeposit(users[i], amount, queue);
        }

        for (uint256 i = 0; i < users.length; i++) {
            assertEq(
                deployment.shareManager.activeSharesOf(users[i]), amount, "User should have shares based on deposit fee"
            );
        }
    }
}
