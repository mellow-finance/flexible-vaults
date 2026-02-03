// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";

import "../../src/oracles/OracleSubmitter.sol";
import "../../src/vaults/Subvault.sol";
import "../../src/vaults/VaultConfigurator.sol";

import "../common/AcceptanceLibrary.sol";
import "../common/Permissions.sol";
import "../common/ProofLibrary.sol";

import "./Constants.sol";

import "../common/ArraysLibrary.sol";

contract Deploy is Script, Test {
    // Actors
    address public proxyAdmin = 0xC5C0fE8D0DD15a96ec2760c1953799F15ecCe65c;
    address public lazyVaultAdmin = 0xC5C0fE8D0DD15a96ec2760c1953799F15ecCe65c;
    address public activeVaultAdmin = 0xC5C0fE8D0DD15a96ec2760c1953799F15ecCe65c;
    address public oracleUpdater = 0xC5C0fE8D0DD15a96ec2760c1953799F15ecCe65c;
    address public curator = 0xc67F082359f006B1D7d1666f1a43976C9E0Aea44;
    address public feeManagerOwner = lazyVaultAdmin;
    address public pauser = 0xC5C0fE8D0DD15a96ec2760c1953799F15ecCe65c;
    // to avoid stack too deep
    address public deployer;
    Vault vault = Vault(payable(0xdB58329eeBb999cbcC168086A71E5DAfc9CfaFB9));
    TimelockController timelockController;

    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));

        deployer = vm.addr(deployerPk);
        console2.log("Deployer: %s", deployer);

        vm.startBroadcast(deployerPk);
        {
            OracleSubmitter oracleSubmitter = OracleSubmitter(0x9D7534a8A42639bd4d8ee7153a8c014eAEEEcB57);

            address[] memory assets_ = ArraysLibrary.makeAddressArray(abi.encode(Constants.RBTC, Constants.WRBTC));
            IOracle oracle = vault.oracle();
            uint224[] memory prices_ = new uint224[](assets_.length);
            uint32[] memory timestamps_ = new uint32[](assets_.length);
            for (uint256 i = 0; i < assets_.length; i++) {
                IOracle.DetailedReport memory report = oracle.getReport(assets_[i]);
                prices_[i] = report.priceD18;
                timestamps_[i] = report.timestamp;
            }
            oracleSubmitter.acceptReports(assets_, prices_, timestamps_);
            oracleSubmitter.renounceRole(Permissions.ACCEPT_REPORT_ROLE, deployer);
        }

        IDepositQueue(address(vault.queueAt(Constants.RBTC, 0))).deposit{value: 1 gwei}(
            1 gwei, address(0), new bytes32[](0)
        );

        return;

        Vault.RoleHolder[] memory holders = new Vault.RoleHolder[](42);

        {
            address[] memory proposers = ArraysLibrary.makeAddressArray(abi.encode(lazyVaultAdmin, deployer));
            address[] memory executors = ArraysLibrary.makeAddressArray(abi.encode(pauser));
            timelockController = new TimelockController(0, proposers, executors, lazyVaultAdmin);
        }
        {
            uint256 i = 0;

            // activeVaultAdmin roles:
            holders[i++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, lazyVaultAdmin);
            holders[i++] = Vault.RoleHolder(Permissions.ALLOW_CALL_ROLE, lazyVaultAdmin);
            holders[i++] = Vault.RoleHolder(Permissions.DISALLOW_CALL_ROLE, lazyVaultAdmin);
            holders[i++] = Vault.RoleHolder(Permissions.SET_SECURITY_PARAMS_ROLE, lazyVaultAdmin);

            // activeVaultAdmin roles:
            holders[i++] = Vault.RoleHolder(Permissions.SET_VAULT_LIMIT_ROLE, activeVaultAdmin);
            holders[i++] = Vault.RoleHolder(Permissions.SET_SUBVAULT_LIMIT_ROLE, activeVaultAdmin);
            holders[i++] = Vault.RoleHolder(Permissions.ALLOW_SUBVAULT_ASSETS_ROLE, activeVaultAdmin);
            holders[i++] = Vault.RoleHolder(Permissions.MODIFY_VAULT_BALANCE_ROLE, activeVaultAdmin);
            holders[i++] = Vault.RoleHolder(Permissions.MODIFY_SUBVAULT_BALANCE_ROLE, activeVaultAdmin);

            // emergeny pauser roles:
            holders[i++] = Vault.RoleHolder(Permissions.SET_FLAGS_ROLE, address(timelockController));
            holders[i++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, address(timelockController));
            holders[i++] = Vault.RoleHolder(Permissions.SET_QUEUE_STATUS_ROLE, address(timelockController));

            // curator roles:
            holders[i++] = Vault.RoleHolder(Permissions.CALLER_ROLE, curator);
            holders[i++] = Vault.RoleHolder(Permissions.PULL_LIQUIDITY_ROLE, curator);
            holders[i++] = Vault.RoleHolder(Permissions.PUSH_LIQUIDITY_ROLE, curator);

            // deployer roles:
            holders[i++] = Vault.RoleHolder(Permissions.DEFAULT_ADMIN_ROLE, deployer);
            holders[i++] = Vault.RoleHolder(Permissions.CREATE_QUEUE_ROLE, deployer);
            holders[i++] = Vault.RoleHolder(Permissions.CREATE_SUBVAULT_ROLE, deployer);
            holders[i++] = Vault.RoleHolder(Permissions.ALLOW_SUBVAULT_ASSETS_ROLE, deployer);
            holders[i++] = Vault.RoleHolder(Permissions.SET_SUBVAULT_LIMIT_ROLE, deployer);
            holders[i++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, deployer);
            assembly {
                mstore(holders, i)
            }
        }
        address[] memory assets_ = ArraysLibrary.makeAddressArray(abi.encode(Constants.RBTC, Constants.WRBTC));

        ProtocolDeployment memory $ = Constants.protocolDeployment();
        VaultConfigurator.InitParams memory initParams = VaultConfigurator.InitParams({
            version: 0,
            proxyAdmin: proxyAdmin,
            vaultAdmin: lazyVaultAdmin,
            shareManagerVersion: 0,
            shareManagerParams: abi.encode(bytes32(0), "Tyr Capital", "Tyr.rBTC"),
            feeManagerVersion: 0,
            feeManagerParams: abi.encode(deployer, lazyVaultAdmin, uint24(0), uint24(0), uint24(2e5), uint24(2e4)),
            riskManagerVersion: 0,
            riskManagerParams: abi.encode(type(int256).max / 2),
            oracleVersion: 0,
            oracleParams: abi.encode(
                IOracle.SecurityParams({
                    maxAbsoluteDeviation: type(uint224).max,
                    suspiciousAbsoluteDeviation: type(uint224).max,
                    maxRelativeDeviationD18: type(uint64).max,
                    suspiciousRelativeDeviationD18: type(uint64).max,
                    timeout: 1,
                    depositInterval: 1,
                    redeemInterval: 1
                }),
                assets_
            ),
            defaultDepositHook: address($.redirectingDepositHook),
            defaultRedeemHook: address($.basicRedeemHook),
            queueLimit: 4,
            roleHolders: holders
        });

        {
            (,,,, address vault_) = $.vaultConfigurator.create{gas: 6800000}(initParams);
            vault = Vault(payable(vault_));
        }

        // queues setup
        vault.createQueue(0, true, proxyAdmin, Constants.RBTC, new bytes(0));
        vault.createQueue(0, false, proxyAdmin, Constants.RBTC, new bytes(0));
        vault.createQueue(0, true, proxyAdmin, Constants.WRBTC, new bytes(0));
        vault.createQueue(0, false, proxyAdmin, Constants.WRBTC, new bytes(0));

        // fee manager setup
        vault.feeManager().setBaseAsset(address(vault), Constants.RBTC);
        Ownable(address(vault.feeManager())).transferOwnership(feeManagerOwner);

        // oracle submitter setup
        OracleSubmitter oracleSubmitter =
            new OracleSubmitter(deployer, oracleUpdater, activeVaultAdmin, address(vault.oracle()));

        vault.grantRole(Permissions.SUBMIT_REPORTS_ROLE, address(oracleSubmitter));
        vault.grantRole(Permissions.ACCEPT_REPORT_ROLE, address(oracleSubmitter));
        vault.renounceRole(Permissions.DEFAULT_ADMIN_ROLE, deployer);

        oracleSubmitter.grantRole(Permissions.SUBMIT_REPORTS_ROLE, deployer);
        oracleSubmitter.grantRole(Permissions.ACCEPT_REPORT_ROLE, deployer);
        oracleSubmitter.grantRole(Permissions.DEFAULT_ADMIN_ROLE, lazyVaultAdmin);
        oracleSubmitter.renounceRole(Permissions.DEFAULT_ADMIN_ROLE, deployer);

        // subvault setup
        address[] memory verifiers = new address[](1);
        SubvaultCalls[] memory calls = new SubvaultCalls[](1);

        IRiskManager riskManager = vault.riskManager();
        {
            verifiers[0] = $.verifierFactory.create(0, proxyAdmin, abi.encode(vault, bytes32(0)));
            vault.createSubvault(0, proxyAdmin, verifiers[0]);
            riskManager.allowSubvaultAssets(
                vault.subvaultAt(0), ArraysLibrary.makeAddressArray(abi.encode(Constants.RBTC, Constants.WRBTC))
            );
            riskManager.setSubvaultLimit(vault.subvaultAt(0), type(int256).max / 2);
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
        for (uint256 i = 0; i < vault.subvaults(); i++) {
            timelockController.schedule(
                address(Subvault(payable(vault.subvaultAt(i))).verifier()),
                0,
                abi.encodeCall(IVerifier.setMerkleRoot, (bytes32(0))),
                bytes32(0),
                bytes32(0),
                0
            );
        }
        for (uint256 i = 0; i < vault.getAssetCount(); i++) {
            address asset = assets_[i];
            uint256 count = vault.getQueueCount(asset);
            for (uint256 j = 0; j < count; j++) {
                address queue = vault.queueAt(asset, j);
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
        vault.renounceRole(Permissions.ALLOW_SUBVAULT_ASSETS_ROLE, deployer);
        vault.renounceRole(Permissions.SET_SUBVAULT_LIMIT_ROLE, deployer);
        vault.renounceRole(Permissions.SET_MERKLE_ROOT_ROLE, deployer);

        console2.log("Vault %s", address(vault));

        for (uint256 i = 0; i < assets_.length; i++) {
            string memory symbol = assets_[i] == Constants.RBTC ? "RBTC" : IERC20Metadata(assets_[i]).symbol();
            for (uint256 j = 0; j < vault.getQueueCount(assets_[i]); j++) {
                address queue = vault.queueAt(assets_[i], j);
                if (vault.isDepositQueue(queue)) {
                    console2.log("DepositQueue (%s): %s", symbol, queue);
                } else {
                    console2.log("RedeemQueue (%s): %s", symbol, queue);
                }
            }
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
            IOracle.Report[] memory reports = new IOracle.Report[](assets_.length);
            for (uint256 i = 0; i < reports.length; i++) {
                reports[i].asset = assets_[i];
            }
            reports[0].priceD18 = 1 ether;
            reports[1].priceD18 = 1 ether;

            oracleSubmitter.submitReports(reports);
            oracleSubmitter.renounceRole(Permissions.SUBMIT_REPORTS_ROLE, deployer);
        }

        {
            IOracle oracle = vault.oracle();
            uint224[] memory prices_ = new uint224[](assets_.length);
            uint32[] memory timestamps_ = new uint32[](assets_.length);
            for (uint256 i = 0; i < assets_.length; i++) {
                IOracle.DetailedReport memory report = oracle.getReport(assets_[i]);
                prices_[i] = report.priceD18;
                timestamps_[i] = report.timestamp;
            }
            oracleSubmitter.acceptReports(assets_, prices_, timestamps_);
            oracleSubmitter.renounceRole(Permissions.ACCEPT_REPORT_ROLE, deployer);
        }

        IDepositQueue(address(vault.queueAt(Constants.RBTC, 0))).deposit{value: 1 gwei}(
            1 gwei, address(0), new bytes32[](0)
        );

        vm.stopBroadcast();

        AcceptanceLibrary.runProtocolDeploymentChecks(Constants.protocolDeployment());
        AcceptanceLibrary.runVaultDeploymentChecks(
            Constants.protocolDeployment(),
            VaultDeployment({
                vault: vault,
                calls: calls,
                initParams: initParams,
                holders: _getExpectedHolders(address(timelockController), address(oracleSubmitter)),
                depositHook: address($.redirectingDepositHook),
                redeemHook: address($.basicRedeemHook),
                assets: assets_,
                depositQueueAssets: assets_,
                redeemQueueAssets: assets_,
                subvaultVerifiers: verifiers,
                timelockControllers: ArraysLibrary.makeAddressArray(abi.encode(address(timelockController))),
                timelockProposers: ArraysLibrary.makeAddressArray(abi.encode(lazyVaultAdmin, deployer)),
                timelockExecutors: ArraysLibrary.makeAddressArray(abi.encode(pauser))
            })
        );

        //revert("ok");
    }

    function _getExpectedHolders(address timelockController, address oracleSubmitter)
        internal
        view
        returns (Vault.RoleHolder[] memory holders)
    {
        holders = new Vault.RoleHolder[](50);
        uint256 i = 0;

        // lazyVaultAdmin roles:
        holders[i++] = Vault.RoleHolder(Permissions.DEFAULT_ADMIN_ROLE, lazyVaultAdmin);
        holders[i++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, lazyVaultAdmin);
        holders[i++] = Vault.RoleHolder(Permissions.ALLOW_CALL_ROLE, lazyVaultAdmin);
        holders[i++] = Vault.RoleHolder(Permissions.DISALLOW_CALL_ROLE, lazyVaultAdmin);
        holders[i++] = Vault.RoleHolder(Permissions.SET_SECURITY_PARAMS_ROLE, lazyVaultAdmin);

        // activeVaultAdmin roles:
        holders[i++] = Vault.RoleHolder(Permissions.SET_VAULT_LIMIT_ROLE, activeVaultAdmin);
        holders[i++] = Vault.RoleHolder(Permissions.SET_SUBVAULT_LIMIT_ROLE, activeVaultAdmin);
        holders[i++] = Vault.RoleHolder(Permissions.ALLOW_SUBVAULT_ASSETS_ROLE, activeVaultAdmin);
        holders[i++] = Vault.RoleHolder(Permissions.MODIFY_VAULT_BALANCE_ROLE, activeVaultAdmin);
        holders[i++] = Vault.RoleHolder(Permissions.MODIFY_SUBVAULT_BALANCE_ROLE, activeVaultAdmin);

        // emergeny pauser roles:
        holders[i++] = Vault.RoleHolder(Permissions.SET_FLAGS_ROLE, address(timelockController));
        holders[i++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, address(timelockController));
        holders[i++] = Vault.RoleHolder(Permissions.SET_QUEUE_STATUS_ROLE, address(timelockController));

        // oracle submitter roles:
        holders[i++] = Vault.RoleHolder(Permissions.ACCEPT_REPORT_ROLE, oracleSubmitter);
        holders[i++] = Vault.RoleHolder(Permissions.SUBMIT_REPORTS_ROLE, oracleSubmitter);

        // curator roles:
        holders[i++] = Vault.RoleHolder(Permissions.CALLER_ROLE, curator);
        holders[i++] = Vault.RoleHolder(Permissions.PULL_LIQUIDITY_ROLE, curator);
        holders[i++] = Vault.RoleHolder(Permissions.PUSH_LIQUIDITY_ROLE, curator);

        assembly {
            mstore(holders, i)
        }
    }
}
