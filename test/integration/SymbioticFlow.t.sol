// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../Imports.sol";
import "./BaseIntegrationTest.sol";

interface ISymbioticStorageVault {
    function setDepositWhitelist(bool status) external;
    function setDepositLimit(uint256 limit) external;
    function currentEpoch() external view returns (uint256);
    function activeBalanceOf(address user) external view returns (uint256);
}

contract SymbioticIntegrationTest is BaseIntegrationTest {
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

    function testSymbioticFlow() external {
        IOracle.SecurityParams memory securityParams = IOracle.SecurityParams({
            maxAbsoluteDeviation: 0.01 ether, // 1% abs
            suspiciousAbsoluteDeviation: 0.005 ether, // 0.05% abs
            maxRelativeDeviationD18: 0.01 ether, // 1% abs
            suspiciousRelativeDeviationD18: 0.005 ether, // 0.05% abs
            timeout: 20 hours,
            depositInterval: 1 hours,
            redeemInterval: 14 days
        });

        address[] memory assets = new address[](1);
        assets[0] = ASSET;

        Vault.RoleHolder[] memory roleHolders = new Vault.RoleHolder[](7);

        Vault vaultImplementation = Vault(payable($.vaultFactory.implementationAt(0)));
        Oracle oracleImplementation = Oracle($.oracleFactory.implementationAt(0));

        roleHolders[0] = Vault.RoleHolder(vaultImplementation.CREATE_QUEUE_ROLE(), $.vaultAdmin);
        roleHolders[1] = Vault.RoleHolder(oracleImplementation.SUBMIT_REPORTS_ROLE(), $.vaultAdmin);
        roleHolders[2] = Vault.RoleHolder(oracleImplementation.ACCEPT_REPORT_ROLE(), $.vaultAdmin);
        roleHolders[3] = Vault.RoleHolder(vaultImplementation.CREATE_SUBVAULT_ROLE(), $.vaultAdmin);
        roleHolders[4] = Vault.RoleHolder(Verifier($.verifierFactory.implementationAt(0)).CALLER_ROLE(), $.curator);
        roleHolders[5] = Vault.RoleHolder(
            RiskManager($.riskManagerFactory.implementationAt(0)).SET_SUBVAULT_LIMIT_ROLE(), $.vaultAdmin
        );
        roleHolders[6] = Vault.RoleHolder(
            RiskManager($.riskManagerFactory.implementationAt(0)).ALLOW_SUBVAULT_ASSETS_ROLE(), $.vaultAdmin
        );

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
                roleHolders: roleHolders
            })
        );

        Vault vault = Vault(payable(vault_));

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

        assertEq(vault.shareManager().sharesOf($.user), 1 ether);
        assertEq(IERC20(ASSET).balanceOf(address(vault)), 0);
        assertEq(IERC20(ASSET).balanceOf(address(vault.subvaultAt(0))), 0);

        uint256 userRedeemTimestamp = block.timestamp;
        vm.startPrank($.user);
        {
            RedeemQueue queue = RedeemQueue(payable(vault.queueAt(ASSET, 1)));
            uint224 shares = uint224(vault.shareManager().sharesOf($.user));
            queue.redeem(shares);
        }
        vm.stopPrank();

        assertEq(vault.shareManager().sharesOf($.user), 0);
        assertEq(IERC20(ASSET).balanceOf(address(vault)), 0);
        assertEq(IERC20(ASSET).balanceOf(address(vault.subvaultAt(0))), 0);

        vm.startPrank($.curator);
        uint256 currentEpoch = ISymbioticStorageVault(SYMBIOTIC_VAULT).currentEpoch();
        {
            Subvault subvault = Subvault(payable(vault.subvaultAt(0)));
            uint256 balance = ISymbioticStorageVault(SYMBIOTIC_VAULT).activeBalanceOf(address(subvault));
            subvault.call(
                SYMBIOTIC_VAULT,
                0,
                abi.encodeCall(ISymbioticVault.withdraw, (address(subvault), balance)),
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
            assertEq(abi.decode(response, (uint256)), 1 ether);
        }
        vm.stopPrank();

        assertEq(vault.shareManager().sharesOf($.user), 0);
        assertEq(IERC20(ASSET).balanceOf(vault.queueAt(ASSET, 1)), 0);
        assertEq(IERC20(ASSET).balanceOf(address(vault)), 0);
        assertEq(IERC20(ASSET).balanceOf(address(vault.subvaultAt(0))), 1 ether);
        assertEq(IERC20(ASSET).balanceOf($.user), 0);

        vm.startPrank($.vaultAdmin);
        {
            IOracle.Report[] memory reports = new IOracle.Report[](1);
            reports[0] = IOracle.Report({asset: ASSET, priceD18: 1 ether});
            Oracle(oracle).submitReports(reports);
        }
        vm.stopPrank();

        assertEq(vault.shareManager().sharesOf($.user), 0);
        assertEq(IERC20(ASSET).balanceOf(vault.queueAt(ASSET, 1)), 0);
        assertEq(IERC20(ASSET).balanceOf(address(vault)), 0);
        assertEq(IERC20(ASSET).balanceOf(address(vault.subvaultAt(0))), 1 ether);
        assertEq(IERC20(ASSET).balanceOf($.user), 0);

        vm.startPrank($.user);
        {
            uint32[] memory timestamps = new uint32[](1);
            timestamps[0] = uint32(userRedeemTimestamp);
            RedeemQueue(payable(vault.queueAt(ASSET, 1))).claim($.user, timestamps);
        }
        vm.stopPrank();

        assertEq(vault.shareManager().sharesOf($.user), 0);
        assertEq(IERC20(ASSET).balanceOf(vault.queueAt(ASSET, 1)), 0);
        assertEq(IERC20(ASSET).balanceOf(address(vault)), 0);
        assertEq(IERC20(ASSET).balanceOf(address(vault.subvaultAt(0))), 1 ether);
        assertEq(IERC20(ASSET).balanceOf($.user), 0);

        {
            RedeemQueue queue = RedeemQueue(payable(vault.queueAt(ASSET, 1)));
            (uint256 batchIterator,,,) = queue.getState();
            (uint256 x, uint256 y) = queue.batchAt(batchIterator);
            assertEq(x, 1 ether);
            assertEq(y, 1 ether);
        }
        RedeemQueue(payable(vault.queueAt(ASSET, 1))).handleBatches(1);

        {
            RedeemQueue queue = RedeemQueue(payable(vault.queueAt(ASSET, 1)));
            (uint256 batchIterator,,,) = queue.getState();
            (uint256 x, uint256 y) = queue.batchAt(batchIterator);
            assertEq(x, 0);
            assertEq(y, 0);
        }
        assertEq(vault.shareManager().sharesOf($.user), 0);
        assertEq(IERC20(ASSET).balanceOf(vault.queueAt(ASSET, 1)), 1 ether);
        assertEq(IERC20(ASSET).balanceOf(address(vault)), 0);
        assertEq(IERC20(ASSET).balanceOf(address(vault.subvaultAt(0))), 0);
        assertEq(IERC20(ASSET).balanceOf($.user), 0);

        vm.startPrank($.user);
        {
            uint32[] memory timestamps = new uint32[](1);
            timestamps[0] = uint32(userRedeemTimestamp);
            RedeemQueue queue = RedeemQueue(payable(vault.queueAt(ASSET, 1)));
            IRedeemQueue.Request[] memory requests = queue.requestsOf($.user, 0, type(uint256).max);
            assertEq(requests.length, 1);
            assertEq(requests[0].timestamp, userRedeemTimestamp);
            assertEq(requests[0].isClaimable, true, "isClaimable");
            assertEq(requests[0].assets, 1 ether, "assets");
            assertEq(requests[0].shares, 1 ether, "shares");
            RedeemQueue(payable(vault.queueAt(ASSET, 1))).claim($.user, timestamps);
        }
        vm.stopPrank();

        assertEq(vault.shareManager().sharesOf($.user), 0);
        assertEq(IERC20(ASSET).balanceOf(vault.queueAt(ASSET, 1)), 0);
        assertEq(IERC20(ASSET).balanceOf(address(vault)), 0);
        assertEq(IERC20(ASSET).balanceOf(address(vault.subvaultAt(0))), 0);
        assertEq(IERC20(ASSET).balanceOf($.user), 1 ether);
    }
}
