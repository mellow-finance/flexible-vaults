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
import "forge-std/Test.sol";

import "./Constants.sol";
import "./strETHLibrary.sol";

import "../common/ArraysLibrary.sol";

contract Deploy is Script, Test {
    // Actors

    address test = 0x5Dbf9287787A5825beCb0321A276C9c92d570a75;
    address public proxyAdmin = test;
    address public lazyVaultAdmin = test;
    address public activeVaultAdmin = test;
    address public oracleUpdater = test;
    address public curator = test;
    address public treasury = test;

    address public pauser = test;

    uint256 public constant DEFAULT_MULTIPLIER = 0.995e8;

    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);

        vm.startBroadcast(deployerPk);

        Vault.RoleHolder[] memory holders = new Vault.RoleHolder[](42);
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
        address[] memory assets_ =
            ArraysLibrary.makeAddressArray(abi.encode(Constants.ETH, Constants.WETH, Constants.WSTETH));

        ProtocolDeployment memory $ = Constants.protocolDeployment();
        VaultConfigurator.InitParams memory initParams = VaultConfigurator.InitParams({
            version: 0,
            proxyAdmin: proxyAdmin,
            vaultAdmin: lazyVaultAdmin,
            shareManagerVersion: 0,
            shareManagerParams: abi.encode(bytes32(0), "Mellow UI Test Vault", "MUITV"),
            feeManagerVersion: 0,
            feeManagerParams: abi.encode(deployer, treasury, uint24(0), uint24(0), uint24(0), uint24(0)),
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
            queueLimit: 3,
            roleHolders: holders
        });

        Vault vault;
        {
            (,,,, address vault_) = $.vaultConfigurator.create(initParams);
            vault = Vault(payable(vault_));
        }

        // queues setup
        vault.createQueue(0, true, proxyAdmin, Constants.ETH, new bytes(0));
        vault.createQueue(0, true, proxyAdmin, Constants.WSTETH, new bytes(0));
        vault.createQueue(0, false, proxyAdmin, Constants.WSTETH, new bytes(0));

        // fee manager setup
        vault.feeManager().setBaseAsset(address(vault), Constants.ETH);
        Ownable(address(vault.feeManager())).transferOwnership(lazyVaultAdmin);

        // subvault setup
        address[] memory verifiers = new address[](2);
        SubvaultCalls[] memory calls = new SubvaultCalls[](2);

        IRiskManager riskManager = vault.riskManager();
        {
            uint256 subvaultIndex = 0;
            verifiers[subvaultIndex] = $.verifierFactory.create(0, proxyAdmin, abi.encode(vault, bytes32(0)));
            address subvault = vault.createSubvault(0, proxyAdmin, verifiers[subvaultIndex]); // eth,weth,wsteth

            address swapModule = _deploySwapModule0(subvault);
            bytes32 merkleRoot;
            (merkleRoot, calls[subvaultIndex]) = _createSubvault0Verifier(vault.subvaultAt(0), swapModule);
            IVerifier(verifiers[subvaultIndex]).setMerkleRoot(merkleRoot);
            riskManager.allowSubvaultAssets(subvault, assets_);
            riskManager.setSubvaultLimit(subvault, type(int256).max / 2);
        }
        {
            uint256 subvaultIndex = 1;
            verifiers[subvaultIndex] = $.verifierFactory.create(0, proxyAdmin, abi.encode(vault, bytes32(0)));
            address subvault = vault.createSubvault(0, proxyAdmin, verifiers[subvaultIndex]); // wsteth, weth

            address swapModule = _deploySwapModule1(subvault);
            bytes32 merkleRoot;
            (merkleRoot, calls[subvaultIndex]) = _createSubvault1Verifier(subvault, swapModule);
            IVerifier(verifiers[subvaultIndex]).setMerkleRoot(merkleRoot);
            riskManager.allowSubvaultAssets(
                subvault, ArraysLibrary.makeAddressArray(abi.encode(Constants.WETH, Constants.WSTETH))
            );
            riskManager.setSubvaultLimit(subvault, type(int256).max / 2);
        }

        vault.renounceRole(Permissions.CREATE_QUEUE_ROLE, deployer);
        vault.renounceRole(Permissions.CREATE_SUBVAULT_ROLE, deployer);
        vault.renounceRole(Permissions.SET_VAULT_LIMIT_ROLE, deployer);
        vault.renounceRole(Permissions.ALLOW_SUBVAULT_ASSETS_ROLE, deployer);
        vault.renounceRole(Permissions.SET_SUBVAULT_LIMIT_ROLE, deployer);
        vault.renounceRole(Permissions.SET_MERKLE_ROOT_ROLE, deployer);

        console2.log("Vault %s", address(vault));

        console2.log("DepositQueue (ETH) %s", address(vault.queueAt(Constants.ETH, 0)));
        console2.log("DepositQueue (WSTETH) %s", address(vault.queueAt(Constants.WSTETH, 0)));
        console2.log("RedeemQueue (WSTETH) %s", address(vault.queueAt(Constants.WSTETH, 1)));

        console2.log("Oracle %s", address(vault.oracle()));
        console2.log("ShareManager %s", address(vault.shareManager()));
        console2.log("FeeManager %s", address(vault.feeManager()));
        console2.log("RiskManager %s", address(vault.riskManager()));

        for (uint256 i = 0; i < vault.subvaults(); i++) {
            address subvault = vault.subvaultAt(i);
            console2.log("Subvault %s %s", i, subvault);
            console2.log("Verifier %s %s", i, address(Subvault(payable(subvault)).verifier()));
        }

        {
            IOracle.Report[] memory reports = new IOracle.Report[](assets_.length);
            for (uint256 i = 0; i < reports.length; i++) {
                reports[i].asset = assets_[i];
            }
            reports[0].priceD18 = 1 ether;
            reports[1].priceD18 = 1 ether;
            reports[2].priceD18 = uint224(WSTETHInterface(Constants.WSTETH).getStETHByWstETH(1 ether));
            IOracle oracle = vault.oracle();
            oracle.submitReports(reports);
            uint256 timestamp = oracle.getReport(Constants.ETH).timestamp;
            for (uint256 i = 0; i < reports.length; i++) {
                oracle.acceptReport(reports[i].asset, reports[i].priceD18, uint32(timestamp));
            }
        }

        vm.stopBroadcast();
    }

    function _createSubvault0Verifier(address subvault, address swapModule)
        internal
        returns (bytes32 merkleRoot, SubvaultCalls memory calls)
    {
        console2.log("SwapModule 0: %s", swapModule);
        string[] memory descriptions = strETHLibrary.getSubvault0Descriptions(curator, subvault, swapModule);
        IVerifier.VerificationPayload[] memory leaves;
        (merkleRoot, leaves) = strETHLibrary.getSubvault0Proofs(curator, subvault, swapModule);
        ProofLibrary.storeProofs("ethereum:MUITV:subvault0", merkleRoot, leaves, descriptions);
        calls = strETHLibrary.getSubvault0SubvaultCalls(curator, subvault, swapModule, leaves);
    }

    function _createSubvault1Verifier(address subvault, address swapModule)
        internal
        returns (bytes32 merkleRoot, SubvaultCalls memory calls)
    {
        console2.log("SwapModule 1: %s", swapModule);
        string[] memory descriptions = strETHLibrary.getSubvault1Descriptions(curator, subvault, swapModule);
        IVerifier.VerificationPayload[] memory leaves;
        (merkleRoot, leaves) = strETHLibrary.getSubvault1Proofs(curator, subvault, swapModule);
        ProofLibrary.storeProofs("ethereum:MUITV:subvault1", merkleRoot, leaves, descriptions);
        calls = strETHLibrary.getSubvault1SubvaultCalls(curator, subvault, swapModule, leaves);
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

    function _deploySwapModule1(address subvault) internal returns (address swapModule) {
        return _deployLidoLeverageSwapModule(subvault);
    }

    function _deployLidoLeverageSwapModule(address subvault) internal returns (address) {
        IFactory swapModuleFactory = Constants.protocolDeployment().swapModuleFactory;
        address[2] memory lidoLeverage = [Constants.WETH, Constants.WSTETH];
        address[] memory actors =
            ArraysLibrary.makeAddressArray(abi.encode(curator, lidoLeverage, lidoLeverage, _routers()));
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
}
