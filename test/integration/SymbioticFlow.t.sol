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
            secureInterval: 1 hours
        });

        address[] memory assets = new address[](1);
        assets[0] = ASSET;

        Vault.RoleHolder[] memory holders = new Vault.RoleHolder[](6);

        Vault vaultImplementation = Vault(payable($.vaultFactory.implementationAt(0)));
        Oracle oracleImplementation = Oracle($.oracleFactory.implementationAt(0));

        holders[0] = Vault.RoleHolder(false, vaultImplementation.CREATE_DEPOSIT_QUEUE_ROLE(), $.vaultAdmin);
        holders[1] = Vault.RoleHolder(false, vaultImplementation.CREATE_REDEEM_QUEUE_ROLE(), $.vaultAdmin);
        holders[2] = Vault.RoleHolder(false, oracleImplementation.SUBMIT_REPORTS_ROLE(), $.vaultAdmin);
        holders[3] = Vault.RoleHolder(false, oracleImplementation.ACCEPT_REPORT_ROLE(), $.vaultAdmin);
        holders[4] = Vault.RoleHolder(true, bytes32(uint256(IACLModule.FundamentalRole.PROXY_OWNER)), $.vaultProxyAdmin);
        holders[5] = Vault.RoleHolder(false, vaultImplementation.CREATE_SUBVAULT_ROLE(), $.vaultAdmin);

        (address shareManager, address feeManager, address riskManager, address oracle, address vault) = $
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
                defaultDepositHook: address(0),
                defaultRedeemHook: address(0),
                queueLimit: 0,
                roleHolders: holders,
                salt: bytes32(0)
            })
        );

        assertTrue($.vaultConfigurator.isEntity(vault));
        assertEq($.vaultConfigurator.entities(), 1);
        assertEq($.vaultConfigurator.entityAt(0), vault);
    }
}
