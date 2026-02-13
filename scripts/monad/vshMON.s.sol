// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../common/interfaces/IAavePoolV3.sol";
import "../common/interfaces/ICowswapSettlement.sol";
import {IWETH as WETHInterface} from "../common/interfaces/IWETH.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import "../collectors/defi/external/IAaveOracleV3.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";

import "../../src/vaults/Subvault.sol";
import "../../src/vaults/VaultConfigurator.sol";

import "../../scripts/collectors/Collector.sol";
import "../common/AcceptanceLibrary.sol";
import "../common/Permissions.sol";
import "../common/ProofLibrary.sol";
import "forge-std/Script.sol";

import "./Constants.sol";

contract Deploy is Script {
    /*
        Fastlane proxy admin leverage strategy multisig (4/6): 0x69Da353A1A7Af69A8FB95C67908580D8f7B7A149
        Oracle updater: 0xcd4dDd7EC5fAa95EaCF6858A6812c47Ef707f2d6 (eoa)
        Curator: 0xdcDc8989eC8771e1aA586347c848DFeAED68d10F (msig 2/3)
    */

    // Actors
    address public deployer;
    address public proxyAdmin = 0x69Da353A1A7Af69A8FB95C67908580D8f7B7A149;
    address public lazyVaultAdmin = 0x69Da353A1A7Af69A8FB95C67908580D8f7B7A149;
    address public activeVaultAdmin = 0x69Da353A1A7Af69A8FB95C67908580D8f7B7A149;
    address public oracleUpdater = 0xcd4dDd7EC5fAa95EaCF6858A6812c47Ef707f2d6;
    address public curator = 0xdcDc8989eC8771e1aA586347c848DFeAED68d10F;
    address public pauser = 0x69Da353A1A7Af69A8FB95C67908580D8f7B7A149;

    address public feeManagerOwner = 0x5523462B0dDA6F6D9a26d0d088160995c0332Bf3;
    Vault public vault = Vault(payable(address(0xd7441a389Df504D2124529157152AaAD766456da)));

    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        deployer = vm.addr(deployerPk);

        vm.startBroadcast(deployerPk);
        deployMonad();
        vm.stopBroadcast();
        revert("ok");
    }

    function deployMonad() internal {
        Vault.RoleHolder[] memory holders = new Vault.RoleHolder[](42);
        TimelockController timelockController;

        {
            address[] memory proposers = ArraysLibrary.makeAddressArray(abi.encode(lazyVaultAdmin, deployer));
            address[] memory executors = ArraysLibrary.makeAddressArray(abi.encode(lazyVaultAdmin));
            timelockController = new TimelockController(0, proposers, executors, lazyVaultAdmin);
        }
        {
            uint256 i = 0;

            // activeVaultAdmin roles:
            holders[i++] = Vault.RoleHolder(Permissions.ACCEPT_REPORT_ROLE, activeVaultAdmin);
            holders[i++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, lazyVaultAdmin);
            holders[i++] = Vault.RoleHolder(Permissions.ALLOW_CALL_ROLE, lazyVaultAdmin);
            holders[i++] = Vault.RoleHolder(Permissions.DISALLOW_CALL_ROLE, lazyVaultAdmin);
            holders[i++] = Vault.RoleHolder(Permissions.SET_VAULT_LIMIT_ROLE, lazyVaultAdmin);
            holders[i++] = Vault.RoleHolder(Permissions.SET_SUBVAULT_LIMIT_ROLE, activeVaultAdmin);
            holders[i++] = Vault.RoleHolder(Permissions.ALLOW_SUBVAULT_ASSETS_ROLE, activeVaultAdmin);
            holders[i++] = Vault.RoleHolder(Permissions.MODIFY_VAULT_BALANCE_ROLE, activeVaultAdmin);
            holders[i++] = Vault.RoleHolder(Permissions.MODIFY_SUBVAULT_BALANCE_ROLE, activeVaultAdmin);

            // emergeny pauser roles:
            holders[i++] = Vault.RoleHolder(Permissions.SET_FLAGS_ROLE, address(timelockController));
            holders[i++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, address(timelockController));
            holders[i++] = Vault.RoleHolder(Permissions.SET_QUEUE_STATUS_ROLE, address(timelockController));

            // oracle updater roles:
            holders[i++] = Vault.RoleHolder(Permissions.SUBMIT_REPORTS_ROLE, oracleUpdater);

            // curator roles:
            holders[i++] = Vault.RoleHolder(Permissions.CALLER_ROLE, curator);
            holders[i++] = Vault.RoleHolder(Permissions.PULL_LIQUIDITY_ROLE, curator);
            holders[i++] = Vault.RoleHolder(Permissions.PUSH_LIQUIDITY_ROLE, curator);

            // deployer roles:
            holders[i++] = Vault.RoleHolder(Permissions.CREATE_QUEUE_ROLE, deployer);
            holders[i++] = Vault.RoleHolder(Permissions.CREATE_SUBVAULT_ROLE, deployer);
            holders[i++] = Vault.RoleHolder(Permissions.SET_VAULT_LIMIT_ROLE, deployer);
            holders[i++] = Vault.RoleHolder(Permissions.ALLOW_SUBVAULT_ASSETS_ROLE, deployer);
            holders[i++] = Vault.RoleHolder(Permissions.SET_SUBVAULT_LIMIT_ROLE, deployer);
            holders[i++] = Vault.RoleHolder(Permissions.SUBMIT_REPORTS_ROLE, deployer);
            holders[i++] = Vault.RoleHolder(Permissions.ACCEPT_REPORT_ROLE, deployer);
            assembly {
                mstore(holders, i)
            }
        }
        address[] memory assets_ = ArraysLibrary.makeAddressArray(abi.encode(Constants.SHMON));
        address[] memory depositAssets = ArraysLibrary.makeAddressArray(abi.encode(Constants.SHMON));
        address[] memory withdrawAssets = ArraysLibrary.makeAddressArray(abi.encode(Constants.SHMON));

        ProtocolDeployment memory $ = Constants.protocolDeployment();
        VaultConfigurator.InitParams memory initParams = VaultConfigurator.InitParams({
            version: 0,
            proxyAdmin: proxyAdmin,
            vaultAdmin: lazyVaultAdmin,
            shareManagerVersion: 0,
            shareManagerParams: abi.encode(bytes32(0), "Fastlane Strategic Vault", "vshMON"),
            feeManagerVersion: 0,
            feeManagerParams: abi.encode(deployer, feeManagerOwner, uint24(0), uint24(0), uint24(15e4), uint24(1e4)),
            riskManagerVersion: 0,
            riskManagerParams: abi.encode(type(int256).max / 2),
            oracleVersion: 0,
            oracleParams: abi.encode(
                IOracle.SecurityParams({
                    maxAbsoluteDeviation: 0.005 ether,
                    suspiciousAbsoluteDeviation: 0.001 ether,
                    maxRelativeDeviationD18: 0.005 ether,
                    suspiciousRelativeDeviationD18: 0.001 ether,
                    timeout: 6 hours,
                    depositInterval: 1 hours,
                    redeemInterval: 2 days
                }),
                assets_
            ),
            defaultDepositHook: address($.redirectingDepositHook),
            defaultRedeemHook: address($.basicRedeemHook),
            queueLimit: 6,
            roleHolders: holders
        });

        Vault vault;
        {
            (,,,, address vault_) = $.vaultConfigurator.create(initParams);
            vault = Vault(payable(vault_));
        }
        {
            // deposit queues setup
            for (uint256 i = 0; i < depositAssets.length; i++) {
                vault.createQueue(0, true, proxyAdmin, depositAssets[i], new bytes(0));
            }
            // withdraw queues setup
            for (uint256 i = 0; i < withdrawAssets.length; i++) {
                vault.createQueue(0, false, proxyAdmin, withdrawAssets[i], new bytes(0));
            }
        }

        // fee manager setup
        vault.feeManager().setBaseAsset(address(vault), Constants.SHMON);
        Ownable(address(vault.feeManager())).transferOwnership(feeManagerOwner);

        // subvault setup
        address[] memory verifiers = new address[](1);
        SubvaultCalls[] memory calls = new SubvaultCalls[](1);

        {
            IRiskManager riskManager = vault.riskManager();

            verifiers[0] = $.verifierFactory.create(0, proxyAdmin, abi.encode(vault, bytes32(0)));
            address subvault = vault.createSubvault(0, proxyAdmin, verifiers[0]);

            //bytes32 merkleRoot;
            //(merkleRoot, calls[0]) = _createSubvault0Proofs(subvault);
            //IVerifier(verifiers[0]).setMerkleRoot(merkleRoot);

            riskManager.allowSubvaultAssets(subvault, assets_);
            riskManager.setSubvaultLimit(subvault, type(int256).max / 2);
        }

        // emergency pause setup
        timelockController.schedule(
            address(vault.shareManager()),
            0,
            abi.encodeCall(
                IShareManager.setFlags,
                (
                    IShareManager.Flags({
                        hasMintPause: true,
                        hasBurnPause: true,
                        hasTransferPause: true,
                        hasWhitelist: true,
                        hasTransferWhitelist: true,
                        globalLockup: type(uint32).max
                    })
                )
            ),
            bytes32(0),
            bytes32(0),
            0
        );

        timelockController.schedule(
            address(Subvault(payable(vault.subvaultAt(0))).verifier()),
            0,
            abi.encodeCall(IVerifier.setMerkleRoot, (bytes32(0))),
            bytes32(0),
            bytes32(0),
            0
        );

        for (uint256 i = 0; i < assets_.length; i++) {
            if (vault.getQueueCount(assets_[i]) > 0) {
                address queue = vault.queueAt(assets_[i], 0);
                timelockController.schedule(
                    address(vault),
                    0,
                    abi.encodeCall(IShareModule.setQueueStatus, (queue, true)),
                    bytes32(0),
                    bytes32(0),
                    0
                );
            }
        }

        timelockController.renounceRole(timelockController.PROPOSER_ROLE(), deployer);
        timelockController.renounceRole(timelockController.CANCELLER_ROLE(), deployer);

        vault.renounceRole(Permissions.CREATE_QUEUE_ROLE, deployer);
        vault.renounceRole(Permissions.CREATE_SUBVAULT_ROLE, deployer);
        vault.renounceRole(Permissions.SET_VAULT_LIMIT_ROLE, deployer);
        vault.renounceRole(Permissions.ALLOW_SUBVAULT_ASSETS_ROLE, deployer);
        vault.renounceRole(Permissions.SET_SUBVAULT_LIMIT_ROLE, deployer);

        console.log("Vault %s", address(vault));

        for (uint256 i = 0; i < depositAssets.length; i++) {
            console.log(
                "DepositQueue (%s) %s", getSymbol(depositAssets[i]), address(vault.queueAt(depositAssets[i], 0))
            );
        }
        for (uint256 i = 0; i < withdrawAssets.length; i++) {
            console.log(
                "RedeemQueue (%s) %s", getSymbol(withdrawAssets[i]), address(vault.queueAt(withdrawAssets[i], 1))
            );
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
        console.log("Timelock controller:", address(timelockController));

        {
            IOracle.Report[] memory reports = new IOracle.Report[](assets_.length);
            for (uint256 i = 0; i < assets_.length; i++) {
                reports[i].asset = assets_[i];
            }
            reports[0].priceD18 = 1 ether;

            IOracle oracle = vault.oracle();
            oracle.submitReports(reports);
            uint256 timestamp = oracle.getReport(Constants.SHMON).timestamp;

            for (uint256 i = 0; i < reports.length; i++) {
                oracle.acceptReport(reports[i].asset, reports[i].priceD18, uint32(timestamp));
            }

            vault.renounceRole(Permissions.SUBMIT_REPORTS_ROLE, deployer);
            vault.renounceRole(Permissions.ACCEPT_REPORT_ROLE, deployer);

            (, bytes memory data) =
                Constants.SHMON.call{value: 1 ether}(abi.encodeWithSelector(0x6e553f65, 1 ether, deployer));
            uint224 shares = abi.decode(data, (uint224));
            address queue = address(vault.queueAt(Constants.SHMON, 0));
            IERC4626(Constants.SHMON).approve(queue, shares);
            IDepositQueue(queue).deposit(shares, address(0), new bytes32[](0));
        }

        AcceptanceLibrary.runProtocolDeploymentChecks(Constants.protocolDeployment());
        AcceptanceLibrary.runVaultDeploymentChecks(
            Constants.protocolDeployment(),
            VaultDeployment({
                vault: vault,
                calls: calls,
                initParams: initParams,
                holders: _getExpectedHolders(address(timelockController)),
                depositHook: address($.redirectingDepositHook),
                redeemHook: address($.basicRedeemHook),
                assets: assets_,
                depositQueueAssets: depositAssets,
                redeemQueueAssets: withdrawAssets,
                subvaultVerifiers: verifiers,
                timelockControllers: ArraysLibrary.makeAddressArray(abi.encode(timelockController)),
                timelockProposers: ArraysLibrary.makeAddressArray(abi.encode(lazyVaultAdmin, deployer)),
                timelockExecutors: ArraysLibrary.makeAddressArray(abi.encode(lazyVaultAdmin))
            })
        );
    }

    function _getExpectedHolders(address timelockController)
        internal
        view
        returns (Vault.RoleHolder[] memory holders)
    {
        holders = new Vault.RoleHolder[](50);
        uint256 i = 0;

        // lazyVaultAdmin roles:
        holders[i++] = Vault.RoleHolder(Permissions.DEFAULT_ADMIN_ROLE, lazyVaultAdmin);

        // activeVaultAdmin roles:
        holders[i++] = Vault.RoleHolder(Permissions.ACCEPT_REPORT_ROLE, activeVaultAdmin);
        holders[i++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, lazyVaultAdmin);
        holders[i++] = Vault.RoleHolder(Permissions.ALLOW_CALL_ROLE, lazyVaultAdmin);
        holders[i++] = Vault.RoleHolder(Permissions.DISALLOW_CALL_ROLE, lazyVaultAdmin);
        holders[i++] = Vault.RoleHolder(Permissions.SET_VAULT_LIMIT_ROLE, lazyVaultAdmin);
        holders[i++] = Vault.RoleHolder(Permissions.SET_SUBVAULT_LIMIT_ROLE, activeVaultAdmin);
        holders[i++] = Vault.RoleHolder(Permissions.ALLOW_SUBVAULT_ASSETS_ROLE, activeVaultAdmin);
        holders[i++] = Vault.RoleHolder(Permissions.MODIFY_VAULT_BALANCE_ROLE, activeVaultAdmin);
        holders[i++] = Vault.RoleHolder(Permissions.MODIFY_SUBVAULT_BALANCE_ROLE, activeVaultAdmin);

        // emergency pauser roles:
        holders[i++] = Vault.RoleHolder(Permissions.SET_FLAGS_ROLE, address(timelockController));
        holders[i++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, address(timelockController));
        holders[i++] = Vault.RoleHolder(Permissions.SET_QUEUE_STATUS_ROLE, address(timelockController));

        // oracle updater roles:
        holders[i++] = Vault.RoleHolder(Permissions.SUBMIT_REPORTS_ROLE, oracleUpdater);

        // curator roles:
        holders[i++] = Vault.RoleHolder(Permissions.CALLER_ROLE, curator);
        holders[i++] = Vault.RoleHolder(Permissions.PULL_LIQUIDITY_ROLE, curator);
        holders[i++] = Vault.RoleHolder(Permissions.PUSH_LIQUIDITY_ROLE, curator);

        assembly {
            mstore(holders, i)
        }
    }

    function _createSubvault0Proofs(address subvault)
        internal
        returns (bytes32 merkleRoot, SubvaultCalls memory calls)
    {
        merkleRoot = bytes32(0);
        calls.calls = new Call[][](1);
        calls.calls[0] = new Call[](0);
        calls.payloads = new IVerifier.VerificationPayload[](0);
    }

    function getSymbol(address token) internal view returns (string memory) {
        if (token == Constants.MON) {
            return "MON";
        } else {
            return IERC20Metadata(token).symbol();
        }
    }

    function acceptReport() internal {
        IOracle oracle = vault.oracle();
        address[] memory assets = ArraysLibrary.makeAddressArray(abi.encode(Constants.SHMON));

        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        deployer = vm.addr(deployerPk);

        vm.startBroadcast(deployerPk);
        for (uint256 i = 0; i < assets.length; i++) {
            IOracle.DetailedReport memory report = oracle.getReport(assets[i]);
            oracle.acceptReport(assets[i], report.priceD18, uint32(report.timestamp));
            console.log("asset %s priceD18 %s timestamp %s", assets[i], report.priceD18, report.timestamp);
        }

        {
            (, bytes memory data) =
                Constants.SHMON.call{value: 1 ether}(abi.encodeWithSelector(0x6e553f65, 1 ether, deployer));
            uint224 shares = abi.decode(data, (uint224));
            address queue = address(vault.queueAt(Constants.SHMON, 0));
            IERC4626(Constants.SHMON).approve(queue, shares);
            IDepositQueue(queue).deposit(shares, address(0), new bytes32[](0));
        }

        vault.renounceRole(Permissions.SUBMIT_REPORTS_ROLE, deployer);
        vault.renounceRole(Permissions.ACCEPT_REPORT_ROLE, deployer);

        vm.stopBroadcast();
    }

    function pushReport() internal {
        IOracle oracle = vault.oracle();
        address[] memory assets = ArraysLibrary.makeAddressArray(abi.encode(Constants.SHMON));

        IOracle.Report[] memory reports = new IOracle.Report[](assets.length);
        for (uint256 i = 0; i < assets.length; i++) {
            IOracle.DetailedReport memory report = oracle.getReport(assets[i]);
            reports[i] = IOracle.Report({asset: assets[i], priceD18: report.priceD18});
        }

        vm.prank(oracleUpdater);
        oracle.submitReports(reports);
    }

    function _updateMerkleRoot() internal {
        bytes32[] memory merkleRoot = new bytes32[](1);
        SubvaultCalls[] memory calls = new SubvaultCalls[](1);

        address subvault = vault.subvaultAt(0);
        (merkleRoot[0], calls[0]) = _createSubvault0Proofs(subvault);

        for (uint256 i = 0; i < calls.length; i++) {
            Subvault subvault = Subvault(payable(IVaultModule(vault).subvaultAt(i)));
            IVerifier verifier = Subvault(payable(subvault)).verifier();

            vm.prank(lazyVaultAdmin);
            verifier.setMerkleRoot(merkleRoot[i]);

            for (uint256 j = 0; j < calls[i].payloads.length; j++) {
                AcceptanceLibrary._verifyCalls(verifier, calls[i].calls[j], calls[i].payloads[j]);
            }
        }
    }
}
