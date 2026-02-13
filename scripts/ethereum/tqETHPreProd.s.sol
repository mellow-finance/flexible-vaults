// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../common/interfaces/ICowswapSettlement.sol";
import {IWETH as WETHInterface} from "../common/interfaces/IWETH.sol";
import {IWSTETH as WSTETHInterface} from "../common/interfaces/IWSTETH.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";

import "../../src/vaults/Subvault.sol";
import "../../src/vaults/VaultConfigurator.sol";

import "../common/AcceptanceLibrary.sol";
import "../common/Permissions.sol";
import "../common/ProofLibrary.sol";
import "forge-std/Script.sol";

import "./Constants.sol";
import "./tqETHLibrary.sol";

contract Deploy is Script {
    // Actors
    address public proxyAdmin = 0xC1211878475Cd017fecb922Ae63cc3815FA45652;
    address public lazyVaultAdmin = 0xE8bEc6Fb52f01e487415D3Ed3797ab92cBfdF498;
    address public activeVaultAdmin = 0x7885B30F0DC0d8e1aAf0Ed6580caC22d5D09ff4f;
    address public oracleUpdater = 0x3F1C3Eb0bC499c1A091B635dEE73fF55E19cdCE9;

    address public curator1 = 0x55666095cD083a92E368c0CBAA18d8a10D3b65Ec;
    address public curator2 = 0x7096aa3293DEc845235b42c199358D02f497bA58;

    address public pauser1 = 0xFeCeb0255a4B7Cd05995A7d617c0D52c994099CF;
    address public pauser2 = 0x8b7C1b52e2d606a526abD73f326c943c75e45Bd3;

    function _upgradePermissions(uint256 deployerPk) internal {
        Vault vault = Vault(payable(0x2669a8B27B6f957ddb92Dc0ebdec1f112E6079E4));
        _createCowswapVerifier(vault.subvaultAt(0), 0x17aeAbfD3cB214A8757bF07D2E248d526c8C4809);
        _createStrETHVerifier(vault.subvaultAt(1));
        _createOsETHVerifier(vault.subvaultAt(2));
    }

    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);

        if (true) {
            _upgradePermissions(deployerPk);
            revert("ok");
        }

        vm.startBroadcast(deployerPk);

        Vault.RoleHolder[] memory holders = new Vault.RoleHolder[](42);
        TimelockController timelockController;

        {
            address[] memory proposers = ArraysLibrary.makeAddressArray(abi.encode(lazyVaultAdmin, deployer));
            address[] memory executors = ArraysLibrary.makeAddressArray(abi.encode(pauser1, pauser2));
            timelockController = new TimelockController(0, proposers, executors, lazyVaultAdmin);
        }
        {
            uint256 i = 0;

            // activeVaultAdmin roles:
            holders[i++] = Vault.RoleHolder(Permissions.ACCEPT_REPORT_ROLE, activeVaultAdmin);
            holders[i++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, activeVaultAdmin);
            holders[i++] = Vault.RoleHolder(Permissions.ALLOW_CALL_ROLE, activeVaultAdmin);
            holders[i++] = Vault.RoleHolder(Permissions.DISALLOW_CALL_ROLE, activeVaultAdmin);
            holders[i++] = Vault.RoleHolder(Permissions.SET_VAULT_LIMIT_ROLE, activeVaultAdmin);
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
            address[] memory curators = getCurators();

            for (uint256 j = 0; j < curators.length; j++) {
                holders[i++] = Vault.RoleHolder(Permissions.CALLER_ROLE, curators[j]);
                holders[i++] = Vault.RoleHolder(Permissions.PULL_LIQUIDITY_ROLE, curators[j]);
                holders[i++] = Vault.RoleHolder(Permissions.PUSH_LIQUIDITY_ROLE, curators[j]);
            }

            // deployer roles:
            holders[i++] = Vault.RoleHolder(Permissions.CREATE_QUEUE_ROLE, deployer);
            holders[i++] = Vault.RoleHolder(Permissions.CREATE_SUBVAULT_ROLE, deployer);
            holders[i++] = Vault.RoleHolder(Permissions.SET_VAULT_LIMIT_ROLE, deployer);
            holders[i++] = Vault.RoleHolder(Permissions.ALLOW_SUBVAULT_ASSETS_ROLE, deployer);
            holders[i++] = Vault.RoleHolder(Permissions.SET_SUBVAULT_LIMIT_ROLE, deployer);
            holders[i++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, deployer);
            holders[i++] = Vault.RoleHolder(Permissions.SUBMIT_REPORTS_ROLE, deployer);
            holders[i++] = Vault.RoleHolder(Permissions.ACCEPT_REPORT_ROLE, deployer);
            assembly {
                mstore(holders, i)
            }
        }
        address[] memory assets_ = new address[](3);
        assets_[0] = Constants.ETH;
        assets_[1] = Constants.WETH;
        assets_[2] = Constants.WSTETH;

        ProtocolDeployment memory $ = Constants.protocolDeployment();
        VaultConfigurator.InitParams memory initParams = VaultConfigurator.InitParams({
            version: 0,
            proxyAdmin: proxyAdmin,
            vaultAdmin: lazyVaultAdmin,
            shareManagerVersion: 0,
            shareManagerParams: abi.encode(bytes32(0), "Theoriq AlphaVault ETH", "tqETH"),
            feeManagerVersion: 0,
            feeManagerParams: abi.encode(deployer, lazyVaultAdmin, uint24(0), uint24(0), uint24(1e5), uint24(1e4)),
            riskManagerVersion: 0,
            riskManagerParams: abi.encode(type(int256).max),
            oracleVersion: 0,
            oracleParams: abi.encode(
                IOracle.SecurityParams({
                    maxAbsoluteDeviation: 0.005 ether,
                    suspiciousAbsoluteDeviation: 0.001 ether,
                    maxRelativeDeviationD18: 0.005 ether,
                    suspiciousRelativeDeviationD18: 0.001 ether,
                    timeout: 1 hours,
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
        // queues setup
        vault.createQueue(0, true, proxyAdmin, Constants.ETH, new bytes(0));
        vault.createQueue(0, true, proxyAdmin, Constants.WETH, new bytes(0));
        vault.createQueue(0, true, proxyAdmin, Constants.WSTETH, new bytes(0));
        vault.createQueue(0, false, proxyAdmin, Constants.ETH, new bytes(0));
        vault.createQueue(0, false, proxyAdmin, Constants.WETH, new bytes(0));
        vault.createQueue(0, false, proxyAdmin, Constants.WSTETH, new bytes(0));

        // fee manager setup
        vault.feeManager().setBaseAsset(address(vault), Constants.ETH);
        Ownable(address(vault.feeManager())).transferOwnership(lazyVaultAdmin);

        // subvault setup

        address[] memory verifiers = new address[](3);
        SubvaultCalls[] memory calls = new SubvaultCalls[](3);

        {
            IRiskManager riskManager = vault.riskManager();
            verifiers[0] = $.verifierFactory.create(0, proxyAdmin, abi.encode(vault, bytes32(0)));
            address subvault = vault.createSubvault(0, proxyAdmin, verifiers[0]);
            bytes32 merkleRoot;

            address swapModule = $.swapModuleFactory.create(
                0,
                proxyAdmin,
                abi.encode(
                    lazyVaultAdmin,
                    subvault,
                    Constants.AAVE_V3_ORACLE,
                    0.995e8,
                    ArraysLibrary.makeAddressArray(
                        abi.encode(
                            curator1,
                            curator2,
                            Constants.ETH,
                            Constants.WETH,
                            Constants.WSTETH,
                            Constants.ETH,
                            Constants.WETH,
                            Constants.WSTETH,
                            Constants.WETH
                        )
                    ),
                    ArraysLibrary.makeBytes32Array(
                        abi.encode(
                            Permissions.SWAP_MODULE_CALLER_ROLE,
                            Permissions.SWAP_MODULE_CALLER_ROLE,
                            Permissions.SWAP_MODULE_TOKEN_IN_ROLE,
                            Permissions.SWAP_MODULE_TOKEN_IN_ROLE,
                            Permissions.SWAP_MODULE_TOKEN_IN_ROLE,
                            Permissions.SWAP_MODULE_TOKEN_OUT_ROLE,
                            Permissions.SWAP_MODULE_TOKEN_OUT_ROLE,
                            Permissions.SWAP_MODULE_TOKEN_OUT_ROLE,
                            Permissions.SWAP_MODULE_ROUTER_ROLE
                        )
                    )
                )
            );

            (merkleRoot, calls[0]) = _createCowswapVerifier(subvault, swapModule);
            IVerifier(verifiers[0]).setMerkleRoot(merkleRoot);
            riskManager.allowSubvaultAssets(vault.subvaultAt(0), assets_);
            riskManager.setSubvaultLimit(vault.subvaultAt(0), type(int256).max / 2);
        }
        {
            IRiskManager riskManager = vault.riskManager();
            verifiers[1] = $.verifierFactory.create(0, proxyAdmin, abi.encode(vault, bytes32(0)));
            address subvault = vault.createSubvault(0, proxyAdmin, verifiers[1]);
            bytes32 merkleRoot;
            (merkleRoot, calls[1]) = _createStrETHVerifier(subvault);
            IVerifier(verifiers[1]).setMerkleRoot(merkleRoot);
            riskManager.allowSubvaultAssets(vault.subvaultAt(1), assets_);
            riskManager.setSubvaultLimit(vault.subvaultAt(1), type(int256).max / 2);
        }

        {
            IRiskManager riskManager = vault.riskManager();
            verifiers[2] = $.verifierFactory.create(0, proxyAdmin, abi.encode(vault, bytes32(0)));
            address subvault = vault.createSubvault(0, proxyAdmin, verifiers[2]);
            bytes32 merkleRoot;
            (merkleRoot, calls[2]) = _createOsETHVerifier(subvault);
            IVerifier(verifiers[2]).setMerkleRoot(merkleRoot);

            riskManager.allowSubvaultAssets(
                vault.subvaultAt(2), ArraysLibrary.makeAddressArray(abi.encode(Constants.ETH))
            );
            riskManager.setSubvaultLimit(vault.subvaultAt(2), type(int256).max / 2);
        }

        {
            IOracle.Report[] memory reports = new IOracle.Report[](3);
            reports[0].asset = Constants.ETH;
            reports[0].priceD18 = 1 ether;

            reports[1].asset = Constants.WETH;
            reports[1].priceD18 = 1 ether;

            reports[2].asset = Constants.WSTETH;
            reports[2].priceD18 = uint224(WSTETHInterface(Constants.WSTETH).getStETHByWstETH(1 ether));
            IOracle oracle = vault.oracle();
            oracle.submitReports(reports);
            uint256 timestamp = oracle.getReport(Constants.ETH).timestamp;
            for (uint256 i = 0; i < reports.length; i++) {
                oracle.acceptReport(reports[i].asset, reports[i].priceD18, uint32(timestamp));
            }
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
            address asset = vault.assetAt(i);
            for (uint256 j = 0; j < vault.getQueueCount(asset); j++) {
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
        vault.renounceRole(Permissions.SET_VAULT_LIMIT_ROLE, deployer);
        vault.renounceRole(Permissions.ALLOW_SUBVAULT_ASSETS_ROLE, deployer);
        vault.renounceRole(Permissions.SET_SUBVAULT_LIMIT_ROLE, deployer);
        vault.renounceRole(Permissions.SUBMIT_REPORTS_ROLE, deployer);
        vault.renounceRole(Permissions.ACCEPT_REPORT_ROLE, deployer);
        vault.renounceRole(Permissions.SET_MERKLE_ROOT_ROLE, deployer);

        console.log("Vault %s", address(vault));

        console.log("DepositQueue (ETH) %s", address(vault.queueAt(Constants.ETH, 0)));
        console.log("DepositQueue (WETH) %s", address(vault.queueAt(Constants.WETH, 0)));
        console.log("DepositQueue (WSTETH) %s", address(vault.queueAt(Constants.WSTETH, 0)));
        console.log("RedeemQueue (ETH) %s", address(vault.queueAt(Constants.ETH, 1)));
        console.log("RedeemQueue (WETH) %s", address(vault.queueAt(Constants.WETH, 1)));
        console.log("RedeemQueue (WSTETH) %s", address(vault.queueAt(Constants.WSTETH, 1)));

        console.log("Oracle %s", address(vault.oracle()));
        console.log("ShareManager %s", address(vault.shareManager()));
        console.log("FeeManager %s", address(vault.feeManager()));
        console.log("RiskManager %s", address(vault.riskManager()));

        IDepositQueue(address(vault.queueAt(Constants.ETH, 0))).deposit{value: 1 gwei}(
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
                holders: _getExpectedHolders(address(timelockController)),
                depositHook: address($.redirectingDepositHook),
                redeemHook: address($.basicRedeemHook),
                assets: assets_,
                depositQueueAssets: assets_,
                redeemQueueAssets: assets_,
                subvaultVerifiers: verifiers,
                timelockControllers: ArraysLibrary.makeAddressArray(abi.encode(timelockController)),
                timelockProposers: ArraysLibrary.makeAddressArray(abi.encode(lazyVaultAdmin, deployer)),
                timelockExecutors: ArraysLibrary.makeAddressArray(abi.encode(pauser1, pauser2))
            })
        );

        revert("ok");
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
        holders[i++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, activeVaultAdmin);
        holders[i++] = Vault.RoleHolder(Permissions.ALLOW_CALL_ROLE, activeVaultAdmin);
        holders[i++] = Vault.RoleHolder(Permissions.DISALLOW_CALL_ROLE, activeVaultAdmin);
        holders[i++] = Vault.RoleHolder(Permissions.SET_VAULT_LIMIT_ROLE, activeVaultAdmin);
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
        address[] memory curators = getCurators();

        for (uint256 j = 0; j < curators.length; j++) {
            holders[i++] = Vault.RoleHolder(Permissions.CALLER_ROLE, curators[j]);
            holders[i++] = Vault.RoleHolder(Permissions.PULL_LIQUIDITY_ROLE, curators[j]);
            holders[i++] = Vault.RoleHolder(Permissions.PUSH_LIQUIDITY_ROLE, curators[j]);
        }

        assembly {
            mstore(holders, i)
        }
    }

    function getCurators() public view returns (address[] memory) {
        return ArraysLibrary.makeAddressArray(abi.encode(curator1, curator2));
    }

    function _createCowswapVerifier(address subvault, address swapModule)
        internal
        returns (bytes32 merkleRoot, SubvaultCalls memory calls)
    {
        address[] memory curators = getCurators();
        string[] memory descriptions = tqETHLibrary.getSubvault0Descriptions(subvault, swapModule, curators);
        IVerifier.VerificationPayload[] memory leaves;
        (merkleRoot, leaves) = tqETHLibrary.getSubvault0Proofs(subvault, swapModule, curators);
        ProofLibrary.storeProofs("ethereum:tqETHPreProd:subvault0", merkleRoot, leaves, descriptions);
        calls = tqETHLibrary.getSubvault0SubvaultCalls(subvault, swapModule, curators, leaves);
    }

    function _createStrETHVerifier(address subvault)
        internal
        returns (bytes32 merkleRoot, SubvaultCalls memory calls)
    {
        address[] memory curators = getCurators();
        string[] memory descriptions = tqETHLibrary.getSubvault1Descriptions(subvault, curators);
        IVerifier.VerificationPayload[] memory leaves;
        (merkleRoot, leaves) = tqETHLibrary.getSubvault1Proofs(subvault, curators);
        ProofLibrary.storeProofs("ethereum:tqETHPreProd:subvault1", merkleRoot, leaves, descriptions);
        calls = tqETHLibrary.getSubvault1SubvaultCalls(subvault, curators, leaves);
    }

    function _createOsETHVerifier(address subvault) internal returns (bytes32 merkleRoot, SubvaultCalls memory calls) {
        address[] memory curators = getCurators();
        string[] memory descriptions = tqETHLibrary.getSubvault2Descriptions(subvault, curators);
        IVerifier.VerificationPayload[] memory leaves;
        (merkleRoot, leaves) = tqETHLibrary.getSubvault2Proofs(subvault, curators);
        ProofLibrary.storeProofs("ethereum:tqETHPreProd:subvault2", merkleRoot, leaves, descriptions);
        calls = tqETHLibrary.getSubvault2SubvaultCalls(subvault, curators, leaves);
    }
}
