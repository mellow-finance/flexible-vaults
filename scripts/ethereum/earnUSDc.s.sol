// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../common/interfaces/ICowswapSettlement.sol";
import {IWETH as WETHInterface} from "../common/interfaces/IWETH.sol";
import {IWSTETH as WSTETHInterface} from "../common/interfaces/IWSTETH.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "@openzeppelin/contracts/interfaces/IERC4626.sol";

import "../../src/oracles/OracleSubmitter.sol";
import "../../src/vaults/Subvault.sol";
import "../../src/vaults/VaultConfigurator.sol";

import "../common/AcceptanceLibrary.sol";
import "../common/Permissions.sol";
import "../common/ProofLibrary.sol";
import "forge-std/Script.sol";
import "forge-std/Test.sol";

import "./Constants.sol";
import "./earnUSDLibrary.sol";

import "../common/ArraysLibrary.sol";

import "../common/interfaces/IAggregatorV3.sol";

contract Deploy is Script, Test {
    // Actors
    address public proxyAdmin = 0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0;
    address public lazyVaultAdmin = 0x0Dd73341d6158a72b4D224541f1094188f57076E;
    address public activeVaultAdmin = 0x982aB69785f5329BB59c36B19CBd4865353fEf10;
    address public curator = 0x7e681274F9F6606abf544d694531F171Cc104985;

    // only for initial setup. Will be changed later
    address public oracleUpdater = curator;
    address public oracleAccepter = lazyVaultAdmin;
    address public treasury = 0xcCf2daba8Bb04a232a2fDA0D01010D4EF6C69B85;

    address public lidoPauser = 0xA916fD5252160A7E56A6405741De76dc0Da5A0Cd;
    address public mellowPauser = 0x6E887aF318c6b29CEE42Ea28953Bd0BAdb3cE638;

    uint256 public constant DEFAULT_PENALTY_D6 = 0; // earnUSD is the only depositor
    uint32 public constant DEFAULT_MAX_AGE = 24 hours;

    string public name = "Conservative earnUSD";
    string public symbol = "earnUSDc";

    address[2] public depositAssets = [Constants.USDC, Constants.USDT];

    address[] public assets_ = ArraysLibrary.makeAddressArray(abi.encode(depositAssets));

    address[] verifiers = new address[](0);

    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);

        vm.startBroadcast(deployerPk);

        if (true) {
            _acceptReports(OracleSubmitter(0xeE2a2B77Ee1B27BF2D68A7496f52dd551873681D), deployer);
            return;
        }

        Vault.RoleHolder[] memory holders = new Vault.RoleHolder[](42);
        TimelockController timelockController;

        {
            address[] memory proposers = ArraysLibrary.makeAddressArray(abi.encode(lazyVaultAdmin, deployer));
            address[] memory executors = ArraysLibrary.makeAddressArray(abi.encode(lidoPauser, mellowPauser));
            timelockController = new TimelockController(0, proposers, executors, lazyVaultAdmin);
        }

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
            holders[i++] = Vault.RoleHolder(Permissions.SET_FLAGS_ROLE, deployer);
            holders[i++] = Vault.RoleHolder(Permissions.SET_ACCOUNT_INFO_ROLE, deployer);
            holders[i++] = Vault.RoleHolder(Permissions.CREATE_QUEUE_ROLE, deployer);
            holders[i++] = Vault.RoleHolder(Permissions.DEFAULT_ADMIN_ROLE, deployer);

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
                    depositInterval: 1 hours,
                    redeemInterval: 2 days
                }),
                assets_
            ),
            defaultDepositHook: address($.redirectingDepositHook),
            defaultRedeemHook: address($.basicRedeemHook),
            queueLimit: 5,
            roleHolders: holders
        });

        Vault vault;
        {
            (,,,, address vault_) = $.vaultConfigurator.create(initParams);
            vault = Vault(payable(vault_));
        }

        vault.shareManager().setFlags(
            IShareManager.Flags({
                hasMintPause: false,
                hasBurnPause: false,
                hasTransferPause: false,
                hasWhitelist: true,
                hasTransferWhitelist: false,
                globalLockup: 0
            })
        );
        vault.renounceRole(Permissions.SET_FLAGS_ROLE, deployer);
        vault.shareManager().setAccountInfo(
            treasury, IShareManager.AccountInfo({canDeposit: true, canTransfer: false, isBlacklisted: false})
        );
        // vault.renounceRole(Permissions.SET_ACCOUNT_INFO_ROLE, deployer) will be called later to add subvault of earnUSD in the whitelist.

        // queues setup

        for (uint256 i = 0; i < depositAssets.length; i++) {
            address asset = depositAssets[i];
            // DepositQueue
            vault.createQueue(0, true, proxyAdmin, asset, new bytes(0));
            // AsyncDepositQueue
            vault.createQueue(2, true, proxyAdmin, asset, abi.encode(DEFAULT_PENALTY_D6, DEFAULT_MAX_AGE));
        }

        // Updated version of RedeemQueue contract
        vault.createQueue(2, false, proxyAdmin, Constants.USDC, new bytes(0));

        // fee manager setup
        vault.feeManager().setBaseAsset(address(vault), Constants.USDC);
        Ownable(address(vault.feeManager())).transferOwnership(lazyVaultAdmin);

        // subvault setup

        SubvaultCalls[] memory calls = new SubvaultCalls[](verifiers.length);

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

        console2.log("Vault %s", address(vault));

        for (uint256 i = 0; i < vault.getAssetCount(); i++) {
            address asset = vault.assetAt(i);
            string memory symbol_ = asset == Constants.ETH ? "ETH" : IERC20Metadata(asset).symbol();
            for (uint256 j = 0; j < vault.getQueueCount(asset); j++) {
                address queue = vault.queueAt(asset, j);
                if (vault.isDepositQueue(queue)) {
                    try SyncDepositQueue(queue).name() returns (string memory) {
                        console2.log("SyncDepositQueue (%s): %s", symbol_, queue);
                    } catch {
                        console2.log("DepositQueue (%s): %s", symbol_, queue);
                    }
                } else {
                    console2.log("RedeemQueue (%s): %s", symbol_, queue);
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

        OracleSubmitter oracleSubmitter =
            new OracleSubmitter(deployer, oracleUpdater, oracleAccepter, address(vault.oracle()));
        oracleSubmitter.grantRole(Permissions.DEFAULT_ADMIN_ROLE, lazyVaultAdmin);
        oracleSubmitter.grantRole(Permissions.SUBMIT_REPORTS_ROLE, deployer);
        oracleSubmitter.grantRole(Permissions.ACCEPT_REPORT_ROLE, deployer);
        oracleSubmitter.renounceRole(Permissions.DEFAULT_ADMIN_ROLE, deployer);
        vault.grantRole(Permissions.SUBMIT_REPORTS_ROLE, address(oracleSubmitter));
        vault.grantRole(Permissions.ACCEPT_REPORT_ROLE, address(oracleSubmitter));
        vault.renounceRole(Permissions.DEFAULT_ADMIN_ROLE, deployer);

        console2.log("OracleSubmitter: %s", address(oracleSubmitter));

        {
            IOracle.Report[] memory reports = new IOracle.Report[](assets_.length);
            for (uint256 i = 0; i < reports.length; i++) {
                reports[i].asset = assets_[i];
            }

            // Constants.USDC, Constants.USDT
            reports[0].priceD18 =
                uint224(uint256(IAggregatorV3(0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6).latestAnswer()) * 1e22);
            reports[1].priceD18 =
                uint224(uint256(IAggregatorV3(0x3E7d1eAB13ad0104d2750B8863b489D65364e32D).latestAnswer()) * 1e22);

            oracleSubmitter.submitReports(reports);
        }

        // _acceptReports(oracleSubmitter, deployer);

        // vm.stopBroadcast();

        // address[] memory depositQueueAssets = new address[](depositAssets.length * 2);
        // for (uint256 i = 0; i < depositAssets.length; i++) {
        //     depositQueueAssets[i * 2] = depositAssets[i];
        //     depositQueueAssets[i * 2 + 1] = depositAssets[i];
        // }
        // AcceptanceLibrary.runProtocolDeploymentChecks(Constants.protocolDeployment());
        // AcceptanceLibrary.runVaultDeploymentChecks(
        //     Constants.protocolDeployment(),
        //     VaultDeployment({
        //         vault: vault,
        //         calls: calls,
        //         initParams: initParams,
        //         holders: _getExpectedHolders(address(timelockController), address(oracleSubmitter), deployer),
        //         depositHook: address($.redirectingDepositHook),
        //         redeemHook: address($.basicRedeemHook),
        //         assets: assets_,
        //         depositQueueAssets: depositQueueAssets,
        //         redeemQueueAssets: ArraysLibrary.makeAddressArray(abi.encode(Constants.USDC)),
        //         subvaultVerifiers: verifiers,
        //         timelockControllers: ArraysLibrary.makeAddressArray(abi.encode(address(timelockController))),
        //         timelockProposers: ArraysLibrary.makeAddressArray(abi.encode(lazyVaultAdmin, deployer)),
        //         timelockExecutors: ArraysLibrary.makeAddressArray(abi.encode(lidoPauser, mellowPauser))
        //     })
        // );

        // revert("ok");
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

        // deployer roles:
        holders[i++] = Vault.RoleHolder(Permissions.SET_ACCOUNT_INFO_ROLE, deployer);

        assembly {
            mstore(holders, i)
        }
    }
}
