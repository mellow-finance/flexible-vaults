// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../Imports.sol";
import "./BaseIntegrationTest.sol";

contract IntegrationTest is BaseIntegrationTest {
    address public constant ASSET = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

    Deployment private $;

    function setUp() external {
        $ = deployBase();
    }

    Vault vault;

    function testProtocolFees() external {
        IOracle.SecurityParams memory securityParams = IOracle.SecurityParams({
            maxAbsoluteDeviation: 0.01 ether, // 1% abs
            suspiciousAbsoluteDeviation: 0.005 ether, // 0.05% abs
            maxRelativeDeviationD18: 0.01 ether, // 1% abs
            suspiciousRelativeDeviationD18: 0.005 ether, // 0.05% abs
            timeout: 20 hours,
            depositInterval: 1 hours,
            redeemInterval: 1 hours
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

        vault = Vault(payable(vault_));

        vm.startPrank($.vaultAdmin);
        IFeeManager feeManager = vault.feeManager();
        IShareManager shareManager = vault.shareManager();

        feeManager.setBaseAsset(address(vault), ASSET);
        feeManager.setFees(0, 0, 0, 1e4);
        vault.createQueue(0, true, $.vaultProxyAdmin, ASSET, new bytes(0));
        vault.createQueue(0, false, $.vaultProxyAdmin, ASSET, new bytes(0));

        DepositQueue depositQueue = DepositQueue(payable(vault.queueAt(ASSET, 0)));
        RedeemQueue redeemQueue = RedeemQueue(payable(vault.queueAt(ASSET, 1)));

        IOracle.Report[] memory reports = new IOracle.Report[](1);
        reports[0] = IOracle.Report({asset: ASSET, priceD18: 1 ether});
        {
            Oracle(oracle).submitReports(reports);
            Oracle(oracle).acceptReport(ASSET, 1 ether, uint32(block.timestamp));
        }

        assertEq(shareManager.totalShares(), 0 ether);

        vm.stopPrank();
        vm.startPrank($.user);

        {
            uint224 amount = 1 ether;
            deal(ASSET, $.user, amount);
            IERC20(ASSET).approve(address(depositQueue), type(uint256).max);
            depositQueue.deposit(amount, address(0), new bytes32[](0));
        }

        vm.stopPrank();
        vm.startPrank($.vaultAdmin);

        {
            skip(20 hours);
            adjustPrice(reports[0]);
            Oracle(oracle).submitReports(reports);
        }

        assertEq(shareManager.totalShares(), 1 ether, "20 hours");
        uint256 shares = shareManager.totalShares();

        {
            skip(20 hours);
            adjustPrice(reports[0]);
            Oracle(oracle).submitReports(reports);
        }

        assertEq(shareManager.totalShares(), (shares * 1e4 * 20 hours / 365e6 days) + shares, "40 hours");
        shares = shareManager.totalShares();

        {
            skip(50 hours);
            adjustPrice(reports[0]);
            Oracle(oracle).submitReports(reports);
        }

        assertEq(shareManager.totalShares(), (shares * 1e4 * 50 hours / 365e6 days) + shares, "90 hours");
        shares = shareManager.totalShares();

        {
            skip(1000 hours);
            adjustPrice(reports[0]);
            Oracle(oracle).submitReports(reports);
            feeManager.setFees(0, 0, 0, 0);
        }

        assertEq(shareManager.totalShares(), (shares * 1e4 * 1000 hours / 365e6 days) + shares, "1090 hours");
        shares = shareManager.totalShares();
        {
            skip(1000 hours);
            adjustPrice(reports[0]);
            Oracle(oracle).submitReports(reports);
        }
        assertEq(shareManager.totalShares(), shares, "2090 hours");

        uint256 totalAssets = IERC20(ASSET).balanceOf(address(vault));
        uint256 totalShares = shareManager.totalShares();

        assertEq(Math.mulDiv(totalShares, 1 ether, totalAssets), reports[0].priceD18);

        vm.stopPrank();

        uint256 userShares = shareManager.sharesOf($.user);
        uint256 protocolTreasuryShares = shareManager.sharesOf($.protocolTreasury);

        vm.startPrank($.user);
        redeemQueue.redeem(userShares);
        vm.stopPrank();
        vm.startPrank($.protocolTreasury);
        redeemQueue.redeem(protocolTreasuryShares);
        vm.stopPrank();

        vm.startPrank($.vaultAdmin);
        {
            skip(20 hours);
            Oracle(oracle).submitReports(reports);
        }
        vm.stopPrank();

        redeemQueue.handleBatches(1);

        uint32[] memory timestamps = new uint32[](1);
        timestamps[0] = uint32(block.timestamp - 20 hours);
        vm.prank($.user);
        redeemQueue.claim($.user, timestamps);
        vm.prank($.protocolTreasury);
        redeemQueue.claim($.protocolTreasury, timestamps);

        assertEq(IERC20(ASSET).balanceOf($.user) + IERC20(ASSET).balanceOf($.protocolTreasury), 1 ether);
        assertEq(
            IERC20(ASSET).balanceOf($.protocolTreasury),
            Math.mulDiv(1 ether, protocolTreasuryShares, protocolTreasuryShares + userShares, Math.Rounding.Ceil)
        );
    }

    function adjustPrice(IOracle.Report memory report) public view {
        if (vault.shareManager().totalShares() != 0) {
            report.priceD18 +=
                uint224(vault.feeManager().calculateFee(address(vault), ASSET, report.priceD18, report.priceD18));
        }
    }
}
