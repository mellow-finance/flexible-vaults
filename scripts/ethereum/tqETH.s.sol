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
    address public proxyAdmin = 0x55d9ecEB5733F72A48C544e20D49859eC92Fba5F;
    address public lazyVaultAdmin = 0x8907D6089fC71AA6a9a7bb9EC5b1170e92489ebf;
    address public activeVaultAdmin = 0x2D95cb50F204B8B84606751F262b407C08528c85;
    address public oracleUpdater = 0xe5Bc509b277f83F2bF771D0dcB16949D4e175f09;
    address public curator = 0xcca5BafEa783B0Ed8D11FD6D9F97c155332A16b8;

    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);

        vm.startBroadcast(deployerPk);

        Vault.RoleHolder[] memory holders = new Vault.RoleHolder[](42);
        TimelockController timelockController;

        {
            address[] memory proposers = new address[](2);
            proposers[0] = lazyVaultAdmin;
            proposers[1] = deployer;
            address[] memory executors = new address[](1);
            executors[0] = lazyVaultAdmin;
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
                    timeout: 12 hours,
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
            riskManager.setSubvaultLimit(vault.subvaultAt(0), type(int256).max);
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
                subvaultVerifiers: _makeArray(verifier),
                timelockControllers: _makeArray(address(timelockController)),
                timelockProposers: _makeArray(lazyVaultAdmin, deployer),
                timelockExecutors: _makeArray(lazyVaultAdmin)
            })
        );

        revert("ok");
    }

    function _makeArray(address x) internal pure returns (address[] memory a) {
        a = new address[](1);
        a[0] = x;
    }

    function _makeArray(address x, address y) internal pure returns (address[] memory a) {
        a = new address[](2);
        a[0] = x;
        a[1] = y;
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
        string[] memory descriptions = tqETHLibrary.getSubvault0Descriptions();
        (bytes32 merkleRoot, IVerifier.VerificationPayload[] memory leaves) = tqETHLibrary.getSubvault0Proofs(curator);
        ProofLibrary.storeProofs("ethereum:tqETH:subvault0", merkleRoot, leaves, descriptions);
        calls = tqETHLibrary.getSubvault0SubvaultCalls($, curator, leaves);
        verifier = $.verifierFactory.create(0, proxyAdmin, abi.encode(vault, merkleRoot));
    }
}
