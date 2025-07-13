// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../Imports.sol";
import "./BaseIntegrationTest.sol";

interface ISymbioticStorageVault {
    function setDepositWhitelist(bool status) external;
    function setDepositLimit(uint256 limit) external;
    function currentEpoch() external view returns (uint256);
    function activeBalanceOf(address user) external view returns (uint256);
    function activeStake() external view returns (uint256);
}

contract SymbioticWithSlashingIntegrationTest is BaseIntegrationTest {
    address public constant ASSET = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address public constant SYMBIOTIC_VAULT = 0x7b276aAD6D2ebfD7e270C5a2697ac79182D9550E;
    address public constant SYMBIOTIC_VAULT_ADMIN = 0x9437B2a8cF3b69D782a61f9814baAbc172f72003;

    Deployment private $;

    function setUp() external {
        $ = deployBase();

        vm.startPrank(SYMBIOTIC_VAULT_ADMIN);
        IAccessControl(SYMBIOTIC_VAULT).grantRole(keccak256("DEPOSIT_WHITELIST_SET_ROLE"), SYMBIOTIC_VAULT_ADMIN);
        IAccessControl(SYMBIOTIC_VAULT).grantRole(keccak256("DEPOSITOR_WHITELIST_ROLE"), SYMBIOTIC_VAULT_ADMIN);

        ISymbioticStorageVault(SYMBIOTIC_VAULT).setDepositWhitelist(false);
        ISymbioticStorageVault(SYMBIOTIC_VAULT).setDepositLimit(type(uint256).max);
        vm.stopPrank();
    }

    IOracle.SecurityParams securityParams = IOracle.SecurityParams({
        maxAbsoluteDeviation: 0.01 ether, // 1% abs
        suspiciousAbsoluteDeviation: 0.005 ether, // 0.05% abs
        maxRelativeDeviationD18: 0.01 ether, // 1% abs
        suspiciousRelativeDeviationD18: 0.005 ether, // 0.05% abs
        timeout: 20 hours,
        depositInterval: 1 hours,
        redeemInterval: 14 days
    });

    uint256 amountAfterSlashing;
    Vault vaultImplementation;
    Oracle oracleImplementation;

    function testSymbioticFlowWithSlashingWithRedemptionFee() external {
        address[] memory assets = new address[](1);
        assets[0] = ASSET;

        Vault.RoleHolder[] memory holders_ = new Vault.RoleHolder[](10);

        vaultImplementation = Vault(payable($.vaultFactory.implementationAt(0)));
        oracleImplementation = Oracle($.oracleFactory.implementationAt(0));

        holders_[0] = Vault.RoleHolder(vaultImplementation.CREATE_QUEUE_ROLE(), $.vaultAdmin);
        holders_[1] = Vault.RoleHolder(oracleImplementation.SUBMIT_REPORTS_ROLE(), $.vaultAdmin);
        holders_[2] = Vault.RoleHolder(oracleImplementation.ACCEPT_REPORT_ROLE(), $.vaultAdmin);
        holders_[3] = Vault.RoleHolder(vaultImplementation.CREATE_SUBVAULT_ROLE(), $.vaultAdmin);
        holders_[4] = Vault.RoleHolder(Verifier($.verifierFactory.implementationAt(0)).CALLER_ROLE(), $.curator);
        holders_[5] = Vault.RoleHolder(
            RiskManager($.riskManagerFactory.implementationAt(0)).SET_SUBVAULT_LIMIT_ROLE(), $.vaultAdmin
        );
        holders_[6] = Vault.RoleHolder(
            RiskManager($.riskManagerFactory.implementationAt(0)).ALLOW_SUBVAULT_ASSETS_ROLE(), $.vaultAdmin
        );
        holders_[7] =
            Vault.RoleHolder(Oracle($.oracleFactory.implementationAt(0)).SET_SECURITY_PARAMS_ROLE(), $.vaultAdmin);
        holders_[8] = Vault.RoleHolder(vaultImplementation.REMOVE_QUEUE_ROLE(), $.vaultAdmin);

        holders_[9] = Vault.RoleHolder(vaultImplementation.SET_QUEUE_STATUS_ROLE(), $.vaultAdmin);

        (,,, address oracle, address vault_) = $.vaultConfigurator.create(
            VaultConfigurator.InitParams({
                version: 0,
                proxyAdmin: $.vaultProxyAdmin,
                vaultAdmin: $.vaultAdmin,
                shareManagerVersion: 0,
                shareManagerParams: abi.encode(bytes32(0), string("MellowVault"), string("MV")),
                feeManagerVersion: 0,
                feeManagerParams: abi.encode($.vaultAdmin, $.protocolTreasury, uint24(0), uint24(0), uint24(0), uint24(0)),
                riskManagerVersion: 0,
                riskManagerParams: abi.encode(int256(100 ether)),
                oracleVersion: 0,
                oracleParams: abi.encode(securityParams, assets),
                defaultDepositHook: address(new RedirectingDepositHook()),
                defaultRedeemHook: address(new BasicRedeemHook()),
                queueLimit: 16,
                roleHolders: holders_
            })
        );
        Vault vault = Vault(payable(vault_));

        vm.startPrank($.vaultAdmin);
        vault.feeManager().setFees(0, 1e4, 0, 0); // 1% redeem fee
        vm.stopPrank();

        vm.startPrank($.vaultAdmin);
        vault.createQueue(0, true, $.vaultProxyAdmin, ASSET, new bytes(0));
        vault.createQueue(0, false, $.vaultProxyAdmin, ASSET, new bytes(0));
        {
            IOracle.Report[] memory reports = new IOracle.Report[](1);
            reports[0] = IOracle.Report({asset: ASSET, priceD18: 1 ether});
            Oracle(oracle).submitReports(reports);
            Oracle(oracle).acceptReport(ASSET, 1 ether, uint32(block.timestamp));
        }
        SymbioticVerifier symbioticVerifier;
        {
            address[] memory holderAddresses = new address[](2);
            bytes32[] memory roles = new bytes32[](holderAddresses.length);

            SymbioticVerifier symbioticVerifierImplementation =
                SymbioticVerifier($.protocolVerifierFactory.implementationAt(0));

            holderAddresses[0] = $.curator;
            roles[0] = symbioticVerifierImplementation.CALLER_ROLE();

            holderAddresses[1] = SYMBIOTIC_VAULT;
            roles[1] = symbioticVerifierImplementation.SYMBIOTIC_VAULT_ROLE();
            symbioticVerifier = SymbioticVerifier(
                $.protocolVerifierFactory.create(0, $.vaultProxyAdmin, abi.encode($.vaultAdmin, holderAddresses, roles))
            );
        }

        ERC20Verifier erc20Verifier;
        {
            address[] memory holders = new address[](3);
            bytes32[] memory roles = new bytes32[](holders.length);

            ERC20Verifier erc20VerifierImplementation = ERC20Verifier($.protocolVerifierFactory.implementationAt(1));

            holders[0] = ASSET;
            roles[0] = erc20VerifierImplementation.ASSET_ROLE();

            holders[1] = $.curator;
            roles[1] = erc20VerifierImplementation.CALLER_ROLE();

            holders[2] = SYMBIOTIC_VAULT;
            roles[2] = erc20VerifierImplementation.RECIPIENT_ROLE();

            erc20Verifier = ERC20Verifier(
                $.protocolVerifierFactory.create(1, $.vaultProxyAdmin, abi.encode($.vaultAdmin, holders, roles))
            );
        }
        Verifier verifier;
        IVerifier.VerificationPayload[] memory verificationPayloads;
        {
            IVerifier.VerificationPayload[] memory leaves = new IVerifier.VerificationPayload[](2);
            leaves[0] = IVerifier.VerificationPayload({
                verificationType: IVerifier.VerificationType.CUSTOM_VERIFIER,
                verificationData: abi.encode(symbioticVerifier),
                proof: new bytes32[](0)
            });
            leaves[1] = IVerifier.VerificationPayload({
                verificationType: IVerifier.VerificationType.CUSTOM_VERIFIER,
                verificationData: abi.encode(erc20Verifier),
                proof: new bytes32[](0)
            });
            bytes32 merkleRoot;
            (merkleRoot, verificationPayloads) = generateMerkleProofs(leaves);
            verifier = Verifier($.verifierFactory.create(0, $.vaultProxyAdmin, abi.encode(address(vault), merkleRoot)));
            address subvault = vault.createSubvault(0, $.vaultProxyAdmin, address(verifier));

            address[] memory assets_ = new address[](1);
            assets_[0] = ASSET;
            vault.riskManager().setSubvaultLimit(subvault, int256(100 ether));
            vault.riskManager().allowSubvaultAssets(subvault, assets_);

            symbioticVerifier.grantRole(symbioticVerifier.MELLOW_VAULT_ROLE(), subvault);
        }
        vm.stopPrank();

        vm.startPrank($.user);
        {
            DepositQueue queue = DepositQueue(payable(vault.queueAt(ASSET, 0)));
            uint224 amount = 1 ether;
            deal(ASSET, $.user, amount);
            IERC20(ASSET).approve(address(queue), type(uint256).max);
            queue.deposit(amount, address(0), new bytes32[](0));
        }
        vm.stopPrank();

        {
            IOracle.SecurityParams memory securityParmas = Oracle(oracle).securityParams();
            skip(Math.max(securityParmas.depositInterval, securityParmas.timeout) + 1);
        }

        vm.startPrank($.vaultAdmin);
        {
            IOracle.Report[] memory reports = new IOracle.Report[](1);
            reports[0] = IOracle.Report({asset: ASSET, priceD18: 1 ether});
            Oracle(oracle).submitReports(reports);
        }
        vm.stopPrank();

        assertEq(vault.shareManager().sharesOf($.user), 1 ether);
        assertEq(IERC20(ASSET).balanceOf(address(vault)), 0);
        assertEq(IERC20(ASSET).balanceOf(address(vault.subvaultAt(0))), 1 ether);
        assertEq(IERC20(ASSET).balanceOf($.user), 0);

        vm.startPrank($.curator);
        {
            Subvault subvault = Subvault(payable(vault.subvaultAt(0)));
            subvault.call(
                ASSET,
                0,
                abi.encodeCall(IERC20.approve, (SYMBIOTIC_VAULT, type(uint256).max)),
                verificationPayloads[1] // erc20Verifier payload
            );
            subvault.call(
                SYMBIOTIC_VAULT,
                0,
                abi.encodeCall(ISymbioticVault.deposit, (address(subvault), 1 ether)),
                verificationPayloads[0] // symbioticVerifier payload
            );
        }
        vm.stopPrank();

        uint256 ratioD2 = 10; // slash symbiotic vault for 10%
        uint256 slashedRatioD18 = slashSymbioticVault(ratioD2);
        uint256 expectedSlashedValue = slashedRatioD18; // ratio*1e18/1e18

        assertEq(vault.shareManager().sharesOf($.user), 1 ether);
        assertEq(IERC20(ASSET).balanceOf(address(vault)), 0);
        assertEq(IERC20(ASSET).balanceOf(address(vault.subvaultAt(0))), 0);

        uint256 userRedeemTimestamp = block.timestamp;
        vm.startPrank($.user);
        {
            RedeemQueue queue = RedeemQueue(payable(vault.queueAt(ASSET, 1)));
            uint224 shares = uint224(vault.shareManager().sharesOf($.user));
            vm.expectRevert();
            queue.redeem(0);
            queue.redeem(shares / 2);
            queue.redeem(shares / 2);
        }
        vm.stopPrank();

        assertEq(RedeemQueue(payable(vault.queueAt(ASSET, 1))).requestsOf($.user, 0, 10).length, 1);

        vm.startPrank($.vaultAdmin);
        skip(20 hours);
        {
            RedeemQueue queue = RedeemQueue(payable(vault.queueAt(ASSET, 1)));
            vault.setQueueStatus(address(queue), true);
            vm.expectRevert();
            queue.redeem(1 ether);
            vault.setQueueStatus(address(queue), false);

            IOracle.Report[] memory reports = new IOracle.Report[](1);
            reports[0] = IOracle.Report({asset: ASSET, priceD18: 1 ether});
            Oracle(oracle).submitReports(reports);
        }
        vm.stopPrank();

        vm.startPrank($.vaultAdmin);
        skip(20 hours);
        {
            RedeemQueue queue = RedeemQueue(payable(vault.queueAt(ASSET, 1)));
            vault.setQueueStatus(address(queue), true);
            vm.expectRevert();
            queue.redeem(1 ether);
            vault.setQueueStatus(address(queue), false);

            IOracle.Report[] memory reports = new IOracle.Report[](1);
            reports[0] = IOracle.Report({asset: ASSET, priceD18: 1 ether});
            Oracle(oracle).submitReports(reports);
        }
        vm.stopPrank();

        assertEq(vault.shareManager().sharesOf($.user), 0);
        assertEq(IERC20(ASSET).balanceOf(address(vault)), 0);
        assertEq(IERC20(ASSET).balanceOf(address(vault.subvaultAt(0))), 0);

        vm.startPrank($.curator);
        uint256 currentEpoch = ISymbioticStorageVault(SYMBIOTIC_VAULT).currentEpoch();

        uint256 expectedRedeemAmount = 1 ether - expectedSlashedValue;
        expectedRedeemAmount -= vault.feeManager().calculateRedeemFee(expectedRedeemAmount);

        {
            Subvault subvault = Subvault(payable(vault.subvaultAt(0)));
            amountAfterSlashing = ISymbioticStorageVault(SYMBIOTIC_VAULT).activeBalanceOf(address(subvault));
            assertApproxEqAbs(amountAfterSlashing, 1 ether - expectedSlashedValue, 1 wei);
            subvault.call(
                SYMBIOTIC_VAULT,
                0,
                abi.encodeCall(ISymbioticVault.withdraw, (address(subvault), amountAfterSlashing)),
                verificationPayloads[0]
            );
        }
        vm.stopPrank();

        {
            IOracle.SecurityParams memory securityParmas = Oracle(oracle).securityParams();
            skip(Math.max(securityParmas.redeemInterval, securityParmas.timeout) + 1);
        }

        vm.startPrank($.curator);
        {
            Subvault subvault = Subvault(payable(vault.subvaultAt(0)));
            bytes memory response = subvault.call(
                SYMBIOTIC_VAULT,
                0,
                abi.encodeCall(ISymbioticVault.claim, (address(subvault), currentEpoch + 1)),
                verificationPayloads[0]
            );
            assertApproxEqAbs(abi.decode(response, (uint256)), amountAfterSlashing, 1 wei);
            amountAfterSlashing = abi.decode(response, (uint256));
        }
        vm.stopPrank();

        assertEq(vault.shareManager().sharesOf($.user), 0);
        assertEq(IERC20(ASSET).balanceOf(vault.queueAt(ASSET, 1)), 0);
        assertEq(IERC20(ASSET).balanceOf(address(vault)), 0);
        assertEq(IERC20(ASSET).balanceOf(address(vault.subvaultAt(0))), amountAfterSlashing);
        assertEq(IERC20(ASSET).balanceOf($.user), 0);

        vm.startPrank($.user);
        {
            uint32[] memory timestamps = new uint32[](1);
            timestamps[0] = uint32(userRedeemTimestamp);
            assertEq(0, RedeemQueue(payable(vault.queueAt(ASSET, 1))).claim($.user, timestamps));
        }
        vm.stopPrank();

        vm.startPrank($.vaultAdmin);
        {
            IOracle.Report[] memory reports = new IOracle.Report[](1);
            reports[0] = IOracle.Report({asset: ASSET, priceD18: uint224(1e36 / amountAfterSlashing)});

            vm.expectRevert();
            Oracle(oracle).submitReports(reports);
            securityParams.maxAbsoluteDeviation = 0.12 ether;
            securityParams.maxRelativeDeviationD18 = 0.12 ether;
            Oracle(oracle).setSecurityParams(securityParams);

            Oracle(oracle).submitReports(reports);
            Oracle(oracle).acceptReport(ASSET, reports[0].priceD18, uint32(block.timestamp));

            RedeemQueue queue = RedeemQueue(payable(vault.queueAt(ASSET, 1)));
            assertFalse(queue.canBeRemoved());

            skip(20 hours);
            Oracle(oracle).submitReports(reports);

            skip(20 hours);
            Oracle(oracle).submitReports(reports);
        }
        vm.stopPrank();

        assertEq(vault.shareManager().sharesOf($.user), 0);
        assertEq(IERC20(ASSET).balanceOf(vault.queueAt(ASSET, 1)), 0);
        assertEq(IERC20(ASSET).balanceOf(address(vault)), 0);
        assertEq(IERC20(ASSET).balanceOf(address(vault.subvaultAt(0))), amountAfterSlashing);
        assertEq(IERC20(ASSET).balanceOf($.user), 0);

        vm.startPrank($.user);
        {
            uint32[] memory timestamps = new uint32[](1);
            timestamps[0] = uint32(userRedeemTimestamp);
            assertEq(0, RedeemQueue(payable(vault.queueAt(ASSET, 1))).claim($.user, timestamps));
        }
        vm.stopPrank();

        assertEq(vault.shareManager().sharesOf($.user), 0);
        assertEq(IERC20(ASSET).balanceOf(vault.queueAt(ASSET, 1)), 0);
        assertEq(IERC20(ASSET).balanceOf(address(vault)), 0);
        assertEq(IERC20(ASSET).balanceOf(address(vault.subvaultAt(0))), amountAfterSlashing);
        assertEq(IERC20(ASSET).balanceOf($.user), 0);

        RedeemQueue redeemQueue = RedeemQueue(payable(vault.queueAt(ASSET, 1)));
        {
            uint256 x;
            uint256 y;
            {
                (uint256 batchIterator,,,) = redeemQueue.getState();
                (x, y) = redeemQueue.batchAt(batchIterator);
            }
            {
                assertEq(y, 1 ether - vault.feeManager().calculateRedeemFee(1 ether));
            }

            assertApproxEqAbs(x, expectedRedeemAmount, 2 wei);
            expectedRedeemAmount = x;
            assertFalse(redeemQueue.canBeRemoved());

            vm.startPrank($.vaultAdmin);
            vm.expectRevert();
            vault.removeQueue(address(redeemQueue));
            vm.stopPrank();
        }

        assertEq(0, redeemQueue.handleBatches(0));
        assertEq(1, redeemQueue.handleBatches(1));
        assertEq(0, redeemQueue.handleBatches(1));

        {
            (uint256 batchIterator,,,) = redeemQueue.getState();
            (uint256 x, uint256 y) = redeemQueue.batchAt(batchIterator);
            assertEq(x, 0);
            assertEq(y, 0);
            assertTrue(redeemQueue.canBeRemoved());
        }
        assertEq(vault.shareManager().sharesOf($.user), 0);
        assertEq(IERC20(ASSET).balanceOf(address(redeemQueue)), expectedRedeemAmount);
        assertEq(IERC20(ASSET).balanceOf(address(vault)), 0);
        assertEq(IERC20(ASSET).balanceOf(address(vault.subvaultAt(0))), amountAfterSlashing - expectedRedeemAmount);
        assertEq(IERC20(ASSET).balanceOf($.user), 0);

        vm.startPrank($.user);
        {
            IRedeemQueue.Request[] memory requests = redeemQueue.requestsOf($.user, 0, type(uint256).max);
            assertEq(requests.length, 1);
            assertEq(requests[0].timestamp, userRedeemTimestamp);
            assertEq(requests[0].isClaimable, true, "isClaimable");
            assertEq(requests[0].assets, expectedRedeemAmount, "assets");
            assertEq(requests[0].shares, 0.99 ether, "shares");
            uint32[] memory timestamps = new uint32[](1);
            timestamps[0] = type(uint32).max;
            assertEq(redeemQueue.claim($.user, timestamps), 0);
            timestamps[0] = uint32(userRedeemTimestamp) - 1;
            assertEq(redeemQueue.claim($.user, timestamps), 0);
            timestamps[0] = uint32(userRedeemTimestamp);
            assertEq(redeemQueue.claim($.user, timestamps), expectedRedeemAmount);
            assertEq(redeemQueue.requestsOf($.user, type(uint256).max, 0).length, 0);
        }
        vm.stopPrank();

        assertEq(vault.shareManager().sharesOf($.user), 0);
        assertEq(IERC20(ASSET).balanceOf(address(redeemQueue)), 0);
        assertEq(IERC20(ASSET).balanceOf(address(vault)), 0);
        assertEq(IERC20(ASSET).balanceOf(address(vault.subvaultAt(0))), amountAfterSlashing - expectedRedeemAmount);
        assertEq(IERC20(ASSET).balanceOf($.user), expectedRedeemAmount);

        vm.startPrank($.user);
        {
            DepositQueue queue = DepositQueue(payable(vault.queueAt(ASSET, 0)));
            uint224 amount = 1 ether;
            deal(ASSET, $.user, amount);
            IERC20(ASSET).approve(address(queue), type(uint256).max);
            queue.deposit(amount, address(0), new bytes32[](0));
        }
        vm.stopPrank();

        vm.startPrank($.vaultAdmin);
        {
            IOracle.Report[] memory reports = new IOracle.Report[](1);
            reports[0] = IOracle.Report({asset: ASSET, priceD18: uint224(1e36 / amountAfterSlashing)});

            skip(20 hours);
            Oracle(oracle).submitReports(reports);
        }
        vm.stopPrank();

        vm.startPrank($.user);
        {
            redeemQueue.redeem(vault.shareManager().sharesOf($.user));
        }
        vm.stopPrank();

        vm.startPrank($.vaultAdmin);
        for (uint256 i = 0; i < 30; i++) {
            IOracle.Report[] memory reports = new IOracle.Report[](1);
            reports[0] = IOracle.Report({asset: ASSET, priceD18: uint224(1e36 / amountAfterSlashing)});

            skip(20 hours);
            Oracle(oracle).submitReports(reports);
        }
        vm.stopPrank();

        {
            (uint256 batchIterator,, uint256 demandAssets, uint256 pendingShares) = redeemQueue.getState();
            assertEq(pendingShares, 1099777681625627299, "pending shares");
            assertEq(demandAssets, 0.99 ether, "required assets");
            {
                (uint256 batchAssets, uint256 batchShares) = redeemQueue.batchAt(batchIterator);
                assertEq(batchAssets, 0.99 ether);
                assertEq(batchShares, 1099777681625627299);
            }

            assertFalse(redeemQueue.canBeRemoved());
            assertEq(1, redeemQueue.handleBatches(1));

            (,, demandAssets, pendingShares) = redeemQueue.getState();

            assertEq(pendingShares, 0, "pending shares");
            assertEq(demandAssets, 0, "required assets");

            assertTrue(redeemQueue.canBeRemoved());

            vm.startPrank($.vaultAdmin);
            vault.removeQueue(address(redeemQueue));
            vm.stopPrank();
        }
    }

    function slashSymbioticVault(uint256 ratioD2) public returns (uint256 slashedActiveStakeRatioD18) {
        ISymbioticSlasher slasher = ISymbioticSlasher(0x295F8c41eA17B330853AC74D1477a6F83B36ee31);
        address network = 0x83742C346E9f305dcA94e20915aB49A483d33f3E;
        address operator = 0x087c25f83ED20bda587CFA035ED0c96338D4660f;
        bytes32 subnetwork = bytes32(uint256(uint160(network)) << 96);
        vm.startPrank(network);
        uint256 activeStake = ISymbioticStorageVault(SYMBIOTIC_VAULT).activeStake();
        uint256 slashIndex = slasher.requestSlash(
            subnetwork, operator, activeStake * ratioD2 / 100, uint48(block.timestamp) - 1, new bytes(0)
        );
        slasher.executeSlash(slashIndex, new bytes(0));
        uint256 activeStakeAfter = ISymbioticStorageVault(SYMBIOTIC_VAULT).activeStake();
        vm.stopPrank();

        slashedActiveStakeRatioD18 = Math.mulDiv(activeStake - activeStakeAfter, 1 ether, activeStake);
    }
}

interface ISymbioticSlasher {
    function requestSlash(
        bytes32 subnetwork,
        address operator,
        uint256 amount,
        uint48 captureTimestamp,
        bytes calldata hints
    ) external returns (uint256 slashIndex);

    function executeSlash(uint256 slashIndex, bytes calldata hints) external returns (uint256 slashedAmount);
}
