// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../common/interfaces/ICowswapSettlement.sol";
import {IWETH as WETHInterface} from "../common/interfaces/IWETH.sol";
import {IWSTETH as WSTETHInterface} from "../common/interfaces/IWSTETH.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "../../src/oracles/OracleSubmitter.sol";
import "../../src/vaults/Subvault.sol";
import "../../src/vaults/VaultConfigurator.sol";

import "../common/AcceptanceLibrary.sol";
import "../common/Permissions.sol";
import "../common/ProofLibrary.sol";
import "forge-std/Script.sol";
import "forge-std/Test.sol";

import "../common/ArraysLibrary.sol";
import "../common/interfaces/IAggregatorV3.sol";
import "./Constants.sol";

contract Deploy is Script, Test {
    // Actors
    address public proxyAdmin = 0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0;
    address public lazyVaultAdmin = 0x0Dd73341d6158a72b4D224541f1094188f57076E;
    address public activeVaultAdmin = 0x5037B1A8Fd9aB941d57fbfc4435148C3C9b48b14;
    address public curator = 0x3236FdfE07f2886Af61c0A559aFc2c5869D06009;

    address public oracleUpdater = 0x317838e80ca05a29DE3a9bbB1596047F45ceaD72;
    address public oracleAccepter = lazyVaultAdmin;
    address public treasury = 0xcCf2daba8Bb04a232a2fDA0D01010D4EF6C69B85;

    address public lidoPauser = 0xA916fD5252160A7E56A6405741De76dc0Da5A0Cd;
    address public mellowPauser = 0x6E887aF318c6b29CEE42Ea28953Bd0BAdb3cE638;
    address public curatorPauser = 0x306D9086Aff2a55F2990882bA8685112FEe332d3;

    uint256 public constant DEFAULT_PENALTY_D6 = 0; // earnUSD is the only depositor
    uint32 public constant DEFAULT_MAX_AGE = 24 hours;
    uint256 public constant DEFAULT_MULTIPLIER = 0.995e8;

    string public name = "Experimental earnUSD";
    string public symbol = "earnUSDe";

    address[] assets_ = ArraysLibrary.makeAddressArray(abi.encode(Constants.USDC, Constants.WMON));

    address[] verifiers = new address[](2);

    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);

        vm.startBroadcast(deployerPk);

        Vault.RoleHolder[] memory holders = new Vault.RoleHolder[](42);
        TimelockController timelockController;

        {
            address[] memory proposers = ArraysLibrary.makeAddressArray(abi.encode(lazyVaultAdmin, deployer));
            address[] memory executors =
                ArraysLibrary.makeAddressArray(abi.encode(lidoPauser, mellowPauser, curatorPauser));
            timelockController = new TimelockController(0, proposers, executors, lazyVaultAdmin);
        }

        console.log("------------------------------------");
        console.log("%s (%s)", name, symbol);
        console.log("------------------------------------");
        console.log("Actors:");
        console.log("------------------------------------");
        console.log("ProxyAdmin", proxyAdmin);
        console.log("LazyAdmin", lazyVaultAdmin);
        console.log("ActiveAdmin", activeVaultAdmin);

        console.log("Curator", curator);
        curator = Constants.protocolDeployment().accountFactory.create(0, proxyAdmin, abi.encode(curator));
        console.log("MellowAccountV1 for curator", curator);

        console.log("OracleUpdater", oracleUpdater);
        console.log("OracleAccepter", oracleAccepter);
        console.log("Treasury", treasury);

        console.log("LidoPauser", lidoPauser);
        console.log("MellowPauser", mellowPauser);
        console.log("CuratorPauser", curatorPauser);

        console.log("------------------------------------");
        console.log("Addresses:");
        console.log("------------------------------------");

        {
            uint256 i = 0;

            // activeVaultAdmin roles:
            holders[i++] = Vault.RoleHolder(Permissions.SET_VAULT_LIMIT_ROLE, activeVaultAdmin);
            holders[i++] = Vault.RoleHolder(Permissions.SET_SUBVAULT_LIMIT_ROLE, activeVaultAdmin);
            holders[i++] = Vault.RoleHolder(Permissions.ALLOW_SUBVAULT_ASSETS_ROLE, activeVaultAdmin);
            holders[i++] = Vault.RoleHolder(Permissions.MODIFY_VAULT_BALANCE_ROLE, activeVaultAdmin);
            holders[i++] = Vault.RoleHolder(Permissions.MODIFY_SUBVAULT_BALANCE_ROLE, activeVaultAdmin);

            // curator roles:
            holders[i++] = Vault.RoleHolder(Permissions.CALLER_ROLE, curator);
            holders[i++] = Vault.RoleHolder(Permissions.PULL_LIQUIDITY_ROLE, curator);
            holders[i++] = Vault.RoleHolder(Permissions.PUSH_LIQUIDITY_ROLE, curator);

            // emergeny pauser roles:
            holders[i++] = Vault.RoleHolder(Permissions.SET_FLAGS_ROLE, address(timelockController));
            holders[i++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, address(timelockController));
            holders[i++] = Vault.RoleHolder(Permissions.SET_QUEUE_STATUS_ROLE, address(timelockController));

            // deployer roles:
            holders[i++] = Vault.RoleHolder(Permissions.DEFAULT_ADMIN_ROLE, deployer);
            holders[i++] = Vault.RoleHolder(Permissions.CREATE_SUBVAULT_ROLE, deployer);
            holders[i++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, deployer);
            holders[i++] = Vault.RoleHolder(Permissions.ALLOW_SUBVAULT_ASSETS_ROLE, deployer);
            holders[i++] = Vault.RoleHolder(Permissions.SET_SUBVAULT_LIMIT_ROLE, deployer);

            assembly {
                mstore(holders, i)
            }
        }

        ProtocolDeployment memory $ = Constants.protocolDeployment();
        VaultConfigurator.InitParams memory initParams = VaultConfigurator.InitParams({
            version: 0,
            proxyAdmin: proxyAdmin,
            vaultAdmin: lazyVaultAdmin,
            shareManagerVersion: 0,
            shareManagerParams: abi.encode(bytes32(0), name, symbol),
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
                    timeout: 20 hours,
                    depositInterval: 365 days,
                    redeemInterval: 365 days
                }),
                assets_
            ),
            defaultDepositHook: address(0),
            defaultRedeemHook: address(0),
            queueLimit: 0,
            roleHolders: holders
        });

        Vault vault;
        {
            (,,,, address vault_) = $.vaultConfigurator.create(initParams);
            vault = Vault(payable(vault_));
        }

        vault.feeManager().setBaseAsset(address(vault), Constants.USDC);
        Ownable(address(vault.feeManager())).transferOwnership(lazyVaultAdmin);

        // subvault setup

        SubvaultCalls[] memory calls = new SubvaultCalls[](verifiers.length);

        {
            IRiskManager riskManager = vault.riskManager();
            {
                uint256 subvaultIndex = 0;
                verifiers[subvaultIndex] = $.verifierFactory.create(0, proxyAdmin, abi.encode(vault, bytes32(0)));
                address subvault = vault.createSubvault(0, proxyAdmin, verifiers[subvaultIndex]);
                address swapModule = _deploySwapModule(subvault);

                console.log("SwapModule 0:", swapModule);
                console.log("Subvault 0:", subvault);
                console.log("Verifier 0:", verifiers[0]);

                riskManager.allowSubvaultAssets(subvault, assets_);
                riskManager.setSubvaultLimit(subvault, type(int256).max / 2);
            }

            {
                uint256 subvaultIndex = 1;
                verifiers[subvaultIndex] = $.verifierFactory.create(0, proxyAdmin, abi.encode(vault, bytes32(0)));
                address subvault = vault.createSubvault(0, proxyAdmin, verifiers[subvaultIndex]);
                console.log("Subvault 1:", subvault);
                console.log("Verifier 1:", verifiers[0]);
                riskManager.allowSubvaultAssets(subvault, assets_);
                riskManager.setSubvaultLimit(subvault, type(int256).max / 2);
            }
        }

        vault.renounceRole(Permissions.CREATE_SUBVAULT_ROLE, deployer);
        vault.renounceRole(Permissions.ALLOW_SUBVAULT_ASSETS_ROLE, deployer);
        vault.renounceRole(Permissions.SET_SUBVAULT_LIMIT_ROLE, deployer);

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

        console.log("Vault %s", address(vault));

        for (uint256 i = 0; i < vault.getAssetCount(); i++) {
            address asset = vault.assetAt(i);
            string memory symbol_ = asset == Constants.MON ? "MON" : IERC20Metadata(asset).symbol();
            for (uint256 j = 0; j < vault.getQueueCount(asset); j++) {
                address queue = vault.queueAt(asset, j);
                if (vault.isDepositQueue(queue)) {
                    try SyncDepositQueue(queue).name() returns (string memory) {
                        console.log("SyncDepositQueue (%s): %s", symbol_, queue);
                    } catch {
                        console.log("DepositQueue (%s): %s", symbol_, queue);
                    }
                } else {
                    console.log("RedeemQueue (%s): %s", symbol_, queue);
                }
            }
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

        OracleSubmitter oracleSubmitter =
            new OracleSubmitter(deployer, oracleUpdater, oracleAccepter, address(vault.oracle()));
        oracleSubmitter.grantRole(Permissions.DEFAULT_ADMIN_ROLE, lazyVaultAdmin);
        oracleSubmitter.grantRole(Permissions.SUBMIT_REPORTS_ROLE, deployer);
        oracleSubmitter.grantRole(Permissions.ACCEPT_REPORT_ROLE, deployer);
        oracleSubmitter.renounceRole(Permissions.DEFAULT_ADMIN_ROLE, deployer);
        vault.grantRole(Permissions.SUBMIT_REPORTS_ROLE, address(oracleSubmitter));
        vault.grantRole(Permissions.ACCEPT_REPORT_ROLE, address(oracleSubmitter));
        vault.renounceRole(Permissions.DEFAULT_ADMIN_ROLE, deployer);

        console.log("OracleSubmitter: %s", address(oracleSubmitter));

        {
            IOracle.Report[] memory reports = new IOracle.Report[](assets_.length);
            for (uint256 i = 0; i < reports.length; i++) {
                address asset = assets_[i];
                reports[i].asset = asset;
                uint256 priceD8 = IAaveOracle(Constants.AAVE_V3_ORACLE).getAssetPrice(asset);
                reports[i].priceD18 = uint224(priceD8 * 10 ** (28 - IERC20Metadata(asset).decimals()));
                console.log("Reported price for asset: %s %s", IERC20Metadata(asset).symbol(), reports[i].priceD18);
            }
            oracleSubmitter.submitReports(reports);
        }

        _acceptReports(oracleSubmitter, deployer);

        vm.stopBroadcast();

        AcceptanceLibrary.runProtocolDeploymentChecks(Constants.protocolDeployment());
        AcceptanceLibrary.runVaultDeploymentChecks(
            Constants.protocolDeployment(),
            VaultDeployment({
                vault: vault,
                calls: calls,
                initParams: initParams,
                holders: _getExpectedHolders(address(timelockController), address(oracleSubmitter), deployer),
                depositHook: address(0),
                redeemHook: address(0),
                assets: assets_,
                depositQueueAssets: new address[](0),
                redeemQueueAssets: new address[](0),
                subvaultVerifiers: verifiers,
                timelockControllers: ArraysLibrary.makeAddressArray(abi.encode(address(timelockController))),
                timelockProposers: ArraysLibrary.makeAddressArray(abi.encode(lazyVaultAdmin, deployer)),
                timelockExecutors: ArraysLibrary.makeAddressArray(abi.encode(lidoPauser, mellowPauser, curatorPauser))
            })
        );

        revert("ok");
    }

    function _acceptReports(OracleSubmitter oracleSubmitter, address deployer) internal {
        IOracle oracle = oracleSubmitter.oracle();
        uint256 n = oracle.supportedAssets();
        address[] memory assets = new address[](n);
        uint32[] memory timestamps = new uint32[](n);
        uint224[] memory prices = new uint224[](n);
        for (uint256 i = 0; i < n; i++) {
            address a = oracle.supportedAssetAt(i);
            IOracle.DetailedReport memory r = oracle.getReport(a);
            assets[i] = a;
            timestamps[i] = r.timestamp;
            prices[i] = r.priceD18;
        }
        oracleSubmitter.acceptReports(assets, prices, timestamps);
        oracleSubmitter.renounceRole(Permissions.SUBMIT_REPORTS_ROLE, deployer);
        oracleSubmitter.renounceRole(Permissions.ACCEPT_REPORT_ROLE, deployer);
    }

    function _getExpectedHolders(address timelockController, address oracleSubmitter, address deployer)
        internal
        view
        returns (Vault.RoleHolder[] memory holders)
    {
        holders = new Vault.RoleHolder[](50);
        uint256 i = 0;

        // lazyVaultAdmin roles:
        holders[i++] = Vault.RoleHolder(Permissions.DEFAULT_ADMIN_ROLE, lazyVaultAdmin);

        // activeVaultAdmin roles:
        holders[i++] = Vault.RoleHolder(Permissions.SET_VAULT_LIMIT_ROLE, activeVaultAdmin);
        holders[i++] = Vault.RoleHolder(Permissions.SET_SUBVAULT_LIMIT_ROLE, activeVaultAdmin);
        holders[i++] = Vault.RoleHolder(Permissions.ALLOW_SUBVAULT_ASSETS_ROLE, activeVaultAdmin);
        holders[i++] = Vault.RoleHolder(Permissions.MODIFY_VAULT_BALANCE_ROLE, activeVaultAdmin);
        holders[i++] = Vault.RoleHolder(Permissions.MODIFY_SUBVAULT_BALANCE_ROLE, activeVaultAdmin);

        // curator roles:
        holders[i++] = Vault.RoleHolder(Permissions.CALLER_ROLE, curator);
        holders[i++] = Vault.RoleHolder(Permissions.PULL_LIQUIDITY_ROLE, curator);
        holders[i++] = Vault.RoleHolder(Permissions.PUSH_LIQUIDITY_ROLE, curator);

        // oracle updater roles:
        holders[i++] = Vault.RoleHolder(Permissions.SUBMIT_REPORTS_ROLE, oracleSubmitter);
        holders[i++] = Vault.RoleHolder(Permissions.ACCEPT_REPORT_ROLE, oracleSubmitter);

        // emergeny pauser roles:
        holders[i++] = Vault.RoleHolder(Permissions.SET_FLAGS_ROLE, address(timelockController));
        holders[i++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, address(timelockController));
        holders[i++] = Vault.RoleHolder(Permissions.SET_QUEUE_STATUS_ROLE, address(timelockController));

        holders[i++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, deployer);

        assembly {
            mstore(holders, i)
        }
    }

    function _routers() internal pure returns (address[1] memory result) {
        result = [address(0x6131B5fae19EA4f9D964eAc0408E4408b66337b5)];
    }

    function _deploySwapModule(address subvault) internal returns (address) {
        IFactory swapModuleFactory = Constants.protocolDeployment().swapModuleFactory;
        address[2] memory lidoLeverage = [Constants.WMON, Constants.USDC];
        address[] memory actors =
            ArraysLibrary.makeAddressArray(abi.encode(curator, lidoLeverage, lidoLeverage, _routers()));
        bytes32[] memory permissions = ArraysLibrary.makeBytes32Array(
            abi.encode(
                Permissions.SWAP_MODULE_CALLER_ROLE,
                [Permissions.SWAP_MODULE_TOKEN_IN_ROLE, Permissions.SWAP_MODULE_TOKEN_IN_ROLE],
                [Permissions.SWAP_MODULE_TOKEN_OUT_ROLE, Permissions.SWAP_MODULE_TOKEN_OUT_ROLE],
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
