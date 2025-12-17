// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

import {IWETH as WETHInterface} from "../common/interfaces/IWETH.sol";
import {IWSTETH as WSTETHInterface} from "../common/interfaces/IWSTETH.sol";

import {ICapFactory} from "../common/interfaces/ICapFactory.sol";
import {ISymbioticStakerRewardsPermissions} from "../common/interfaces/ISymbioticStakerRewardsPermissions.sol";
import {ISymbioticVaultPermissions} from "../common/interfaces/ISymbioticVaultPermissions.sol";

import {IOracle, OracleSubmitter} from "../../src/oracles/OracleSubmitter.sol";
import {Vault, VaultConfigurator} from "../../src/vaults/VaultConfigurator.sol";

import {AcceptanceLibrary} from "../common/AcceptanceLibrary.sol";

import {ArraysLibrary} from "../common/ArraysLibrary.sol";
import {Permissions} from "../common/Permissions.sol";
import {ProofLibrary} from "../common/ProofLibrary.sol";

import "./Constants.sol";

import {rstETHPlusLibrary} from "./rstETHPlusLibrary.sol";

contract Deploy is Script {
    // Actors

    address public proxyAdmin = 0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0;
    address public lazyVaultAdmin = 0x0Fb1fe5b41cBA3c01BBF48f73bC82b19f32b3053;
    address public activeVaultAdmin = 0x65D692F223bC78da7024a0f0e018D9F35AB45472;
    address public oracleUpdater = 0xAed4BE0D6E933249F833cfF64600e3fB33597B82;
    address public curator = 0x1280e86Cd7787FfA55d37759C0342F8CD3c7594a;

    address public feeManagerOwner = 0x1D2d56EeA41488413cC11441a79F7fF444d469d4;

    address public pauser = 0x3B8Ad20814f782F5681C050eff66F3Df9dF0D0FF;

    uint256 public constant DEFAULT_MULTIPLIER = 0.995e8;

    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);

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

            // lazyVaultAdmin roles
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
        address[] memory assets_ =
            ArraysLibrary.makeAddressArray(abi.encode(Constants.ETH, Constants.WETH, Constants.WSTETH));

        ProtocolDeployment memory $ = Constants.protocolDeployment();
        VaultConfigurator.InitParams memory initParams = VaultConfigurator.InitParams({
            version: 0,
            proxyAdmin: proxyAdmin,
            vaultAdmin: lazyVaultAdmin,
            shareManagerVersion: 0,
            shareManagerParams: abi.encode(bytes32(0), "Restaking Vault ETH+", "rstETH+"),
            feeManagerVersion: 0,
            feeManagerParams: abi.encode(deployer, feeManagerOwner, uint24(0), uint24(0), uint24(175e3), uint24(5e3)),
            riskManagerVersion: 0,
            riskManagerParams: abi.encode(type(int256).max / 2),
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
            queueLimit: 4,
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
        vault.createQueue(0, false, proxyAdmin, Constants.WSTETH, new bytes(0));

        // fee manager setup
        vault.feeManager().setBaseAsset(address(vault), Constants.ETH);
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
        address[] memory verifiers = new address[](3);
        SubvaultCalls[] memory calls = new SubvaultCalls[](3);

        {
            IRiskManager riskManager = vault.riskManager();
            uint256 subvaultIndex = 0;
            verifiers[subvaultIndex] = $.verifierFactory.create(0, proxyAdmin, abi.encode(vault, bytes32(0)));
            address subvault = vault.createSubvault(0, proxyAdmin, verifiers[subvaultIndex]);
            address swapModule = _deploySwapModule0(subvault);
            console2.log("SwapModule 0:", swapModule);

            bytes32 merkleRoot;
            (merkleRoot, calls[subvaultIndex]) = _createSubvault0Proofs(subvault, swapModule);
            IVerifier(verifiers[subvaultIndex]).setMerkleRoot(merkleRoot);

            riskManager.allowSubvaultAssets(subvault, assets_);
            riskManager.setSubvaultLimit(subvault, type(int256).max / 2);
        }

        {
            uint256 subvaultIndex = 1;
            verifiers[subvaultIndex] = $.verifierFactory.create(0, proxyAdmin, abi.encode(vault, bytes32(0)));
            vault.createSubvault(0, proxyAdmin, verifiers[subvaultIndex]);
        }

        {
            uint256 subvaultIndex = 2;
            verifiers[subvaultIndex] = $.verifierFactory.create(0, proxyAdmin, abi.encode(vault, bytes32(0)));
            vault.createSubvault(0, proxyAdmin, verifiers[subvaultIndex]);
        }

        {
            calls[1] = _deploySubvault1(deployer, vault);
        }

        {
            IRiskManager riskManager = vault.riskManager();
            uint256 subvaultIndex = 2;
            address subvault = vault.subvaultAt(subvaultIndex);
            address swapModule = _deploySwapModule2(subvault);
            console2.log("SwapModule 2:", swapModule);
            bytes32 merkleRoot2;
            (merkleRoot2, calls[subvaultIndex]) = _createSubvault2Proofs(subvault, swapModule);
            IVerifier(verifiers[subvaultIndex]).setMerkleRoot(merkleRoot2);

            riskManager.allowSubvaultAssets(subvault, ArraysLibrary.makeAddressArray(abi.encode(Constants.WSTETH)));
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

        for (uint256 i = 0; i < vault.subvaults(); i++) {
            timelockController.schedule(
                address(IVerifierModule(vault.subvaultAt(i)).verifier()),
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
        vault.renounceRole(Permissions.ALLOW_SUBVAULT_ASSETS_ROLE, deployer);
        vault.renounceRole(Permissions.SET_SUBVAULT_LIMIT_ROLE, deployer);
        vault.renounceRole(Permissions.SET_MERKLE_ROOT_ROLE, deployer);

        console2.log("Vault %s", address(vault));

        console2.log("DepositQueue (ETH) %s", address(vault.queueAt(Constants.ETH, 0)));
        console2.log("DepositQueue (WETH) %s", address(vault.queueAt(Constants.WETH, 0)));
        console2.log("DepositQueue (WSTETH) %s", address(vault.queueAt(Constants.WSTETH, 0)));
        console2.log("RedeemQueue (WSTETH) %s", address(vault.queueAt(Constants.WSTETH, 1)));

        console2.log("Oracle %s", address(vault.oracle()));
        console2.log("OracleSubmitter %s", address(oracleSubmitter));
        console2.log("ShareManager %s", address(vault.shareManager()));
        console2.log("FeeManager %s", address(vault.feeManager()));
        console2.log("RiskManager %s", address(vault.riskManager()));

        for (uint256 i = 0; i < vault.subvaults(); i++) {
            address subvault = vault.subvaultAt(i);
            console2.log("Subvault %s %s", i, subvault);
            console2.log("Verifier %s %s", i, address(IVerifierModule(subvault).verifier()));
        }
        console2.log("Timelock controller:", address(timelockController));

        {
            IOracle.Report[] memory reports = new IOracle.Report[](assets_.length);
            for (uint256 i = 0; i < reports.length; i++) {
                reports[i].asset = assets_[i];
            }
            reports[0].priceD18 = 1 ether;
            reports[1].priceD18 = 1 ether;
            reports[2].priceD18 = uint224(WSTETHInterface(Constants.WSTETH).getStETHByWstETH(1 ether));

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

        IDepositQueue(address(vault.queueAt(Constants.ETH, 0))).deposit{value: 0.001 ether}(
            0.001 ether, address(0), new bytes32[](0)
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
                redeemQueueAssets: ArraysLibrary.makeAddressArray(abi.encode(Constants.WSTETH)),
                subvaultVerifiers: verifiers,
                timelockControllers: ArraysLibrary.makeAddressArray(abi.encode(address(timelockController))),
                timelockProposers: ArraysLibrary.makeAddressArray(abi.encode(lazyVaultAdmin, deployer)),
                timelockExecutors: ArraysLibrary.makeAddressArray(abi.encode(pauser))
            }),
            AcceptanceLibrary.OracleSubmitterDeployment({
                oracleSubmitter: oracleSubmitter,
                admin: lazyVaultAdmin,
                submitter: oracleUpdater,
                accepter: activeVaultAdmin
            })
        );

        revert("ok");
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

    function _createSubvault0Proofs(address subvault, address swapModule)
        internal
        returns (bytes32 merkleRoot, SubvaultCalls memory calls)
    {
        string[] memory descriptions = rstETHPlusLibrary.getSubvault0Descriptions(curator, subvault, swapModule);
        IVerifier.VerificationPayload[] memory leaves;
        (merkleRoot, leaves) = rstETHPlusLibrary.getSubvault0Proofs(curator, subvault, swapModule);
        ProofLibrary.storeProofs("ethereum:rstETH+:subvault0", merkleRoot, leaves, descriptions);
        calls = rstETHPlusLibrary.getSubvault0Calls(curator, subvault, swapModule, leaves);
    }

    function _createSubvault1Proofs(address subvault, address capSymbioticVault)
        internal
        returns (bytes32 merkleRoot, SubvaultCalls memory calls)
    {
        string[] memory descriptions = rstETHPlusLibrary.getSubvault1Descriptions(curator, subvault, capSymbioticVault);
        IVerifier.VerificationPayload[] memory leaves;
        (merkleRoot, leaves) = rstETHPlusLibrary.getSubvault1Proofs(curator, subvault, capSymbioticVault);
        ProofLibrary.storeProofs("ethereum:rstETH+:subvault1", merkleRoot, leaves, descriptions);
        calls = rstETHPlusLibrary.getSubvault1Calls(curator, subvault, capSymbioticVault, leaves);
    }

    function _createSubvault2Proofs(address subvault, address swapModule)
        internal
        returns (bytes32 merkleRoot, SubvaultCalls memory calls)
    {
        string[] memory descriptions = rstETHPlusLibrary.getSubvault2Descriptions(curator, subvault, swapModule);
        IVerifier.VerificationPayload[] memory leaves;
        (merkleRoot, leaves) = rstETHPlusLibrary.getSubvault2Proofs(curator, subvault, swapModule);
        ProofLibrary.storeProofs("ethereum:rstETH+:subvault2", merkleRoot, leaves, descriptions);
        calls = rstETHPlusLibrary.getSubvault2Calls(curator, subvault, swapModule, leaves);
    }

    function _routers() internal pure returns (address[5] memory result) {
        result = [
            address(0x1231DEB6f5749EF6cE6943a275A1D3E7486F4EaE),
            address(0x2C0552e5dCb79B064Fd23E358A86810BC5994244),
            address(0xF6801D319497789f934ec7F83E142a9536312B08),
            address(0x6131B5fae19EA4f9D964eAc0408E4408b66337b5),
            address(0x179dC3fb0F2230094894317f307241A52CdB38Aa)
        ];
    }

    function _deploySwapModule0(address subvault) internal returns (address) {
        return _deployLidoLeverageSwapModule(subvault);
    }

    function _deploySwapModule2(address subvault) internal returns (address) {
        return _deployCapResolvLeverageSwapModule(subvault);
    }

    function _deployLidoLeverageSwapModule(address subvault) internal returns (address) {
        IFactory swapModuleFactory = Constants.protocolDeployment().swapModuleFactory;
        address[2] memory assets = [Constants.WETH, Constants.WSTETH];
        address[] memory actors = ArraysLibrary.makeAddressArray(abi.encode(curator, assets, assets, _routers()));
        bytes32[] memory permissions = ArraysLibrary.makeBytes32Array(
            abi.encode(
                Permissions.SWAP_MODULE_CALLER_ROLE,
                Permissions.SWAP_MODULE_TOKEN_IN_ROLE,
                Permissions.SWAP_MODULE_TOKEN_IN_ROLE,
                Permissions.SWAP_MODULE_TOKEN_OUT_ROLE,
                Permissions.SWAP_MODULE_TOKEN_OUT_ROLE,
                Permissions.SWAP_MODULE_ROUTER_ROLE,
                Permissions.SWAP_MODULE_ROUTER_ROLE,
                Permissions.SWAP_MODULE_ROUTER_ROLE,
                Permissions.SWAP_MODULE_ROUTER_ROLE,
                Permissions.SWAP_MODULE_ROUTER_ROLE
            )
        );
        return swapModuleFactory.create(
            0,
            proxyAdmin,
            abi.encode(lazyVaultAdmin, subvault, Constants.AAVE_V3_ORACLE, DEFAULT_MULTIPLIER, actors, permissions)
        );
    }

    function _deployCapResolvLeverageSwapModule(address subvault) internal returns (address) {
        IFactory swapModuleFactory = Constants.protocolDeployment().swapModuleFactory;
        address[2] memory assets = [Constants.WSTETH, Constants.USDC];
        address[] memory actors = ArraysLibrary.makeAddressArray(abi.encode(curator, assets, assets, _routers()));
        bytes32[] memory permissions = ArraysLibrary.makeBytes32Array(
            abi.encode(
                Permissions.SWAP_MODULE_CALLER_ROLE,
                Permissions.SWAP_MODULE_TOKEN_IN_ROLE,
                Permissions.SWAP_MODULE_TOKEN_IN_ROLE,
                Permissions.SWAP_MODULE_TOKEN_OUT_ROLE,
                Permissions.SWAP_MODULE_TOKEN_OUT_ROLE,
                Permissions.SWAP_MODULE_ROUTER_ROLE,
                Permissions.SWAP_MODULE_ROUTER_ROLE,
                Permissions.SWAP_MODULE_ROUTER_ROLE,
                Permissions.SWAP_MODULE_ROUTER_ROLE,
                Permissions.SWAP_MODULE_ROUTER_ROLE
            )
        );
        return swapModuleFactory.create(
            0,
            proxyAdmin,
            abi.encode(lazyVaultAdmin, subvault, Constants.AAVE_V3_ORACLE, DEFAULT_MULTIPLIER, actors, permissions)
        );
    }

    function _deploySubvault1(address deployer, Vault vault) internal returns (SubvaultCalls memory) {
        // The subvault 2 is an agent in the Cap deployment for the symbiotic vault, that is used by the subvault 1.
        (address capSymbioticVault,,,, address stakerRewards) = ICapFactory(Constants.CAP_FACTORY).createVault(
            deployer, Constants.WSTETH, vault.subvaultAt(2), Constants.CAP_NETWORK
        );

        console2.log("Symbiotic Cap Vault", capSymbioticVault);
        console2.log("Symbiotic Cap StakerRewards", stakerRewards);

        {
            ISymbioticVaultPermissions sv = ISymbioticVaultPermissions(capSymbioticVault);

            sv.setDepositWhitelist(true);
            // God, fix stack-too-deep please
            sv.setDepositorWhitelistStatus(vault.subvaultAt(1), true);

            sv.grantRole(0x00, lazyVaultAdmin);
            sv.renounceRole(0x00, deployer);
            sv.renounceRole(sv.DEPOSIT_WHITELIST_SET_ROLE(), deployer);
            sv.renounceRole(sv.DEPOSITOR_WHITELIST_ROLE(), deployer);
            sv.renounceRole(sv.IS_DEPOSIT_LIMIT_SET_ROLE(), deployer);
            sv.renounceRole(sv.DEPOSIT_LIMIT_SET_ROLE(), deployer);
        }

        {
            ISymbioticStakerRewardsPermissions sr = ISymbioticStakerRewardsPermissions(stakerRewards);
            sr.grantRole(0x00, lazyVaultAdmin);
            sr.renounceRole(0x00, deployer);
            sr.renounceRole(sr.ADMIN_FEE_CLAIM_ROLE(), deployer);
            sr.renounceRole(sr.ADMIN_FEE_SET_ROLE(), deployer);
        }

        uint256 subvaultIndex = 1;
        address subvault = vault.subvaultAt(subvaultIndex);
        (bytes32 merkleRoot1, SubvaultCalls memory calls) = _createSubvault1Proofs(subvault, capSymbioticVault);
        IVerifierModule(vault.subvaultAt(subvaultIndex)).verifier().setMerkleRoot(merkleRoot1);

        IRiskManager riskManager = vault.riskManager();
        riskManager.allowSubvaultAssets(subvault, ArraysLibrary.makeAddressArray(abi.encode(Constants.WSTETH)));
        riskManager.setSubvaultLimit(subvault, type(int256).max / 2);
        return calls;
    }
}
