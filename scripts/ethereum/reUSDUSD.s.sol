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
import "./strETHLibrary.sol";

import "../common/ArraysLibrary.sol";

import "../common/protocols/BracketVaultLibrary.sol";
import "../common/protocols/CurveLibrary.sol";

import "../common/protocols/DigiFTILibrary.sol";
import "../common/protocols/ERC4626Library.sol";
import "../common/protocols/TermMaxLibrary.sol";

import {reUSDUSDLibrary} from "./reUSDUSDLibrary.sol";

contract Deploy is Script {
    // Actors
    address public proxyAdmin = 0xEB4Af6fA3AFA08B10d593EC8fF87efB03BC04645;
    address public lazyVaultAdmin = 0xEB4Af6fA3AFA08B10d593EC8fF87efB03BC04645;
    address public activeVaultAdmin = 0xEB4Af6fA3AFA08B10d593EC8fF87efB03BC04645;
    address public oracleUpdater = 0xEB4Af6fA3AFA08B10d593EC8fF87efB03BC04645;
    address public pauser = 0xEB4Af6fA3AFA08B10d593EC8fF87efB03BC04645;

    address public curator = 0x6788c8ad65E85CCa7224a0B46D061EF7D81F9Da5;

    address public feeManagerAdmin = 0xb1E5a8F26C43d019f2883378548a350ecdD1423B;
    address public treasury = 0xb1E5a8F26C43d019f2883378548a350ecdD1423B;

    address public swapModuleOracle = 0x5dad47A49558708173c2150B0D0652018842fa03;

    address public deployer;

    address public constant termmaxMarket = 0x7fa18408f5D0528d1706B6138113BCA446131531; // reUSD/USDU

    function run() external {
        updateMerkleRoot(0x483B00e3b34057D84CF4fF425eBFa7bAdA9f02de);
        revert("ok");
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        deployer = vm.addr(deployerPk);

        vm.startBroadcast(deployerPk);

        Vault.RoleHolder[] memory holders = new Vault.RoleHolder[](42);
        TimelockController timelockController;

        {
            address[] memory proposers = ArraysLibrary.makeAddressArray(abi.encode(lazyVaultAdmin, deployer));
            address[] memory executors = ArraysLibrary.makeAddressArray(abi.encode(pauser));
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
            holders[i++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, deployer);
            assembly {
                mstore(holders, i)
            }
        }
        address[] memory assets_ = ArraysLibrary.makeAddressArray(
            abi.encode(Constants.USDC, Constants.USDU, Constants.USDE, Constants.SUSDE, Constants.REUSD)
        );

        ProtocolDeployment memory $ = Constants.protocolDeployment();
        VaultConfigurator.InitParams memory initParams = VaultConfigurator.InitParams({
            version: 0,
            proxyAdmin: proxyAdmin,
            vaultAdmin: lazyVaultAdmin,
            shareManagerVersion: 0,
            shareManagerParams: abi.encode(bytes32(0), "reUSD USD", "reUSDUSD"),
            feeManagerVersion: 0,
            feeManagerParams: abi.encode(deployer, treasury, uint24(0), uint24(0), uint24(0), uint24(1e4)),
            riskManagerVersion: 0,
            riskManagerParams: abi.encode(type(int256).max / 2),
            oracleVersion: 0,
            oracleParams: abi.encode(
                IOracle.SecurityParams({
                    maxAbsoluteDeviation: 0.005 ether,
                    suspiciousAbsoluteDeviation: 0.001 ether,
                    maxRelativeDeviationD18: 0.005 ether,
                    suspiciousRelativeDeviationD18: 0.001 ether,
                    timeout: 1 minutes,
                    depositInterval: 1 minutes,
                    redeemInterval: 1 minutes
                }),
                assets_
            ),
            defaultDepositHook: address($.redirectingDepositHook),
            defaultRedeemHook: address($.basicRedeemHook),
            queueLimit: 3,
            roleHolders: holders
        });

        Vault vault;
        {
            (,,,, address vault_) = $.vaultConfigurator.create(initParams);
            vault = Vault(payable(vault_));
        }

        // queues setup
        vault.createQueue(0, true, proxyAdmin, Constants.USDC, new bytes(0));
        vault.createQueue(0, false, proxyAdmin, Constants.USDC, new bytes(0));
        vault.createQueue(0, false, proxyAdmin, Constants.REUSD, new bytes(0));

        // fee manager setup
        vault.feeManager().setBaseAsset(address(vault), Constants.USDC);
        Ownable(address(vault.feeManager())).transferOwnership(feeManagerAdmin);

        // subvault setup
        address[] memory verifiers = new address[](1);
        SubvaultCalls[] memory calls = new SubvaultCalls[](1);
        IRiskManager riskManager = vault.riskManager();

        {
            verifiers[0] = $.verifierFactory.create(0, proxyAdmin, abi.encode(vault, bytes32(0)));
            vault.createSubvault(0, proxyAdmin, verifiers[0]);
            bytes32 merkleRoot;
            //(merkleRoot, calls[0]) = _createSubvault0Verifier(vault.subvaultAt(0));
            //IVerifier(verifiers[0]).setMerkleRoot(merkleRoot);
            riskManager.allowSubvaultAssets(vault.subvaultAt(0), assets_);
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
        for (uint256 i = 0; i < assets_.length; i++) {
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
        vault.renounceRole(Permissions.SET_VAULT_LIMIT_ROLE, deployer);
        vault.renounceRole(Permissions.ALLOW_SUBVAULT_ASSETS_ROLE, deployer);
        vault.renounceRole(Permissions.SET_SUBVAULT_LIMIT_ROLE, deployer);
        vault.renounceRole(Permissions.SET_MERKLE_ROOT_ROLE, deployer);

        console2.log("Vault %s", address(vault));

        {
            for (uint256 i = 0; i < assets_.length; i++) {
                string memory symbol = IERC20Metadata(assets_[i]).symbol();
                for (uint256 j = 0; j < vault.getQueueCount(assets_[i]); j++) {
                    address queue = vault.queueAt(assets_[i], j);
                    if (vault.isDepositQueue(queue)) {
                        console2.log("DepositQueue (%s): %s", symbol, queue);
                    } else {
                        console2.log("RedeemQueue (%s): %s", symbol, queue);
                    }
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

            reports[0].priceD18 = 1e30; // USDC, 6 decimals
            reports[1].priceD18 = 1 ether; // USDU, 18 decimals
            reports[2].priceD18 = 1 ether; // USDE, 18 decimals
            reports[3].priceD18 = 1.21 ether; // SUSDE, 18 decimals (1.21 USD)
            reports[4].priceD18 = 1.045 ether; // REUSD, 18 decimals (1.045 USD)

            IOracle oracle = vault.oracle();
            oracle.submitReports(reports);
            uint256 timestamp = oracle.getReport(Constants.USDC).timestamp;
            for (uint256 i = 0; i < reports.length; i++) {
                //oracle.acceptReport(reports[i].asset, reports[i].priceD18, uint32(timestamp));
            }
        }

        //acceptReport(vault);

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
                depositQueueAssets: ArraysLibrary.makeAddressArray(abi.encode(Constants.USDC)),
                redeemQueueAssets: ArraysLibrary.makeAddressArray(abi.encode(Constants.USDC, Constants.REUSD)),
                subvaultVerifiers: verifiers,
                timelockControllers: ArraysLibrary.makeAddressArray(abi.encode(address(timelockController))),
                timelockProposers: ArraysLibrary.makeAddressArray(abi.encode(lazyVaultAdmin, deployer)),
                timelockExecutors: ArraysLibrary.makeAddressArray(abi.encode(pauser))
            })
        );

        //revert("ok");
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
        holders[i++] = Vault.RoleHolder(Permissions.CALLER_ROLE, curator);
        holders[i++] = Vault.RoleHolder(Permissions.PULL_LIQUIDITY_ROLE, curator);
        holders[i++] = Vault.RoleHolder(Permissions.PUSH_LIQUIDITY_ROLE, curator);

        holders[i++] = Vault.RoleHolder(Permissions.ACCEPT_REPORT_ROLE, deployer);
        holders[i++] = Vault.RoleHolder(Permissions.SUBMIT_REPORTS_ROLE, deployer);

        assembly {
            mstore(holders, i)
        }
    }

    function _createSubvault0Proofs(address subvault0)
        internal
        returns (bytes32 merkleRoot, SubvaultCalls memory calls)
    {
        address swapModule = _deploySwapModuleSubvault0(subvault0);
        reUSDUSDLibrary.Info memory reUSDUSDLibraryInfo = reUSDUSDLibrary.Info({
            subvaultName: "subvault0",
            curator: curator,
            subvault: subvault0,
            termmaxMarket: termmaxMarket,
            swapModule: swapModule
        });
        /*
            0. IERC20(USDC).approve(reUSD, ...)
            1. IERC20(RedemptionGateway).approve(reUSD, ...)
            2. InsuranceCapitalLayer.deposit(USDC, ..., ...) -> reUSD
            3. RedemptionGateway.redeemInstant(..., ...) reUSD -> sUSDe
            4. ITermMax calls
            5. SwapModule sUSDe, USDC, USDU on Curve
        */
        string[] memory descriptions = reUSDUSDLibrary.getSubvault0Descriptions(reUSDUSDLibraryInfo);
        IVerifier.VerificationPayload[] memory leaves;
        (merkleRoot, leaves) = reUSDUSDLibrary.getSubvault0Proofs(reUSDUSDLibraryInfo);
        ProofLibrary.storeProofs("ethereum:reUSDUSD:subvault0", merkleRoot, leaves, descriptions);
        calls = reUSDUSDLibrary.getSubvault0SubvaultCalls(reUSDUSDLibraryInfo, leaves);
    }

    function _deploySwapModuleSubvault0(address subvault) internal returns (address swapModule) {
        ProtocolDeployment memory $ = Constants.protocolDeployment();
        /*
            CURVE - router
            USDC/USDU/SUSDE - tokenIn
            USDC/USDU/SUSDE - tokenOut
        */
        address[] memory holders = ArraysLibrary.makeAddressArray(
            abi.encode(
                curator,
                Constants.CURVE_ROUTER,
                Constants.USDC,
                Constants.USDU,
                Constants.SUSDE,
                Constants.USDC,
                Constants.USDU,
                Constants.SUSDE
            )
        );
        bytes32[] memory roles = ArraysLibrary.makeBytes32Array(
            abi.encode(
                Permissions.SWAP_MODULE_CALLER_ROLE,
                Permissions.SWAP_MODULE_ROUTER_ROLE,
                Permissions.SWAP_MODULE_TOKEN_IN_ROLE,
                Permissions.SWAP_MODULE_TOKEN_IN_ROLE,
                Permissions.SWAP_MODULE_TOKEN_IN_ROLE,
                Permissions.SWAP_MODULE_TOKEN_OUT_ROLE,
                Permissions.SWAP_MODULE_TOKEN_OUT_ROLE,
                Permissions.SWAP_MODULE_TOKEN_OUT_ROLE
            )
        );

        console2.log("SwapModuleFactory %s", address($.swapModuleFactory));
        swapModule = $.swapModuleFactory.create(
            0, proxyAdmin, abi.encode(lazyVaultAdmin, subvault, swapModuleOracle, 0.995e8, holders, roles)
        );
        console2.log("Subvault0 SwapModule %s", swapModule);
    }

    function updateMerkleRoot(address subvault) internal {
        bytes32[] memory merkleRoot = new bytes32[](1);
        SubvaultCalls[] memory calls = new SubvaultCalls[](1);

        (merkleRoot[0], calls[0]) = _createSubvault0Proofs(subvault);

        IVerifier verifier = Subvault(payable(subvault)).verifier();

        vm.prank(lazyVaultAdmin);
        verifier.setMerkleRoot(merkleRoot[0]);

        console2.log(
            "Updated Merkle root for Subvault %s Verifier %s to %s",
            address(subvault),
            address(verifier),
            Strings.toHexString(uint256(merkleRoot[0]))
        );

        for (uint256 j = 0; j < calls[0].payloads.length; j++) {
            AcceptanceLibrary._verifyCalls(verifier, calls[0].calls[j], calls[0].payloads[j]);
        }
    }

    function acceptReport(Vault vault) internal {
        IOracle oracle = vault.oracle();
        address[] memory assets = ArraysLibrary.makeAddressArray(
            abi.encode(Constants.USDC, Constants.USDU, Constants.USDE, Constants.SUSDE, Constants.REUSD)
        );

        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        deployer = vm.addr(deployerPk);

        vm.startBroadcast(deployerPk);

        for (uint256 i = 0; i < assets.length; i++) {
            IOracle.DetailedReport memory report = oracle.getReport(assets[i]);
            oracle.acceptReport(assets[i], report.priceD18, uint32(report.timestamp));
            console2.log("asset %s priceD18 %s timestamp %s", assets[i], report.priceD18, report.timestamp);
        }
        IERC20(Constants.USDC).approve(address(vault.queueAt(Constants.USDC, 0)), 1e6);
        IDepositQueue(address(vault.queueAt(Constants.USDC, 0))).deposit(1e6, address(0), new bytes32[](0));

        vault.renounceRole(Permissions.SUBMIT_REPORTS_ROLE, deployer);
        vault.renounceRole(Permissions.ACCEPT_REPORT_ROLE, deployer);
        vm.stopBroadcast();
    }
}
