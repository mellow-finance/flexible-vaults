// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../common/interfaces/IAavePoolV3.sol";
import "../common/interfaces/ICowswapSettlement.sol";
import {IWETH as WETHInterface} from "../common/interfaces/IWETH.sol";

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
    // Actors
    address public deployer;
    address public constant vaultOperator = 0x92FB952A80A2395C9eb05281cB116D3Bd391A799;
    address public proxyAdmin = vaultOperator;
    address public lazyVaultAdmin = vaultOperator;
    address public activeVaultAdmin = vaultOperator;
    address public oracleUpdater = vaultOperator;
    address public curator = vaultOperator;
    address public pauser = vaultOperator;

    address public feeManagerOwner = vaultOperator;

    Vault public vault = Vault(payable(address(0)));

    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        deployer = vm.addr(deployerPk);

        vm.startBroadcast(deployerPk);
        deployStrBTC();
        vm.stopBroadcast();
        revert("ok");
    }

    function deployStrBTC() internal {
        TimelockController timelockController;

        {
            address[] memory proposers = ArraysLibrary.makeAddressArray(abi.encode(lazyVaultAdmin, deployer));
            address[] memory executors = ArraysLibrary.makeAddressArray(abi.encode(lazyVaultAdmin));
            timelockController = new TimelockController(0, proposers, executors, lazyVaultAdmin);
        }

        Vault.RoleHolder[] memory holders = _getVaultRoleHolders(address(timelockController), true);

        (address[] memory assets, address[] memory depositAssets, address[] memory withdrawAssets) = _getAssets();

        ProtocolDeployment memory $ = Constants.protocolDeployment();
        VaultConfigurator.InitParams memory initParams = VaultConfigurator.InitParams({
            version: 0,
            proxyAdmin: proxyAdmin,
            vaultAdmin: lazyVaultAdmin,
            shareManagerVersion: 0,
            shareManagerParams: abi.encode(bytes32(0), "Monad Vault", "MVT"),
            feeManagerVersion: 0,
            feeManagerParams: abi.encode(deployer, feeManagerOwner, uint24(0), uint24(0), uint24(1e5), uint24(1e4)),
            riskManagerVersion: 0,
            riskManagerParams: abi.encode(type(int256).max / 2),
            oracleVersion: 0,
            oracleParams: abi.encode(
                IOracle.SecurityParams({
                    maxAbsoluteDeviation: 0.005 ether,
                    suspiciousAbsoluteDeviation: 0.001 ether,
                    maxRelativeDeviationD18: 0.005 ether,
                    suspiciousRelativeDeviationD18: 0.001 ether,
                    timeout: 20 hours,
                    depositInterval: 1 hours,
                    redeemInterval: 2 days
                }),
                assets
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
        vault.feeManager().setBaseAsset(address(vault), Constants.STRBTC);
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

            riskManager.allowSubvaultAssets(subvault, assets);
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

        for (uint256 i = 0; i < assets.length; i++) {
            if (vault.getQueueCount(assets[i]) > 0) {
                address queue = vault.queueAt(assets[i], 0);
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

        console2.log("Vault %s", address(vault));

        for (uint256 i = 0; i < depositAssets.length; i++) {
            console2.log(
                "DepositQueue (%s) %s", getSymbol(depositAssets[i]), address(vault.queueAt(depositAssets[i], 0))
            );
        }
        for (uint256 i = 0; i < withdrawAssets.length; i++) {
            console2.log(
                "RedeemQueue (%s) %s", getSymbol(withdrawAssets[i]), address(vault.queueAt(withdrawAssets[i], 1))
            );
        }

        console2.log("Oracle %s", address(vault.oracle()));
        console2.log("ShareManager %s", address(vault.shareManager()));
        console2.log("FeeManager %s", address(vault.feeManager()));
        console2.log("RiskManager %s", address(vault.riskManager()));

        for (uint256 i = 0; i < vault.subvaults(); i++) {
            address subvault = vault.subvaultAt(i);
            console2.log("Subvault %s %s", i, subvault);
            console2.log("Verifier %s %s", i, address(Subvault(payable(subvault)).verifier()));
        }
        console2.log("Timelock controller:", address(timelockController));

        {
            IOracle.Report[] memory reports = new IOracle.Report[](assets.length);
            for (uint256 i = 0; i < assets.length; i++) {
                reports[i].asset = assets[i];
            }
            reports[0].priceD18 = 1 ether;
            reports[1].priceD18 = 1 ether;
            reports[2].priceD18 = 1 ether;

            IOracle oracle = vault.oracle();
            oracle.submitReports(reports);
            uint256 timestamp = oracle.getReport(Constants.STRBTC).timestamp;
            for (uint256 i = 0; i < reports.length; i++) {
                oracle.acceptReport(reports[i].asset, reports[i].priceD18, uint32(timestamp));
            }
        }

        _renounceTemporaryDeployerRoles(vault, timelockController, holders);

        ProtocolDeployment memory protocolDeployment = Constants.protocolDeployment();
        protocolDeployment.deployer = deployer;

        AcceptanceLibrary.runProtocolDeploymentChecks(protocolDeployment);
        AcceptanceLibrary.runVaultDeploymentChecks(
            protocolDeployment,
            VaultDeployment({
                vault: vault,
                calls: calls,
                initParams: initParams,
                holders: _getVaultRoleHolders(address(timelockController), false),
                depositHook: address($.redirectingDepositHook),
                redeemHook: address($.basicRedeemHook),
                assets: assets,
                depositQueueAssets: depositAssets,
                redeemQueueAssets: withdrawAssets,
                subvaultVerifiers: verifiers,
                timelockControllers: ArraysLibrary.makeAddressArray(abi.encode(timelockController)),
                timelockProposers: ArraysLibrary.makeAddressArray(abi.encode(lazyVaultAdmin, deployer)),
                timelockExecutors: ArraysLibrary.makeAddressArray(abi.encode(lazyVaultAdmin))
            })
        );
    }

    function _getAssets()
        internal
        pure
        returns (address[] memory assets, address[] memory depositAssets, address[] memory withdrawAssets)
    {
        // supported assets
        assets = new address[](3);
        assets[0] = Constants.WBTC;
        assets[1] = Constants.CBBTC;
        assets[2] = Constants.STRBTC;
        // deposit assets
        depositAssets = new address[](3);
        depositAssets[0] = Constants.WBTC;
        depositAssets[1] = Constants.CBBTC;
        depositAssets[2] = Constants.STRBTC;
        // withdraw assets
        withdrawAssets = new address[](1);
        withdrawAssets[0] = Constants.STRBTC;
    }

    function _getVaultRoleHolders(address timelockController, bool withTemporaryRoles)
        public
        view
        returns (Vault.RoleHolder[] memory holders)
    {
        uint256 index;
        holders = new Vault.RoleHolder[](20 + (withTemporaryRoles ? 7 : 0));

        // lazyVaultAdmin roles:
        holders[index++] = Vault.RoleHolder(Permissions.DEFAULT_ADMIN_ROLE, lazyVaultAdmin);
        holders[index++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, lazyVaultAdmin);
        holders[index++] = Vault.RoleHolder(Permissions.ALLOW_CALL_ROLE, lazyVaultAdmin);
        holders[index++] = Vault.RoleHolder(Permissions.DISALLOW_CALL_ROLE, lazyVaultAdmin);
        holders[index++] = Vault.RoleHolder(Permissions.SET_VAULT_LIMIT_ROLE, lazyVaultAdmin);
        holders[index++] = Vault.RoleHolder(Permissions.SET_SECURITY_PARAMS_ROLE, lazyVaultAdmin);

        // activeVaultAdmin roles:
        holders[index++] = Vault.RoleHolder(Permissions.ACCEPT_REPORT_ROLE, activeVaultAdmin);
        holders[index++] = Vault.RoleHolder(Permissions.SET_SUBVAULT_LIMIT_ROLE, activeVaultAdmin);
        holders[index++] = Vault.RoleHolder(Permissions.ALLOW_SUBVAULT_ASSETS_ROLE, activeVaultAdmin);
        holders[index++] = Vault.RoleHolder(Permissions.MODIFY_VAULT_BALANCE_ROLE, activeVaultAdmin);
        holders[index++] = Vault.RoleHolder(Permissions.MODIFY_SUBVAULT_BALANCE_ROLE, activeVaultAdmin);
        holders[index++] = Vault.RoleHolder(Permissions.CREATE_SUBVAULT_ROLE, activeVaultAdmin);

        // emergency pauser roles:
        holders[index++] = Vault.RoleHolder(Permissions.SET_FLAGS_ROLE, address(timelockController));
        holders[index++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, address(timelockController));
        holders[index++] = Vault.RoleHolder(Permissions.SET_QUEUE_STATUS_ROLE, address(timelockController));

        // oracle updater roles:
        holders[index++] = Vault.RoleHolder(Permissions.SUBMIT_REPORTS_ROLE, oracleUpdater);

        // curator roles:
        holders[index++] = Vault.RoleHolder(Permissions.CALLER_ROLE, curator);
        holders[index++] = Vault.RoleHolder(Permissions.PULL_LIQUIDITY_ROLE, curator);
        holders[index++] = Vault.RoleHolder(Permissions.PUSH_LIQUIDITY_ROLE, curator);

        // temporary deployer roles
        if (withTemporaryRoles) {
            holders[index++] = Vault.RoleHolder(Permissions.CREATE_QUEUE_ROLE, deployer);
            holders[index++] = Vault.RoleHolder(Permissions.CREATE_SUBVAULT_ROLE, deployer);
            holders[index++] = Vault.RoleHolder(Permissions.SET_VAULT_LIMIT_ROLE, deployer);
            holders[index++] = Vault.RoleHolder(Permissions.ALLOW_SUBVAULT_ASSETS_ROLE, deployer);
            holders[index++] = Vault.RoleHolder(Permissions.SET_SUBVAULT_LIMIT_ROLE, deployer);
            holders[index++] = Vault.RoleHolder(Permissions.SUBMIT_REPORTS_ROLE, deployer);
            holders[index++] = Vault.RoleHolder(Permissions.ACCEPT_REPORT_ROLE, deployer);
        }
    }

    function _renounceTemporaryDeployerRoles(
        Vault vault,
        TimelockController timelockController,
        Vault.RoleHolder[] memory holders
    ) internal {
        for (uint256 i = 0; i < holders.length; i++) {
            if (holders[i].holder == deployer) {
                vault.renounceRole(holders[i].role, deployer);
            }
        }

        timelockController.renounceRole(timelockController.PROPOSER_ROLE(), deployer);
        timelockController.renounceRole(timelockController.CANCELLER_ROLE(), deployer);
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
        return IERC20Metadata(token).symbol();
    }

    function acceptReport() internal {
        IOracle oracle = vault.oracle();
        address[] memory assets =
            ArraysLibrary.makeAddressArray(abi.encode(Constants.STRBTC, Constants.WBTC, Constants.CBBTC));

        for (uint256 i = 0; i < assets.length; i++) {
            IOracle.DetailedReport memory report = oracle.getReport(assets[i]);
            vm.prank(activeVaultAdmin);
            oracle.acceptReport(assets[i], report.priceD18, uint32(report.timestamp));
            console2.log("asset %s priceD18 %s timestamp %s", assets[i], report.priceD18, report.timestamp);
        }

        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        deployer = vm.addr(deployerPk);

        vm.startBroadcast(deployerPk);
        IDepositQueue(address(vault.queueAt(Constants.STRBTC, 0))).deposit{value: 1 ether}(
            1 ether, address(0), new bytes32[](0)
        );
        vm.stopBroadcast();
    }

    function pushReport() internal {
        IOracle oracle = vault.oracle();
        address[] memory assets =
            ArraysLibrary.makeAddressArray(abi.encode(Constants.STRBTC, Constants.WBTC, Constants.CBBTC));

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
