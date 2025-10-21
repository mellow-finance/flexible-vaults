// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../common/interfaces/ICowswapSettlement.sol";
import {IWETH as WETHInterface} from "../common/interfaces/IWETH.sol";
import {IWSTETH as WSTETHInterface} from "../common/interfaces/IWSTETH.sol";

import "../collectors/defi/external/IAaveOracleV3.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

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
    address public proxyAdmin = address(0xE98Be1E5538FCbD716C506052eB1Fd5d6fC495A3);
    address public lazyVaultAdmin = address(0x5Ee08C98FaD00C492Deba19e9d038fEFd275E8C0);
    address public activeVaultAdmin = address(0x5Ee08C98FaD00C492Deba19e9d038fEFd275E8C0);
    address public oracleUpdater = address(0x5Ee08C98FaD00C492Deba19e9d038fEFd275E8C0);
    address public curator = address(0x5Ee08C98FaD00C492Deba19e9d038fEFd275E8C0);
    address public pauser = address(0x5Ee08C98FaD00C492Deba19e9d038fEFd275E8C0);

    function run() external {
        _addAgentManagedSubvaults(curator);
        return;

        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);

        vm.startBroadcast(deployerPk);

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
            shareManagerParams: abi.encode(bytes32(0), "Theoriq AlphaVault ETH", "tqETH"),
            feeManagerVersion: 0,
            feeManagerParams: abi.encode(deployer, lazyVaultAdmin, uint24(0), uint24(0), uint24(1e5), uint24(1e4)),
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
        address verifier;
        SubvaultCalls[] memory calls = new SubvaultCalls[](1);

        {
            IRiskManager riskManager = vault.riskManager();
            (verifier, calls[0]) = _createCowswapVerifier(address(vault));
            vault.createSubvault(0, proxyAdmin, verifier); // eth,weth,wsteth
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

        timelockController.schedule(
            address(Subvault(payable(vault.subvaultAt(0))).verifier()),
            0,
            abi.encodeCall(IVerifier.setMerkleRoot, (bytes32(0))),
            bytes32(0),
            bytes32(0),
            0
        );

        address[6] memory queues = [
            vault.queueAt(Constants.WSTETH, 0),
            vault.queueAt(Constants.WSTETH, 1),
            vault.queueAt(Constants.WETH, 0),
            vault.queueAt(Constants.WETH, 1),
            vault.queueAt(Constants.ETH, 0),
            vault.queueAt(Constants.ETH, 1)
        ];
        for (uint256 i = 0; i < queues.length; i++) {
            timelockController.schedule(
                address(vault),
                0,
                abi.encodeCall(IShareModule.setQueueStatus, (queues[i], true)),
                bytes32(0),
                bytes32(0),
                0
            );
        }

        timelockController.renounceRole(timelockController.PROPOSER_ROLE(), deployer);
        timelockController.renounceRole(timelockController.CANCELLER_ROLE(), deployer);

        vault.renounceRole(Permissions.CREATE_QUEUE_ROLE, deployer);
        vault.renounceRole(Permissions.CREATE_SUBVAULT_ROLE, deployer);
        vault.renounceRole(Permissions.SET_VAULT_LIMIT_ROLE, deployer);
        vault.renounceRole(Permissions.ALLOW_SUBVAULT_ASSETS_ROLE, deployer);
        vault.renounceRole(Permissions.SET_SUBVAULT_LIMIT_ROLE, deployer);

        console2.log("Vault %s", address(vault));

        console2.log("DepositQueue (ETH) %s", address(vault.queueAt(Constants.ETH, 0)));
        console2.log("DepositQueue (WETH) %s", address(vault.queueAt(Constants.WETH, 0)));
        console2.log("DepositQueue (WSTETH) %s", address(vault.queueAt(Constants.WSTETH, 0)));

        console2.log("RedeemQueue (ETH) %s", address(vault.queueAt(Constants.ETH, 1)));
        console2.log("RedeemQueue (WETH) %s", address(vault.queueAt(Constants.WETH, 1)));
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
        console2.log("Timelock controller:", address(timelockController));

        {
            IOracle.Report[] memory reports = new IOracle.Report[](3);
            reports[0].asset = Constants.ETH;
            reports[0].priceD18 = 1 ether;

            reports[1].asset = Constants.WETH;
            reports[1].priceD18 = 1 ether;

            reports[2].asset = Constants.WSTETH;
            IAaveOracleV3 aaveOracle = IAaveOracleV3(Constants.AAVE_V3_ORACLE);
            reports[2].priceD18 = uint224(
                Math.mulDiv(
                    1 ether, aaveOracle.getAssetPrice(Constants.WETH), aaveOracle.getAssetPrice(Constants.WSTETH)
                )
            );
            IOracle oracle = vault.oracle();
            oracle.submitReports(reports);
            uint256 timestamp = oracle.getReport(Constants.ETH).timestamp;
            for (uint256 i = 0; i < reports.length; i++) {
                oracle.acceptReport(reports[i].asset, reports[i].priceD18, uint32(timestamp));
            }
        }

        vault.renounceRole(Permissions.SUBMIT_REPORTS_ROLE, deployer);
        vault.renounceRole(Permissions.ACCEPT_REPORT_ROLE, deployer);

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
                subvaultVerifiers: ArraysLibrary.makeAddressArray(abi.encode(verifier)),
                timelockControllers: ArraysLibrary.makeAddressArray(abi.encode(timelockController)),
                timelockProposers: ArraysLibrary.makeAddressArray(abi.encode(lazyVaultAdmin, deployer)),
                timelockExecutors: ArraysLibrary.makeAddressArray(abi.encode(lazyVaultAdmin))
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
        holders[i++] = Vault.RoleHolder(Permissions.CALLER_ROLE, curator);
        holders[i++] = Vault.RoleHolder(Permissions.PULL_LIQUIDITY_ROLE, curator);
        holders[i++] = Vault.RoleHolder(Permissions.PUSH_LIQUIDITY_ROLE, curator);

        assembly {
            mstore(holders, i)
        }
    }

    function _createCowswapVerifier(address vault) internal returns (address verifier, SubvaultCalls memory calls) {
        ProtocolDeployment memory $ = Constants.protocolDeployment();
        /*
            1. weth.deposit{value: <any>}();
            2. weth.withdraw(<any>);
            3. weth.approve(cowswapVaultRelayer, <any>);
            4. wsteth.approve(cowswapVaultRelayer, <any>);
            5. cowswapSettlement.setPreSignature(coswapOrderUid(owner=address(0)), anyBool);
            6. cowswapSettlement.invalidateOrder(anyBytes);
        */
        string[] memory descriptions = tqETHLibrary.getSubvault0Descriptions(curator);
        (bytes32 merkleRoot, IVerifier.VerificationPayload[] memory leaves) = tqETHLibrary.getSubvault0Proofs(curator);
        ProofLibrary.storeProofs("base:tqETH:subvault0", merkleRoot, leaves, descriptions);
        calls = tqETHLibrary.getSubvault0SubvaultCalls($, curator, leaves);
        verifier = $.verifierFactory.create(0, proxyAdmin, abi.encode(vault, merkleRoot));
    }

    function _deployAgentVerifiers(address agent) internal {
        address vault = 0xD014de79cCC9b09376261F106773824F91748a68;

        ProtocolDeployment memory $ = Constants.protocolDeployment();
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);
        console2.log("Deployer %s", deployer);
        vm.startBroadcast(deployerPk);
        for (uint256 i = 1; i < 3; i++) {
            string[] memory descriptions = tqETHLibraryV2.getSubvault0Descriptions(curator, agent);
            (bytes32 merkleRoot, IVerifier.VerificationPayload[] memory leaves) =
                tqETHLibraryV2.getSubvault0Proofs(curator, agent);
            ProofLibrary.storeProofs(
                string(abi.encodePacked("base:tqETH:subvault", Strings.toString(i))), merkleRoot, leaves, descriptions
            );

            address verifier = $.verifierFactory.create(0, proxyAdmin, abi.encode(vault, merkleRoot));
            console2.log("Verifier %s %s", i, verifier);
        }
        vm.stopBroadcast();
        revert("ok");
    }

    function _addAgentManagedSubvaults(address agent) internal {
        Vault vault = Vault(payable(0xD014de79cCC9b09376261F106773824F91748a68));
        address timelockController = 0xb4EDFD431aB522223c5499F1b2E7493fb211eF84;
        address deployer = 0xE98Be1E5538FCbD716C506052eB1Fd5d6fC495A3;

        vm.startPrank(lazyVaultAdmin);
        vault.grantRole(Permissions.CREATE_SUBVAULT_ROLE, lazyVaultAdmin);
        vault.grantRole(Permissions.SET_HOOK_ROLE, lazyVaultAdmin);

        vault.grantRole(Permissions.CALLER_ROLE, agent);
        vault.grantRole(Permissions.PULL_LIQUIDITY_ROLE, agent);
        vault.grantRole(Permissions.PUSH_LIQUIDITY_ROLE, agent);

        address[] memory verifiers = new address[](3);
        verifiers[0] = 0xB6f2b30244e32e7e95Ffa1A23797131aAb896410;
        verifiers[1] = 0x178d24C71437aea2739A6C9E28162793c40A919c;
        verifiers[2] = 0x3e84A470cfD72C6153da3759FB0c22FF05B466e7;
        SubvaultCalls[] memory calls = new SubvaultCalls[](3);
        (, calls[0]) = _createCowswapVerifier(address(vault));

        (address[] memory assets_, VaultConfigurator.InitParams memory initParams) =
            _getInitParams(deployer, timelockController);
        ProtocolDeployment memory $ = Constants.protocolDeployment();
        {
            for (uint256 i = 1; i < 3; i++) {
                string[] memory descriptions = tqETHLibraryV2.getSubvault0Descriptions(curator, agent);
                (bytes32 merkleRoot, IVerifier.VerificationPayload[] memory leaves) =
                    tqETHLibraryV2.getSubvault0Proofs(curator, agent);
                ProofLibrary.storeProofs(
                    string(abi.encodePacked("base:tqETH:subvault", Strings.toString(i))),
                    merkleRoot,
                    leaves,
                    descriptions
                );

                calls[i] = tqETHLibraryV2.getSubvault0SubvaultCalls($, curator, agent, leaves);
                address subvault = vault.createSubvault(0, proxyAdmin, verifiers[i]); // eth,weth,wsteth
                IRiskManager riskManager = vault.riskManager();
                riskManager.allowSubvaultAssets(
                    subvault,
                    ArraysLibrary.makeAddressArray(abi.encode(Constants.ETH, Constants.WETH, Constants.WSTETH))
                );
                riskManager.setSubvaultLimit(subvault, type(int256).max / 2);
            }
        }

        for (uint256 i = 0; i < vault.subvaults() + 2; i++) {
            vault.setDefaultDepositHook(address(0));
        }
        for (uint256 index = 0; index < assets_.length; index++) {
            for (uint256 i = 0; i < vault.getQueueCount(assets_[index]); i++) {
                address queue = vault.queueAt(assets_[index], i);
                if (vault.isDepositQueue(queue)) {
                    vault.setDefaultDepositHook(address(0));
                    vault.setCustomHook(queue, address(0));
                }
            }
        }
        vault.renounceRole(Permissions.CREATE_SUBVAULT_ROLE, lazyVaultAdmin);
        vault.renounceRole(Permissions.SET_HOOK_ROLE, lazyVaultAdmin);
        vm.stopPrank();

        AcceptanceLibrary.runProtocolDeploymentChecks($);
        AcceptanceLibrary.runVaultDeploymentChecks(
            $,
            VaultDeployment({
                vault: vault,
                calls: calls,
                initParams: initParams,
                holders: _getExpectedHolders(timelockController),
                depositHook: address(0),
                redeemHook: address($.basicRedeemHook),
                assets: assets_,
                depositQueueAssets: assets_,
                redeemQueueAssets: assets_,
                subvaultVerifiers: verifiers,
                timelockControllers: ArraysLibrary.makeAddressArray(abi.encode(timelockController)),
                timelockProposers: ArraysLibrary.makeAddressArray(abi.encode(lazyVaultAdmin, deployer)),
                timelockExecutors: ArraysLibrary.makeAddressArray(abi.encode(lazyVaultAdmin))
            })
        );
    }

    function _getInitParams(address deployer, address timelockController)
        internal
        view
        returns (address[] memory assets_, VaultConfigurator.InitParams memory initParams)
    {
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

        assets_ = ArraysLibrary.makeAddressArray(abi.encode(Constants.ETH, Constants.WETH, Constants.WSTETH));

        ProtocolDeployment memory $ = Constants.protocolDeployment();
        initParams = VaultConfigurator.InitParams({
            version: 0,
            proxyAdmin: proxyAdmin,
            vaultAdmin: lazyVaultAdmin,
            shareManagerVersion: 0,
            shareManagerParams: abi.encode(bytes32(0), "Theoriq AlphaVault ETH", "tqETH"),
            feeManagerVersion: 0,
            feeManagerParams: abi.encode(deployer, lazyVaultAdmin, uint24(0), uint24(0), uint24(1e5), uint24(1e4)),
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
                assets_
            ),
            defaultDepositHook: address($.redirectingDepositHook),
            defaultRedeemHook: address($.basicRedeemHook),
            queueLimit: 6,
            roleHolders: holders
        });
    }
}
