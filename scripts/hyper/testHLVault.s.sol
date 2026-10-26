// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../common/interfaces/ICowswapSettlement.sol";
import {IWETH as WETHInterface} from "../common/interfaces/IWETH.sol";
import {IWSTETH as WSTETHInterface} from "../common/interfaces/IWSTETH.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "../../src/oracles/OracleSubmitter.sol";
import "../../src/vaults/Subvault.sol";
import "../../src/vaults/VaultConfigurator.sol";

import "../common/AcceptanceLibrary.sol";
import "../common/Permissions.sol";
import "../common/ProofLibrary.sol";
import "forge-std/Script.sol";
import "forge-std/Test.sol";

import "../common/ArraysLibrary.sol";
import "../common/interfaces/IAggregatorV3.sol";
import "./Constants.sol";

contract Deploy is Script, Test {
    // Actors

    address public constant testActor = 0x38892Fc08D9891c144ddB36e48a47Dee0D821965;

    address public proxyAdmin = testActor;
    address public lazyVaultAdmin = testActor;
    address public activeVaultAdmin = testActor;
    address public curator = testActor;

    address public oracleUpdater = testActor;
    address public oracleAccepter = testActor;
    address public treasury = testActor;

    uint256 public constant DEFAULT_PENALTY_D6 = 0; // earnUSD is the only depositor
    uint32 public constant DEFAULT_MAX_AGE = 24 hours;
    uint256 public constant DEFAULT_MULTIPLIER = 0.995e8;

    string public name = "test Hyperliquid Vault";
    string public symbol = "tHV";

    address[] assets_ = ArraysLibrary.makeAddressArray(abi.encode(Constants.USDC));

    address[] verifiers = new address[](1);

    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);

        vm.startBroadcast(deployerPk);

        if (true) {
            _acceptReports(OracleSubmitter(0x7725788fCBD3B7ff2eCE3CceD27e26CFEA275f3C), deployer);
            return;
        }

        Vault.RoleHolder[] memory holders = new Vault.RoleHolder[](42);


        console.log("------------------------------------");
        console.log("%s (%s)", name, symbol);
        console.log("------------------------------------");
        console.log("Actors:");
        console.log("------------------------------------");
        console.log("Test", testActor);
        curator = Constants.protocolDeployment().accountFactory.create(0, proxyAdmin, abi.encode(curator));

        console.log("------------------------------------");
        console.log("Addresses:");
        console.log("------------------------------------");

        {
            uint256 i = 0;

            // activeVaultAdmin roles:
            holders[i++] = Vault.RoleHolder(Permissions.SET_VAULT_LIMIT_ROLE, activeVaultAdmin);
            holders[i++] = Vault.RoleHolder(Permissions.SET_SUBVAULT_LIMIT_ROLE, activeVaultAdmin);
            holders[i++] = Vault.RoleHolder(Permissions.ALLOW_SUBVAULT_ASSETS_ROLE, activeVaultAdmin);
            holders[i++] = Vault.RoleHolder(Permissions.MODIFY_VAULT_BALANCE_ROLE, activeVaultAdmin);
            holders[i++] = Vault.RoleHolder(Permissions.MODIFY_SUBVAULT_BALANCE_ROLE, activeVaultAdmin);

            // curator roles:
            holders[i++] = Vault.RoleHolder(Permissions.CALLER_ROLE, curator);
            holders[i++] = Vault.RoleHolder(Permissions.PULL_LIQUIDITY_ROLE, curator);
            holders[i++] = Vault.RoleHolder(Permissions.PUSH_LIQUIDITY_ROLE, curator);

            // deployer roles:
            holders[i++] = Vault.RoleHolder(Permissions.DEFAULT_ADMIN_ROLE, deployer);
            holders[i++] = Vault.RoleHolder(Permissions.CREATE_SUBVAULT_ROLE, deployer);
            holders[i++] = Vault.RoleHolder(Permissions.CREATE_QUEUE_ROLE, deployer);
            holders[i++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, deployer);
            holders[i++] = Vault.RoleHolder(Permissions.ALLOW_SUBVAULT_ASSETS_ROLE, deployer);
            holders[i++] = Vault.RoleHolder(Permissions.SET_SUBVAULT_LIMIT_ROLE, deployer);

            assembly {
                mstore(holders, i)
            }
        }

        ProtocolDeployment memory $ = Constants.protocolDeployment();
        VaultConfigurator.InitParams memory initParams = VaultConfigurator.InitParams({
            version: 0,
            proxyAdmin: proxyAdmin,
            vaultAdmin: lazyVaultAdmin,
            shareManagerVersion: 0,
            shareManagerParams: abi.encode(bytes32(0), name, symbol),
            feeManagerVersion: 0,
            feeManagerParams: abi.encode(deployer, treasury, uint24(0), uint24(0), uint24(0), uint24(0)),
            riskManagerVersion: 0,
            riskManagerParams: abi.encode(type(int256).max / 2),
            oracleVersion: 0,
            oracleParams: abi.encode(
                IOracle.SecurityParams({
                    maxAbsoluteDeviation: 0.005e30,
                    suspiciousAbsoluteDeviation: 0.001e30,
                    maxRelativeDeviationD18: 0.005 ether,
                    suspiciousRelativeDeviationD18: 0.001 ether,
                    timeout: 15 minutes,
                    depositInterval: 1 seconds,
                    redeemInterval: 1 seconds
                }),
                assets_
            ),
            defaultDepositHook: address($.redirectingDepositHook),
            defaultRedeemHook: address($.basicRedeemHook),
            queueLimit: 2,
            roleHolders: holders
        });

        Vault vault;
        {
            (,,,, address vault_) = $.vaultConfigurator.create(initParams);
            vault = Vault(payable(vault_));
        }

        vault.feeManager().setBaseAsset(address(vault), Constants.USDC);
        Ownable(address(vault.feeManager())).transferOwnership(lazyVaultAdmin);

        // queue setup

        // uint256 version, bool isDeposit, address owner, address asset, bytes calldata data
        vault.createQueue(2, true, testActor, Constants.USDC, abi.encode(DEFAULT_PENALTY_D6, DEFAULT_MAX_AGE));
        vault.createQueue(2, false, testActor, Constants.USDC, abi.encode(DEFAULT_PENALTY_D6, DEFAULT_MAX_AGE, 1000e18 days));

        // subvault setup

        SubvaultCalls[] memory calls = new SubvaultCalls[](verifiers.length);

        {
            IRiskManager riskManager = vault.riskManager();
            {
                uint256 subvaultIndex = 0;
                verifiers[subvaultIndex] = $.verifierFactory.create(0, proxyAdmin, abi.encode(vault, bytes32(0)));
                address subvault = vault.createSubvault(0, proxyAdmin, verifiers[subvaultIndex]);

                console.log("Subvault 0:", subvault);
                console.log("Verifier 0:", verifiers[0]);

                riskManager.allowSubvaultAssets(subvault, ArraysLibrary.makeAddressArray(abi.encode(Constants.USDC)));
                riskManager.setSubvaultLimit(subvault, type(int256).max / 2);
            }
        }
        console.log("Vault %s", address(vault));

        for (uint256 i = 0; i < vault.getAssetCount(); i++) {
            address asset = vault.assetAt(i);
            string memory symbol_ = asset == Constants.HYPE ? "HYPE" : IERC20Metadata(asset).symbol();
            for (uint256 j = 0; j < vault.getQueueCount(asset); j++) {
                address queue = vault.queueAt(asset, j);
                if (vault.isDepositQueue(queue)) {
                    try SyncDepositQueue(queue).name() returns (string memory) {
                        console.log("SyncDepositQueue (%s): %s", symbol_, queue);
                    } catch {
                        console.log("DepositQueue (%s): %s", symbol_, queue);
                    }
                } else {
                    console.log("RedeemQueue (%s): %s", symbol_, queue);
                }
            }
        }

        console.log("Oracle %s", address(vault.oracle()));
        console.log("ShareManager %s", address(vault.shareManager()));
        console.log("FeeManager %s", address(vault.feeManager()));
        console.log("RiskManager %s", address(vault.riskManager()));

        for (uint256 i = 0; i < vault.subvaults(); i++) {
            address subvault = vault.subvaultAt(i);
            console.log("Subvault %s %s", i, subvault);
            console.log("Verifier %s %s", i, address(Subvault(payable(subvault)).verifier()));
        }

        OracleSubmitter oracleSubmitter =
            new OracleSubmitter(deployer, oracleUpdater, oracleAccepter, address(vault.oracle()));
        oracleSubmitter.grantRole(Permissions.DEFAULT_ADMIN_ROLE, lazyVaultAdmin);
        oracleSubmitter.grantRole(Permissions.SUBMIT_REPORTS_ROLE, deployer);
        oracleSubmitter.grantRole(Permissions.ACCEPT_REPORT_ROLE, deployer);
        oracleSubmitter.renounceRole(Permissions.DEFAULT_ADMIN_ROLE, deployer);
        vault.grantRole(Permissions.SUBMIT_REPORTS_ROLE, address(oracleSubmitter));
        vault.grantRole(Permissions.ACCEPT_REPORT_ROLE, address(oracleSubmitter));
        vault.renounceRole(Permissions.DEFAULT_ADMIN_ROLE, deployer);

        console.log("OracleSubmitter: %s", address(oracleSubmitter));

        {
            IOracle.Report[] memory reports = new IOracle.Report[](assets_.length);
            for (uint256 i = 0; i < reports.length; i++) {
                address asset = assets_[i];
                reports[i].asset = asset;
                uint256 priceD8 = 1e8;
                reports[i].priceD18 = uint224(priceD8 * 10 ** (28 - IERC20Metadata(asset).decimals()));
                console.log("Reported price for asset: %s %s", IERC20Metadata(asset).symbol(), reports[i].priceD18);
            }
            oracleSubmitter.submitReports(reports);
        }

        // _acceptReports(oracleSubmitter, deployer);

        // vm.stopBroadcast();

        // AcceptanceLibrary.runProtocolDeploymentChecks(Constants.protocolDeployment());

        // revert("ok");
    }

    function _acceptReports(OracleSubmitter oracleSubmitter, address deployer) internal {
        IOracle oracle = oracleSubmitter.oracle();
        uint256 n = oracle.supportedAssets();
        address[] memory assets = new address[](n);
        uint32[] memory timestamps = new uint32[](n);
        uint224[] memory prices = new uint224[](n);
        for (uint256 i = 0; i < n; i++) {
            address a = oracle.supportedAssetAt(i);
            IOracle.DetailedReport memory r = oracle.getReport(a);
            assets[i] = a;
            timestamps[i] = r.timestamp;
            prices[i] = r.priceD18;
        }
        oracleSubmitter.acceptReports(assets, prices, timestamps);
        oracleSubmitter.renounceRole(Permissions.SUBMIT_REPORTS_ROLE, deployer);
        oracleSubmitter.renounceRole(Permissions.ACCEPT_REPORT_ROLE, deployer);
    }
 
}
