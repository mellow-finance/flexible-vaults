// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../Imports.sol";
import "./BaseIntegrationTest.sol";

interface ISymbioticStorageVault {
    function setDepositWhitelist(bool status) external;
    function setDepositLimit(uint256 limit) external;
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
            depositSecureInterval: 1 hours,
            redeemSecureInterval: 1 hours
        });

        address[] memory assets = new address[](1);
        assets[0] = ASSET;

        Vault.RoleHolder[] memory holders = new Vault.RoleHolder[](9);

        Vault vaultImplementation = Vault(payable($.vaultFactory.implementationAt(0)));
        Oracle oracleImplementation = Oracle($.oracleFactory.implementationAt(0));

        holders[0] = Vault.RoleHolder(false, vaultImplementation.CREATE_DEPOSIT_QUEUE_ROLE(), $.vaultAdmin);
        holders[1] = Vault.RoleHolder(false, vaultImplementation.CREATE_REDEEM_QUEUE_ROLE(), $.vaultAdmin);
        holders[2] = Vault.RoleHolder(false, oracleImplementation.SUBMIT_REPORTS_ROLE(), $.vaultAdmin);
        holders[3] = Vault.RoleHolder(false, oracleImplementation.ACCEPT_REPORT_ROLE(), $.vaultAdmin);
        holders[4] = Vault.RoleHolder(true, bytes32(uint256(IACLModule.FundamentalRole.PROXY_OWNER)), $.vaultProxyAdmin);
        holders[5] = Vault.RoleHolder(false, vaultImplementation.CREATE_SUBVAULT_ROLE(), $.vaultAdmin);
        holders[6] = Vault.RoleHolder(false, Verifier($.verifierFactory.implementationAt(0)).CALL_ROLE(), $.curator);
        holders[7] = Vault.RoleHolder(
            false, RiskManager($.riskManagerFactory.implementationAt(0)).SET_SUBVAULT_LIMIT_ROLE(), $.vaultAdmin
        );
        holders[8] = Vault.RoleHolder(
            false, RiskManager($.riskManagerFactory.implementationAt(0)).ALLOW_SUBVAULT_ASSETS_ROLE(), $.vaultAdmin
        );

        (address shareManager, address feeManager, address riskManager, address oracle, address vault_) = $
            .vaultConfigurator
            .create(
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
                roleHolders: holders
            })
        );
        Vault vault = Vault(payable(vault_));

        assertTrue($.vaultConfigurator.isEntity(vault_));
        assertEq($.vaultConfigurator.entities(), 1);
        assertEq($.vaultConfigurator.entityAt(0), vault_);

        vm.startPrank($.vaultAdmin);
        vault.createDepositQueue(0, $.vaultProxyAdmin, ASSET, new bytes(0));
        vault.createRedeemQueue(0, $.vaultProxyAdmin, ASSET, new bytes(0));
        {
            IOracle.Report[] memory reports = new IOracle.Report[](1);
            reports[0] = IOracle.Report({asset: ASSET, priceD18: 1 ether});
            Oracle(oracle).submitReports(reports);
            Oracle(oracle).acceptReport(ASSET, uint32(block.timestamp));
        }
        SymbioticVerifier symbioticVerifier;
        {
            address[] memory holders = new address[](3);
            bytes32[] memory roles = new bytes32[](holders.length);

            SymbioticVerifier symbioticVerifierImplementation =
                SymbioticVerifier($.protocolVerifierFactory.implementationAt(0));

            holders[0] = $.curator;
            roles[0] = symbioticVerifierImplementation.CALLER_ROLE();

            holders[1] = address(vault);
            roles[1] = symbioticVerifierImplementation.MELLOW_VAULT_ROLE();

            holders[2] = SYMBIOTIC_VAULT;
            roles[2] = symbioticVerifierImplementation.SYMBIOTIC_VAULT_ROLE();
            symbioticVerifier = SymbioticVerifier(
                $.protocolVerifierFactory.create(0, $.vaultProxyAdmin, abi.encode($.vaultAdmin, holders, roles))
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

            address[] memory assets = new address[](1);
            assets[0] = ASSET;
            vault.riskManager().setSubvaultLimit(subvault, int256(100 ether));
            vault.riskManager().allowSubvaultAssets(subvault, assets);
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
            skip(Math.max(securityParmas.depositSecureInterval, securityParmas.timeout) + 1);
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
                abi.encodeCall(ISymbioticVault.deposit, (address(vault), 1 ether)),
                verificationPayloads[0] // symbioticVerifier payload
            );
        }
        vm.stopPrank();

        assertEq(vault.shareManager().sharesOf($.user), 1 ether);
        assertEq(IERC20(ASSET).balanceOf(address(vault)), 0);
        assertEq(IERC20(ASSET).balanceOf(address(vault.subvaultAt(0))), 0);

        vm.startPrank($.user);
        {
            DepositQueue queue = DepositQueue(payable(vault.queueAt(ASSET, 0)));
            uint224 amount = 1 ether;
            deal(ASSET, $.user, amount);
            IERC20(ASSET).approve(address(queue), type(uint256).max);
            queue.deposit(amount, address(0), new bytes32[](0));
        }
        vm.stopPrank();
    }
}
