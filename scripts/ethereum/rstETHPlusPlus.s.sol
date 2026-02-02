// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

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

import {rstETHPlusPlusLibrary} from "./rstETHPlusPlusLibrary.sol";

contract Deploy is Script, Test {
    // Actors

    address public proxyAdmin = 0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0;
    address public lazyVaultAdmin = 0x0Fb1fe5b41cBA3c01BBF48f73bC82b19f32b3053;
    address public activeVaultAdmin = 0x65D692F223bC78da7024a0f0e018D9F35AB45472;
    address public oracleUpdater = 0xAed4BE0D6E933249F833cfF64600e3fB33597B82;
    address public curator = 0x1280e86Cd7787FfA55d37759C0342F8CD3c7594a;

    address public feeManagerOwner = 0x1D2d56EeA41488413cC11441a79F7fF444d469d4;

    address public pauser = 0x3B8Ad20814f782F5681C050eff66F3Df9dF0D0FF;

    uint256 public constant DEFAULT_MULTIPLIER = 0.995e8;

    function getMerkleRoot(uint256 subvaultIndex) public pure returns (bytes32) {
        if (subvaultIndex == 0) {
            return 0xbca74c74fb91cafed614154f2c8fe71a79f6bf87b3f5c8fd0dfe2485cd8d0e9c;
        } else if (subvaultIndex == 1) {
            return 0x31448edbe5cea82f8b9e0636c855b479dc4771973ee5ac2f264376718b90391c;
        } else if (subvaultIndex == 2) {
            return 0x3e9ed6f426697501b8f2c6b5a2af4512524e2cecf6cf3f3c2f5a9e680396ab67;
        } else {
            revert("Invalid subvaultIndex");
        }
    }

    bytes32 public constant FUND_ROLE = keccak256("vaults.Permissions.Fund");
    bytes32 public constant WITHDRAW_ROLE = keccak256("vaults.Permissions.Withdraw");
    bytes32 public constant MINT_ROLE = keccak256("vaults.Permissions.Mint");
    bytes32 public constant BURN_ROLE = keccak256("vaults.Permissions.Burn");
    bytes32 public constant REBALANCE_ROLE = keccak256("vaults.Permissions.Rebalance");
    bytes32 public constant PAUSE_BEACON_CHAIN_DEPOSITS_ROLE = keccak256("vaults.Permissions.PauseDeposits");
    bytes32 public constant RESUME_BEACON_CHAIN_DEPOSITS_ROLE = keccak256("vaults.Permissions.ResumeDeposits");
    bytes32 public constant REQUEST_VALIDATOR_EXIT_ROLE = keccak256("vaults.Permissions.RequestValidatorExit");
    bytes32 public constant TRIGGER_VALIDATOR_WITHDRAWAL_ROLE =
        keccak256("vaults.Permissions.TriggerValidatorWithdrawal");
    bytes32 public constant VOLUNTARY_DISCONNECT_ROLE = keccak256("vaults.Permissions.VoluntaryDisconnect");
    bytes32 public constant VAULT_CONFIGURATION_ROLE = keccak256("vaults.Permissions.VaultConfiguration");
    bytes32 public constant COLLECT_VAULT_ERC20_ROLE = keccak256("vaults.Dashboard.CollectVaultERC20");
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    bytes32 public constant NODE_OPERATOR_MANAGER_ROLE = keccak256("vaults.NodeOperatorFee.NodeOperatorManagerRole");
    bytes32 public constant NODE_OPERATOR_FEE_EXEMPT_ROLE = keccak256("vaults.NodeOperatorFee.FeeExemptRole");
    bytes32 public constant NODE_OPERATOR_UNGUARANTEED_DEPOSIT_ROLE =
        keccak256("vaults.NodeOperatorFee.UnguaranteedDepositRole");
    bytes32 public constant NODE_OPERATOR_PROVE_UNKNOWN_VALIDATOR_ROLE =
        keccak256("vaults.NodeOperatorFee.ProveUnknownValidatorsRole");

    function logLidoV3Permissions(address d) internal view {
        bytes32[17] memory roles = [
            FUND_ROLE,
            WITHDRAW_ROLE,
            MINT_ROLE,
            BURN_ROLE,
            REBALANCE_ROLE,
            PAUSE_BEACON_CHAIN_DEPOSITS_ROLE,
            RESUME_BEACON_CHAIN_DEPOSITS_ROLE,
            REQUEST_VALIDATOR_EXIT_ROLE,
            TRIGGER_VALIDATOR_WITHDRAWAL_ROLE,
            VOLUNTARY_DISCONNECT_ROLE,
            VAULT_CONFIGURATION_ROLE,
            COLLECT_VAULT_ERC20_ROLE,
            DEFAULT_ADMIN_ROLE,
            NODE_OPERATOR_MANAGER_ROLE,
            NODE_OPERATOR_FEE_EXEMPT_ROLE,
            NODE_OPERATOR_UNGUARANTEED_DEPOSIT_ROLE,
            NODE_OPERATOR_PROVE_UNKNOWN_VALIDATOR_ROLE
        ];

        string[17] memory roleNames = [
            "FUND_ROLE",
            "WITHDRAW_ROLE",
            "MINT_ROLE",
            "BURN_ROLE",
            "REBALANCE_ROLE",
            "PAUSE_BEACON_CHAIN_DEPOSITS_ROLE",
            "RESUME_BEACON_CHAIN_DEPOSITS_ROLE",
            "REQUEST_VALIDATOR_EXIT_ROLE",
            "TRIGGER_VALIDATOR_WITHDRAWAL_ROLE",
            "VOLUNTARY_DISCONNECT_ROLE",
            "VAULT_CONFIGURATION_ROLE",
            "COLLECT_VAULT_ERC20_ROLE",
            "DEFAULT_ADMIN_ROLE",
            "NODE_OPERATOR_MANAGER_ROLE",
            "NODE_OPERATOR_FEE_EXEMPT_ROLE",
            "NODE_OPERATOR_UNGUARANTEED_DEPOSIT_ROLE",
            "NODE_OPERATOR_PROVE_UNKNOWN_VALIDATOR_ROLE"
        ];

        for (uint256 i = 0; i < roles.length; i++) {
            bytes32 role = roles[i];
            address[] memory members = AccessControlEnumerable(d).getRoleMembers(role);
            for (uint256 j = 0; j < members.length; j++) {
                console2.log("LidoV3 dashboard: user %s holds role %s", members[j], roleNames[i]);
            }
        }
    }

    function logAllowedAssetsAndLimits(Vault vault) internal view {
        IRiskManager riskManager = vault.riskManager();

        for (uint256 i = 0; i < vault.subvaults(); i++) {
            address subvault = vault.subvaultAt(i);
            uint256 n = riskManager.allowedAssets(subvault);
            console2.log("subvault %s limit: %s", i, uint256(riskManager.subvaultState(subvault).limit));
            for (uint256 j = 0; j < n; j++) {
                address allowedAsset = riskManager.allowedAssetAt(subvault, j);
                string memory asset = allowedAsset == Constants.ETH ? "ETH" : IERC20Metadata(allowedAsset).symbol();
                console2.log("subvault %s has allowed asset %s", i, asset);
            }
        }
    }

    function logMerkleRoots(Vault vault) internal view {
        for (uint256 i = 0; i < vault.subvaults(); i++) {
            address subvault = vault.subvaultAt(i);
            console2.log(
                "subvault %s has merkle root %s", i, vm.toString(IVerifierModule(subvault).verifier().merkleRoot())
            );
        }
    }

    bytes32 public constant TOKEN_IN_ROLE = keccak256("utils.SwapModule.TOKEN_IN_ROLE");
    bytes32 public constant TOKEN_OUT_ROLE = keccak256("utils.SwapModule.TOKEN_OUT_ROLE");
    bytes32 public constant ROUTER_ROLE = keccak256("utils.SwapModule.ROUTER_ROLE");
    bytes32 public constant CALLER_ROLE = keccak256("utils.SwapModule.CALLER_ROLE");
    bytes32 public constant SET_SLIPPAGE_ROLE = keccak256("utils.SwapModule.SET_SLIPPAGE_ROLE");

    function logSwapModulePermissions(address s) internal view {
        bytes32[6] memory roles =
            [DEFAULT_ADMIN_ROLE, TOKEN_IN_ROLE, TOKEN_OUT_ROLE, ROUTER_ROLE, CALLER_ROLE, SET_SLIPPAGE_ROLE];
        string[6] memory roleNames =
            ["DEFAULT_ADMIN_ROLE", "TOKEN_IN_ROLE", "TOKEN_OUT_ROLE", "ROUTER_ROLE", "CALLER_ROLE", "SET_SLIPPAGE_ROLE"];
        for (uint256 i = 0; i < roles.length; i++) {
            bytes32 role = roles[i];
            address[] memory members = AccessControlEnumerable(s).getRoleMembers(role);
            for (uint256 j = 0; j < members.length; j++) {
                console2.log("SwapModule %s: user %s holds role %s", s, members[j], roleNames[i]);
            }
        }
    }

    function logOracleAssets(IOracle oracle) internal view {
        for (uint256 i = 0; i < oracle.supportedAssets(); i++) {
            address supportedAsset = oracle.supportedAssetAt(i);

            string memory asset = supportedAsset == Constants.ETH ? "ETH" : IERC20Metadata(supportedAsset).symbol();
            console2.log("oracle has supported asset %s", asset);
        }
    }

    function logCall(address target, bytes memory data) internal pure {
        console2.log("{");
        console2.log('  "to": "%s",', target);
        console2.log('  "value": "0",');
        console2.log('  "data": "%s",', vm.toString(data));
        console2.log('  "contractMethod": {');
        console2.log('    "inputs": [],');
        console2.log('     "name": "fallback",');
        console2.log('     "payable": true');
        console2.log("  },");
        console2.log('  "contractInputsValues": null');
        console2.log("},");
    }

    function migrate(Vault vault, IAccessControl dashboard, SwapModule swapModule) internal {
        RiskManager riskManager = RiskManager(address(vault.riskManager()));
        address subvault0 = vault.subvaultAt(0);
        address subvault1 = vault.subvaultAt(1);
        address subvault2 = vault.subvaultAt(2);

        vm.startPrank(lazyVaultAdmin);

        logCall(
            address(vault),
            abi.encodeCall(vault.grantRole, (riskManager.DISALLOW_SUBVAULT_ASSETS_ROLE(), lazyVaultAdmin))
        );
        vault.grantRole(riskManager.DISALLOW_SUBVAULT_ASSETS_ROLE(), lazyVaultAdmin);

        logCall(
            address(vault), abi.encodeCall(vault.grantRole, (riskManager.ALLOW_SUBVAULT_ASSETS_ROLE(), lazyVaultAdmin))
        );
        vault.grantRole(riskManager.ALLOW_SUBVAULT_ASSETS_ROLE(), lazyVaultAdmin);

        logCall(
            address(riskManager),
            abi.encodeCall(
                riskManager.disallowSubvaultAssets,
                (subvault1, ArraysLibrary.makeAddressArray(abi.encode(Constants.WSTETH, Constants.RSETH)))
            )
        );
        riskManager.disallowSubvaultAssets(
            subvault1, ArraysLibrary.makeAddressArray(abi.encode(Constants.WSTETH, Constants.RSETH))
        );

        logCall(
            address(riskManager),
            abi.encodeCall(
                riskManager.disallowSubvaultAssets,
                (subvault2, ArraysLibrary.makeAddressArray(abi.encode(Constants.WSTETH)))
            )
        );
        riskManager.disallowSubvaultAssets(subvault2, ArraysLibrary.makeAddressArray(abi.encode(Constants.WSTETH)));

        logCall(
            address(riskManager),
            abi.encodeCall(
                riskManager.allowSubvaultAssets,
                (subvault2, ArraysLibrary.makeAddressArray(abi.encode(Constants.ETH, Constants.WETH)))
            )
        );
        riskManager.allowSubvaultAssets(
            subvault2, ArraysLibrary.makeAddressArray(abi.encode(Constants.ETH, Constants.WETH))
        );

        logCall(
            address(IVerifierModule(subvault0).verifier()),
            abi.encodeCall(IVerifierModule(subvault0).verifier().setMerkleRoot, (getMerkleRoot(0)))
        );
        IVerifierModule(subvault0).verifier().setMerkleRoot(getMerkleRoot(0));

        logCall(
            address(IVerifierModule(subvault1).verifier()),
            abi.encodeCall(IVerifierModule(subvault1).verifier().setMerkleRoot, (getMerkleRoot(1)))
        );
        IVerifierModule(subvault1).verifier().setMerkleRoot(getMerkleRoot(1));

        logCall(
            address(IVerifierModule(subvault2).verifier()),
            abi.encodeCall(IVerifierModule(subvault2).verifier().setMerkleRoot, (getMerkleRoot(2)))
        );
        IVerifierModule(subvault2).verifier().setMerkleRoot(getMerkleRoot(2));

        logCall(address(dashboard), abi.encodeCall(dashboard.revokeRole, (FUND_ROLE, address(swapModule))));
        dashboard.revokeRole(FUND_ROLE, address(swapModule));

        logCall(address(dashboard), abi.encodeCall(dashboard.revokeRole, (WITHDRAW_ROLE, address(swapModule))));
        dashboard.revokeRole(WITHDRAW_ROLE, address(swapModule));

        logCall(address(dashboard), abi.encodeCall(dashboard.revokeRole, (MINT_ROLE, address(swapModule))));
        dashboard.revokeRole(MINT_ROLE, address(swapModule));

        logCall(address(dashboard), abi.encodeCall(dashboard.revokeRole, (BURN_ROLE, address(swapModule))));
        dashboard.revokeRole(BURN_ROLE, address(swapModule));

        logCall(address(dashboard), abi.encodeCall(dashboard.revokeRole, (REBALANCE_ROLE, address(swapModule))));
        dashboard.revokeRole(REBALANCE_ROLE, address(swapModule));

        logCall(address(dashboard), abi.encodeCall(dashboard.grantRole, (FUND_ROLE, address(subvault0))));
        dashboard.grantRole(FUND_ROLE, subvault0);

        logCall(address(dashboard), abi.encodeCall(dashboard.grantRole, (WITHDRAW_ROLE, address(subvault0))));
        dashboard.grantRole(WITHDRAW_ROLE, address(subvault0));

        logCall(address(dashboard), abi.encodeCall(dashboard.grantRole, (MINT_ROLE, address(subvault0))));
        dashboard.grantRole(MINT_ROLE, address(subvault0));

        logCall(address(dashboard), abi.encodeCall(dashboard.grantRole, (BURN_ROLE, address(subvault0))));
        dashboard.grantRole(BURN_ROLE, address(subvault0));

        logCall(address(dashboard), abi.encodeCall(dashboard.grantRole, (REBALANCE_ROLE, address(subvault0))));
        dashboard.grantRole(REBALANCE_ROLE, address(subvault0));

        vm.stopPrank();
    }

    function upgradePermissions() internal {
        address dashboard = 0xfF1e3a07dF140A6d7207865414D22335B2B263b1;
        Vault vault = Vault(payable(0xd41f177Ec448476d287635CD3AE21457F94c2307));
        address swapModule = 0x2BC798BE6610df25c0255e4C054cbb35F8e99A71;

        migrate(vault, IAccessControl(dashboard), SwapModule(payable(swapModule)));

        logAllowedAssetsAndLimits(vault);
        console2.log();

        logMerkleRoots(vault);

        console2.log();
        logSwapModulePermissions(swapModule);
        console2.log();
        logOracleAssets(vault.oracle());
        console2.log();
        logLidoV3Permissions(dashboard);
        console2.log();
    }

    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);

        if (true) {
            upgradePermissions();
            return;
        }

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
        address[] memory assets_ = ArraysLibrary.makeAddressArray(
            abi.encode(Constants.ETH, Constants.WETH, Constants.WSTETH, Constants.RSETH, Constants.WEETH)
        );

        ProtocolDeployment memory $ = Constants.protocolDeployment();
        VaultConfigurator.InitParams memory initParams = VaultConfigurator.InitParams({
            version: 0,
            proxyAdmin: proxyAdmin,
            vaultAdmin: lazyVaultAdmin,
            shareManagerVersion: 0,
            shareManagerParams: abi.encode(bytes32(0), "Restaking Vault ETH++", "rstETH++"),
            feeManagerVersion: 0,
            feeManagerParams: abi.encode(deployer, feeManagerOwner, uint24(0), uint24(0), uint24(75e3), uint24(15e3)),
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
            IRiskManager riskManager = vault.riskManager();
            uint256 subvaultIndex = 1;
            verifiers[subvaultIndex] = $.verifierFactory.create(0, proxyAdmin, abi.encode(vault, bytes32(0)));
            address subvault = vault.createSubvault(0, proxyAdmin, verifiers[subvaultIndex]);

            bytes32 merkleRoot;
            (merkleRoot, calls[subvaultIndex]) = _createSubvault1Proofs(subvault);
            IVerifier(verifiers[subvaultIndex]).setMerkleRoot(merkleRoot);

            riskManager.allowSubvaultAssets(
                subvault,
                ArraysLibrary.makeAddressArray(
                    abi.encode(Constants.WSTETH, Constants.WEETH, Constants.RSETH, Constants.WETH)
                )
            );
            riskManager.setSubvaultLimit(subvault, type(int256).max / 2);
        }

        {
            IRiskManager riskManager = vault.riskManager();
            uint256 subvaultIndex = 2;
            verifiers[subvaultIndex] = $.verifierFactory.create(0, proxyAdmin, abi.encode(vault, bytes32(0)));
            address subvault = vault.createSubvault(0, proxyAdmin, verifiers[subvaultIndex]);

            bytes32 merkleRoot;
            (merkleRoot, calls[subvaultIndex]) = _createSubvault2Proofs(subvault);
            IVerifier(verifiers[subvaultIndex]).setMerkleRoot(merkleRoot);

            riskManager.allowSubvaultAssets(
                subvault, ArraysLibrary.makeAddressArray(abi.encode(Constants.WSTETH, Constants.RSETH))
            );
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
            reports[2].priceD18 = uint224(getEthAssetPrice(Constants.WSTETH));
            reports[3].priceD18 = uint224(getEthAssetPrice(Constants.RSETH));
            reports[4].priceD18 = uint224(getEthAssetPrice(Constants.WEETH));

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
                depositQueueAssets: ArraysLibrary.makeAddressArray(
                    abi.encode(Constants.ETH, Constants.WETH, Constants.WSTETH)
                ),
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

    function getEthAssetPrice(address asset) public view returns (uint256) {
        uint256 priceD8 = IAaveOracle(Constants.AAVE_V3_ORACLE).getAssetPrice(asset);
        uint256 ethPriceD8 = IAaveOracle(Constants.AAVE_V3_ORACLE).getAssetPrice(Constants.WETH);
        return Math.mulDiv(1 ether, priceD8, ethPriceD8);
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
        string[] memory descriptions = rstETHPlusPlusLibrary.getSubvault0Descriptions(curator, subvault, swapModule);
        IVerifier.VerificationPayload[] memory leaves;
        (merkleRoot, leaves) = rstETHPlusPlusLibrary.getSubvault0Proofs(curator, subvault, swapModule);
        ProofLibrary.storeProofs("ethereum:rstETH++:subvault0", merkleRoot, leaves, descriptions);
        calls = rstETHPlusPlusLibrary.getSubvault0Calls(curator, subvault, swapModule, leaves);
    }

    function _createSubvault1Proofs(address subvault)
        internal
        returns (bytes32 merkleRoot, SubvaultCalls memory calls)
    {
        string[] memory descriptions = rstETHPlusPlusLibrary.getSubvault1Descriptions(curator, subvault);
        IVerifier.VerificationPayload[] memory leaves;
        (merkleRoot, leaves) = rstETHPlusPlusLibrary.getSubvault1Proofs(curator, subvault);
        ProofLibrary.storeProofs("ethereum:rstETH++:subvault1", merkleRoot, leaves, descriptions);
        calls = rstETHPlusPlusLibrary.getSubvault1Calls(curator, subvault, leaves);
    }

    function _createSubvault2Proofs(address subvault)
        internal
        returns (bytes32 merkleRoot, SubvaultCalls memory calls)
    {
        string[] memory descriptions = rstETHPlusPlusLibrary.getSubvault2Descriptions(curator, subvault);
        IVerifier.VerificationPayload[] memory leaves;
        (merkleRoot, leaves) = rstETHPlusPlusLibrary.getSubvault2Proofs(curator, subvault);
        ProofLibrary.storeProofs("ethereum:rstETH++:subvault2", merkleRoot, leaves, descriptions);
        calls = rstETHPlusPlusLibrary.getSubvault2Calls(curator, subvault, leaves);
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

    function _deployLidoLeverageSwapModule(address subvault) internal returns (address) {
        IFactory swapModuleFactory = Constants.protocolDeployment().swapModuleFactory;
        address[5] memory assets = [Constants.ETH, Constants.WETH, Constants.WSTETH, Constants.WEETH, Constants.RSETH];
        address[] memory actors = ArraysLibrary.makeAddressArray(abi.encode(curator, assets, assets, _routers()));
        bytes32[] memory permissions = ArraysLibrary.makeBytes32Array(
            abi.encode(
                [
                    Permissions.SWAP_MODULE_CALLER_ROLE,
                    Permissions.SWAP_MODULE_TOKEN_IN_ROLE,
                    Permissions.SWAP_MODULE_TOKEN_IN_ROLE,
                    Permissions.SWAP_MODULE_TOKEN_IN_ROLE,
                    Permissions.SWAP_MODULE_TOKEN_IN_ROLE,
                    Permissions.SWAP_MODULE_TOKEN_IN_ROLE
                ],
                [
                    Permissions.SWAP_MODULE_TOKEN_OUT_ROLE,
                    Permissions.SWAP_MODULE_TOKEN_OUT_ROLE,
                    Permissions.SWAP_MODULE_TOKEN_OUT_ROLE,
                    Permissions.SWAP_MODULE_TOKEN_OUT_ROLE,
                    Permissions.SWAP_MODULE_TOKEN_OUT_ROLE,
                    Permissions.SWAP_MODULE_ROUTER_ROLE,
                    Permissions.SWAP_MODULE_ROUTER_ROLE,
                    Permissions.SWAP_MODULE_ROUTER_ROLE,
                    Permissions.SWAP_MODULE_ROUTER_ROLE,
                    Permissions.SWAP_MODULE_ROUTER_ROLE
                ]
            )
        );
        return swapModuleFactory.create(
            0,
            proxyAdmin,
            abi.encode(lazyVaultAdmin, subvault, Constants.AAVE_V3_ORACLE, DEFAULT_MULTIPLIER, actors, permissions)
        );
    }
}
