// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

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

import "../../src/queues/SyncRedeemQueue.sol";

import "../common/AcceptanceLibrary.sol";
import "../common/Permissions.sol";
import "../common/ProofLibrary.sol";

import "./Constants.sol";

import "../common/ArraysLibrary.sol";

import "../common/interfaces/IAggregatorV3.sol";

contract Deploy is Script, Test {
    // Actors

    address public admin = 0x60C2F29FD09eFc2BD38f8804cFA909cC74417De2;

    uint256 public constant DEFAULT_PENALTY_D6 = 0; // earnUSD is the only depositor
    uint32 public constant DEFAULT_MAX_AGE = 168 hours;
    uint256 public constant DEFAULT_MULTIPLIER = 0.995e8;

    string public name = "test Lido Vault";
    string public symbol = "tlv";

    address[] assets_ = ArraysLibrary.makeAddressArray(abi.encode(Constants.USDC, Constants.USDT, Constants.USDE));
    address[] verifiers = new address[](2);

    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);

        vm.startBroadcast(deployerPk);

        {

            address verifier0 = 0xcc61f9A3cfe86DC2d361930a18F5E26185deC824;
            IVerifier(verifier0).setMerkleRoot(0x4e59b20cc749886a1750247e8691855367889c649c90e74677e051977d343e69);

            address verifier1 = 0x662274f09BD849a611A71C4931D8861a5C7CBBDC;
            IVerifier(verifier1).setMerkleRoot(0x25808597a2da44c9dbac32cfceb33996f8f9a5c361e0ac1c4df27d98f968e173);

            return;
        }

        Vault.RoleHolder[] memory holders = new Vault.RoleHolder[](42);

        console.log("------------------------------------");
        console.log("%s (%s)", name, symbol);
        console.log("------------------------------------");
        console.log("Actors:");
        console.log("------------------------------------");
        console.log("Admin", admin);

        console.log("------------------------------------");
        console.log("Addresses:");
        console.log("------------------------------------");

        {
            uint256 i = 0;

            // activeVaultAdmin roles:
            holders[i++] = Vault.RoleHolder(Permissions.SET_VAULT_LIMIT_ROLE, admin);
            holders[i++] = Vault.RoleHolder(Permissions.SET_SUBVAULT_LIMIT_ROLE, admin);
            holders[i++] = Vault.RoleHolder(Permissions.ALLOW_SUBVAULT_ASSETS_ROLE, admin);
            holders[i++] = Vault.RoleHolder(Permissions.MODIFY_VAULT_BALANCE_ROLE, admin);
            holders[i++] = Vault.RoleHolder(Permissions.MODIFY_SUBVAULT_BALANCE_ROLE, admin);

            // curator roles:
            holders[i++] = Vault.RoleHolder(Permissions.CALLER_ROLE, admin);
            holders[i++] = Vault.RoleHolder(Permissions.PULL_LIQUIDITY_ROLE, admin);
            holders[i++] = Vault.RoleHolder(Permissions.PUSH_LIQUIDITY_ROLE, admin);

            // deployer roles:
            holders[i++] = Vault.RoleHolder(Permissions.CREATE_QUEUE_ROLE, deployer);
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
            proxyAdmin: admin,
            vaultAdmin: admin,
            shareManagerVersion: 2,
            shareManagerParams: abi.encode(bytes32(0), name, symbol),
            feeManagerVersion: 0,
            feeManagerParams: abi.encode(deployer, admin, uint24(0), uint24(0), uint24(0), uint24(0)),
            riskManagerVersion: 0,
            riskManagerParams: abi.encode(type(int256).max / 2),
            oracleVersion: 0,
            oracleParams: abi.encode(
                IOracle.SecurityParams({
                    maxAbsoluteDeviation: 0.005e30,
                    suspiciousAbsoluteDeviation: 0.001e30,
                    maxRelativeDeviationD18: 0.005 ether,
                    suspiciousRelativeDeviationD18: 0.001 ether,
                    timeout: 15 minutes,
                    depositInterval: 1 seconds,
                    redeemInterval: 30 minutes
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

        for (uint256 i = 0; i < assets_.length; i++) {
            address asset = assets_[i];
            vault.createQueue(3, true, admin, asset, abi.encode(DEFAULT_PENALTY_D6, DEFAULT_MAX_AGE));
        }

        // Updated version of RedeemQueue contract

        for (uint256 i = 0; i < assets_.length; i++) {
            address asset = assets_[i];
            vault.createQueue(2, false, admin, asset, new bytes(0));
        }
        vault.renounceRole(Permissions.CREATE_QUEUE_ROLE, deployer);

        // fee manager setup
        vault.feeManager().setBaseAsset(address(vault), Constants.USDC);
        Ownable(address(vault.feeManager())).transferOwnership(admin);

        // subvault setup

        SubvaultCalls[] memory calls = new SubvaultCalls[](verifiers.length);

        {
            IRiskManager riskManager = vault.riskManager();
            {
                uint256 subvaultIndex = 0;
                verifiers[subvaultIndex] = $.verifierFactory.create(0, admin, abi.encode(vault, bytes32(0)));
                address subvault = vault.createSubvault(0, admin, verifiers[subvaultIndex]);
                address swapModule = _deploySwapModule(subvault);
                console.log("SwapModule 0:", swapModule);
                console.log("Subvault 0:", subvault);
                console.log("Verifier 0:", verifiers[0]);
                riskManager.allowSubvaultAssets(subvault, assets_);
                riskManager.setSubvaultLimit(subvault, type(int256).max / 2);
            }

            {
                uint256 subvaultIndex = 1;
                verifiers[subvaultIndex] = $.verifierFactory.create(0, admin, abi.encode(vault, bytes32(0)));
                address subvault = vault.createSubvault(0, admin, verifiers[subvaultIndex]);
                console.log("Subvault 0:", subvault);
                console.log("Verifier 0:", verifiers[0]);
                riskManager.allowSubvaultAssets(subvault, assets_);
                riskManager.setSubvaultLimit(subvault, type(int256).max / 2);
            }
        }

        vault.renounceRole(Permissions.SET_SUBVAULT_LIMIT_ROLE, deployer);
        vault.renounceRole(Permissions.ALLOW_SUBVAULT_ASSETS_ROLE, deployer);
        vault.renounceRole(Permissions.CREATE_SUBVAULT_ROLE, deployer);

        console.log("Vault %s", address(vault));

        for (uint256 i = 0; i < vault.getAssetCount(); i++) {
            address asset = vault.assetAt(i);
            string memory symbol_ = asset == Constants.ETH ? "ETH" : IERC20Metadata(asset).symbol();
            for (uint256 j = 0; j < vault.getQueueCount(asset); j++) {
                address queue = vault.queueAt(asset, j);
                if (vault.isDepositQueue(queue)) {
                    try ISyncQueue(queue).name() returns (string memory) {
                        console.log("SyncDepositQueue (%s): %s", symbol_, queue);
                    } catch {
                        console.log("DepositQueue (%s): %s", symbol_, queue);
                    }
                } else {
                    try ISyncQueue(queue).name() returns (string memory) {
                        console.log("SyncRedeemQueue (%s): %s", symbol_, queue);
                    } catch {
                        console.log("RedeemQueue (%s): %s", symbol_, queue);
                    }
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

        OracleSubmitter oracleSubmitter = new OracleSubmitter(deployer, admin, admin, address(vault.oracle()));
        oracleSubmitter.grantRole(Permissions.DEFAULT_ADMIN_ROLE, admin);
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

        // _acceptReports(oracleSubmitter, deployer);

        // vm.stopBroadcast();

        // AcceptanceLibrary.runProtocolDeploymentChecks(Constants.protocolDeployment());
        // AcceptanceLibrary.runVaultDeploymentChecks(
        //     Constants.protocolDeployment(),
        //     VaultDeployment({
        //         vault: vault,
        //         calls: calls,
        //         initParams: initParams,
        //         holders: _getExpectedHolders(address(oracleSubmitter), deployer),
        //         depositHook: address($.redirectingDepositHook),
        //         redeemHook: address($.basicRedeemHook),
        //         assets: assets_,
        //         depositQueueAssets: assets_,
        //         redeemQueueAssets: assets_,
        //         subvaultVerifiers: verifiers,
        //         timelockControllers: new address[](0),
        //         timelockProposers: new address[](0),
        //         timelockExecutors: new address[](0)
        //     })
        // );

        // revert("ok");
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

    function _getExpectedHolders(address oracleSubmitter, address deployer)
        internal
        view
        returns (Vault.RoleHolder[] memory holders)
    {
        holders = new Vault.RoleHolder[](50);
        uint256 i = 0;

        // lazyVaultAdmin roles:
        holders[i++] = Vault.RoleHolder(Permissions.DEFAULT_ADMIN_ROLE, admin);

        // activeVaultAdmin roles:
        holders[i++] = Vault.RoleHolder(Permissions.SET_VAULT_LIMIT_ROLE, admin);
        holders[i++] = Vault.RoleHolder(Permissions.SET_SUBVAULT_LIMIT_ROLE, admin);
        holders[i++] = Vault.RoleHolder(Permissions.ALLOW_SUBVAULT_ASSETS_ROLE, admin);
        holders[i++] = Vault.RoleHolder(Permissions.MODIFY_VAULT_BALANCE_ROLE, admin);
        holders[i++] = Vault.RoleHolder(Permissions.MODIFY_SUBVAULT_BALANCE_ROLE, admin);

        // curator roles:
        holders[i++] = Vault.RoleHolder(Permissions.CALLER_ROLE, admin);
        holders[i++] = Vault.RoleHolder(Permissions.PULL_LIQUIDITY_ROLE, admin);
        holders[i++] = Vault.RoleHolder(Permissions.PUSH_LIQUIDITY_ROLE, admin);

        // oracle updater roles:
        holders[i++] = Vault.RoleHolder(Permissions.SUBMIT_REPORTS_ROLE, oracleSubmitter);
        holders[i++] = Vault.RoleHolder(Permissions.ACCEPT_REPORT_ROLE, oracleSubmitter);

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

        address[] memory actors = ArraysLibrary.makeAddressArray(
            abi.encode(
                admin,
                [Constants.USDC, Constants.USDT, Constants.USDE],
                [Constants.USDC, Constants.USDT, Constants.USDE],
                _routers()
            )
        );

        bytes32[] memory permissions = ArraysLibrary.makeBytes32Array(
            abi.encode(
                Permissions.SWAP_MODULE_CALLER_ROLE,
                [
                    Permissions.SWAP_MODULE_TOKEN_IN_ROLE,
                    Permissions.SWAP_MODULE_TOKEN_IN_ROLE,
                    Permissions.SWAP_MODULE_TOKEN_IN_ROLE
                ],
                [
                    Permissions.SWAP_MODULE_TOKEN_OUT_ROLE,
                    Permissions.SWAP_MODULE_TOKEN_OUT_ROLE,
                    Permissions.SWAP_MODULE_TOKEN_OUT_ROLE
                ],
                Permissions.SWAP_MODULE_ROUTER_ROLE
            )
        );
        return swapModuleFactory.create(
            0, admin, abi.encode(admin, subvault, Constants.AAVE_V3_ORACLE, DEFAULT_MULTIPLIER, actors, permissions)
        );
    }
}
