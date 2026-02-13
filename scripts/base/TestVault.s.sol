// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../common/interfaces/ICowswapSettlement.sol";
import {IWETH as WETHInterface} from "../common/interfaces/IWETH.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";

import "../../src/vaults/Subvault.sol";
import "../../src/vaults/VaultConfigurator.sol";

import "../common/AcceptanceLibrary.sol";
import "../common/Permissions.sol";
import "../common/ProofLibrary.sol";
import "forge-std/Script.sol";
import "forge-std/Test.sol";

import "./Constants.sol";

import "../common/ArraysLibrary.sol";

contract Deploy is Script, Test {
    // Actors
    address public testMultisig = 0xe469E9BCF4A9A2D7d9Ca9dAa5f6D168a94f1a4F9;
    string public vaultSymbol = "CB-TV";
    string public vaultName = "Mellow Test Vault";

    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);

        vm.startBroadcast(deployerPk);

        Vault.RoleHolder[] memory holders = new Vault.RoleHolder[](42);
        {
            uint256 i = 0;

            holders[i++] = Vault.RoleHolder(Permissions.ACCEPT_REPORT_ROLE, testMultisig);
            holders[i++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, testMultisig);
            holders[i++] = Vault.RoleHolder(Permissions.SUBMIT_REPORTS_ROLE, testMultisig);
            holders[i++] = Vault.RoleHolder(Permissions.CALLER_ROLE, testMultisig);
            holders[i++] = Vault.RoleHolder(Permissions.PULL_LIQUIDITY_ROLE, testMultisig);
            holders[i++] = Vault.RoleHolder(Permissions.PUSH_LIQUIDITY_ROLE, testMultisig);

            holders[i++] = Vault.RoleHolder(Permissions.CREATE_QUEUE_ROLE, deployer);
            holders[i++] = Vault.RoleHolder(Permissions.CREATE_SUBVAULT_ROLE, deployer);
            holders[i++] = Vault.RoleHolder(Permissions.SET_VAULT_LIMIT_ROLE, deployer);
            holders[i++] = Vault.RoleHolder(Permissions.ALLOW_SUBVAULT_ASSETS_ROLE, deployer);
            holders[i++] = Vault.RoleHolder(Permissions.SET_SUBVAULT_LIMIT_ROLE, deployer);
            holders[i++] = Vault.RoleHolder(Permissions.SUBMIT_REPORTS_ROLE, deployer);
            holders[i++] = Vault.RoleHolder(Permissions.ACCEPT_REPORT_ROLE, deployer);
            holders[i++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, deployer);
            assembly {
                mstore(holders, i)
            }
        }
        address[] memory assets_ = ArraysLibrary.makeAddressArray(abi.encode(Constants.ETH, Constants.WETH));

        ProtocolDeployment memory $ = Constants.protocolDeployment();
        VaultConfigurator.InitParams memory initParams = VaultConfigurator.InitParams({
            version: 0,
            proxyAdmin: testMultisig,
            vaultAdmin: testMultisig,
            shareManagerVersion: 0,
            shareManagerParams: abi.encode(bytes32(0), vaultName, vaultSymbol),
            feeManagerVersion: 0,
            feeManagerParams: abi.encode(deployer, testMultisig, uint24(0), uint24(0), uint24(0), uint24(0)),
            riskManagerVersion: 0,
            riskManagerParams: abi.encode(type(int256).max / 2),
            oracleVersion: 0,
            oracleParams: abi.encode(
                IOracle.SecurityParams({
                    maxAbsoluteDeviation: 0.005 ether,
                    suspiciousAbsoluteDeviation: 0.001 ether,
                    maxRelativeDeviationD18: 0.005 ether,
                    suspiciousRelativeDeviationD18: 0.001 ether,
                    timeout: 1 seconds,
                    depositInterval: 1 seconds,
                    redeemInterval: 1 seconds
                }),
                assets_
            ),
            defaultDepositHook: address($.redirectingDepositHook),
            defaultRedeemHook: address($.basicRedeemHook),
            queueLimit: type(uint256).max,
            roleHolders: holders
        });

        Vault vault;
        {
            (,,,, address vault_) = $.vaultConfigurator.create(initParams);
            vault = Vault(payable(vault_));
        }

        // queues setup
        vault.createQueue(0, true, testMultisig, Constants.ETH, new bytes(0));
        vault.createQueue(0, true, testMultisig, Constants.WETH, new bytes(0));
        vault.createQueue(0, false, testMultisig, Constants.WETH, new bytes(0));

        // fee manager setup
        vault.feeManager().setBaseAsset(address(vault), Constants.ETH);
        Ownable(address(vault.feeManager())).transferOwnership(testMultisig);

        // subvault setup
        address[] memory verifiers = new address[](1);
        SubvaultCalls[] memory calls = new SubvaultCalls[](1);

        IRiskManager riskManager = vault.riskManager();
        {
            uint256 subvaultIndex = 0;
            verifiers[subvaultIndex] = $.verifierFactory.create(0, testMultisig, abi.encode(vault, bytes32(0)));
            address subvault = vault.createSubvault(0, testMultisig, verifiers[subvaultIndex]); // eth,weth
            riskManager.allowSubvaultAssets(subvault, assets_);
            riskManager.setSubvaultLimit(subvault, type(int256).max / 2);
        }

        console.log("Vault %s", address(vault));

        console.log("DepositQueue (ETH) %s", address(vault.queueAt(Constants.ETH, 0)));
        console.log("DepositQueue (WETH) %s", address(vault.queueAt(Constants.WETH, 0)));
        console.log("RedeemQueue (WETH) %s", address(vault.queueAt(Constants.WETH, 1)));

        console.log("Oracle %s", address(vault.oracle()));
        console.log("ShareManager %s", address(vault.shareManager()));
        console.log("FeeManager %s", address(vault.feeManager()));
        console.log("RiskManager %s", address(vault.riskManager()));

        for (uint256 i = 0; i < vault.subvaults(); i++) {
            address subvault = vault.subvaultAt(i);
            console.log("Subvault %s %s", i, subvault);
            console.log("Verifier %s %s", i, address(Subvault(payable(subvault)).verifier()));
        }

        {
            IOracle.Report[] memory reports = new IOracle.Report[](assets_.length);
            for (uint256 i = 0; i < reports.length; i++) {
                reports[i].asset = assets_[i];
            }
            reports[0].priceD18 = 1 ether;
            reports[1].priceD18 = 1 ether;
            IOracle oracle = vault.oracle();
            oracle.submitReports(reports);
        }

        _acceptReports(vault);

        vm.stopBroadcast();

        AcceptanceLibrary.runProtocolDeploymentChecks(Constants.protocolDeployment());
        AcceptanceLibrary.runVaultDeploymentChecks(
            Constants.protocolDeployment(),
            VaultDeployment({
                vault: vault,
                calls: calls,
                initParams: initParams,
                holders: _getExpectedHolders(deployer),
                depositHook: address($.redirectingDepositHook),
                redeemHook: address($.basicRedeemHook),
                assets: assets_,
                depositQueueAssets: ArraysLibrary.makeAddressArray(abi.encode(Constants.ETH, Constants.WETH)),
                redeemQueueAssets: ArraysLibrary.makeAddressArray(abi.encode(Constants.WETH)),
                subvaultVerifiers: verifiers,
                timelockControllers: new address[](0),
                timelockProposers: new address[](0),
                timelockExecutors: new address[](0)
            })
        );
    }

    function _acceptReports(Vault vault) internal {
        IOracle oracle = vault.oracle();
        for (uint256 i = 0; i < oracle.supportedAssets(); i++) {
            address asset = oracle.supportedAssetAt(i);
            IOracle.DetailedReport memory r = oracle.getReport(asset);
            oracle.acceptReport(asset, uint256(r.priceD18), uint32(r.timestamp));
        }
    }

    function _getExpectedHolders(address deployer) internal view returns (Vault.RoleHolder[] memory holders) {
        holders = new Vault.RoleHolder[](42);
        uint256 i = 0;

        holders[i++] = Vault.RoleHolder(Permissions.DEFAULT_ADMIN_ROLE, testMultisig);
        holders[i++] = Vault.RoleHolder(Permissions.ACCEPT_REPORT_ROLE, testMultisig);
        holders[i++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, testMultisig);
        holders[i++] = Vault.RoleHolder(Permissions.SUBMIT_REPORTS_ROLE, testMultisig);
        holders[i++] = Vault.RoleHolder(Permissions.CALLER_ROLE, testMultisig);
        holders[i++] = Vault.RoleHolder(Permissions.PULL_LIQUIDITY_ROLE, testMultisig);
        holders[i++] = Vault.RoleHolder(Permissions.PUSH_LIQUIDITY_ROLE, testMultisig);

        holders[i++] = Vault.RoleHolder(Permissions.CREATE_QUEUE_ROLE, deployer);
        holders[i++] = Vault.RoleHolder(Permissions.CREATE_SUBVAULT_ROLE, deployer);
        holders[i++] = Vault.RoleHolder(Permissions.SET_VAULT_LIMIT_ROLE, deployer);
        holders[i++] = Vault.RoleHolder(Permissions.ALLOW_SUBVAULT_ASSETS_ROLE, deployer);
        holders[i++] = Vault.RoleHolder(Permissions.SET_SUBVAULT_LIMIT_ROLE, deployer);
        holders[i++] = Vault.RoleHolder(Permissions.SUBMIT_REPORTS_ROLE, deployer);
        holders[i++] = Vault.RoleHolder(Permissions.ACCEPT_REPORT_ROLE, deployer);
        holders[i++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, deployer);
        assembly {
            mstore(holders, i)
        }
    }
}
