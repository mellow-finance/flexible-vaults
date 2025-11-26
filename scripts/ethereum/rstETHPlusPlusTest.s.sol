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
import "./rstETHPlusPlusLibrary.sol";

import "../common/ArraysLibrary.sol";
import "../common/interfaces/ICapFactory.sol";

import "../common/interfaces/ISymbioticStakerRewardsPermissions.sol";
import "../common/interfaces/ISymbioticVaultPermissions.sol";

contract Deploy is Script {
    // Actors

    address public testWallet = 0xd134000450E789311F9F11609F6164A35bbF604e;

    address public proxyAdmin = testWallet;
    address public lazyVaultAdmin = testWallet;
    address public activeVaultAdmin = testWallet;
    address public oracleUpdater = testWallet;
    address public curator = testWallet;
    address public treasury = testWallet;

    address public pauser = testWallet;

    bytes32 public constant MORPHO_WEWETH_WETH_MARKET_ID =
        0x37e7484d642d90f14451f1910ba4b7b8e4c3ccdd0ec28f8b2bdb35479e472ba7;
    bytes32 public constant MORPHO_RSETH_WETH_MARKET_ID =
        0xba761af4134efb0855adfba638945f454f0a704af11fc93439e20c7c5ebab942;

    function run() external {
        _updateMerkleRoot();
        revert("ok");
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
            abi.encode(
                Constants.ETH, Constants.WETH, Constants.WSTETH, Constants.RSETH, Constants.WEETH, Constants.RSTETH
            )
        );

        ProtocolDeployment memory $ = Constants.protocolDeployment();
        VaultConfigurator.InitParams memory initParams = VaultConfigurator.InitParams({
            version: 0,
            proxyAdmin: proxyAdmin,
            vaultAdmin: lazyVaultAdmin,
            shareManagerVersion: 0,
            shareManagerParams: abi.encode(bytes32(0), "Restaking Vault ETH++", "rstETH++"),
            feeManagerVersion: 0,
            feeManagerParams: abi.encode(deployer, treasury, uint24(0), uint24(0), uint24(0), uint24(5000)),
            riskManagerVersion: 0,
            riskManagerParams: abi.encode(type(int256).max / 2),
            oracleVersion: 0,
            oracleParams: abi.encode(
                IOracle.SecurityParams({
                    maxAbsoluteDeviation: 0.005 ether,
                    suspiciousAbsoluteDeviation: 0.001 ether,
                    maxRelativeDeviationD18: 0.005 ether,
                    suspiciousRelativeDeviationD18: 0.001 ether,
                    timeout: 15 minutes,
                    depositInterval: 1 seconds,
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

        // queues setup
        vault.createQueue(0, true, proxyAdmin, Constants.ETH, new bytes(0));
        vault.createQueue(0, true, proxyAdmin, Constants.WETH, new bytes(0));
        vault.createQueue(0, true, proxyAdmin, Constants.WSTETH, new bytes(0));
        vault.createQueue(0, true, proxyAdmin, Constants.RSTETH, new bytes(0));
        vault.createQueue(0, false, proxyAdmin, Constants.WSTETH, new bytes(0));

        // fee manager setup
        vault.feeManager().setBaseAsset(address(vault), Constants.ETH);
        Ownable(address(vault.feeManager())).transferOwnership(lazyVaultAdmin);

        // subvault setup
        address[] memory verifiers = new address[](1);
        SubvaultCalls[] memory calls = new SubvaultCalls[](1);

        IRiskManager riskManager = vault.riskManager();
        /*
            subvault 0:
                weth.deposit{any}()
                cowswap (ETH/WETH/wstETH -> weETH/rsETH) via SwapModule
                aave borrow/repay ETH/WETH (weETH/rsETH collateral)
                morpho borrow/repay ETH/WETH (weETH/rsETH collateral)
        */

        {
            verifiers[0] = $.verifierFactory.create(0, proxyAdmin, abi.encode(vault, bytes32(0)));
            address subvault = vault.createSubvault(0, proxyAdmin, verifiers[0]);
            address swapModuleSubvault0 = _deploySwapModuleSubvault0(subvault);

            bytes32 merkleRoot;
            (merkleRoot, calls[0]) = _createSubvault0Proofs(subvault, swapModuleSubvault0);
            IVerifier(verifiers[0]).setMerkleRoot(merkleRoot);

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
        vault.renounceRole(Permissions.SET_MERKLE_ROOT_ROLE, deployer);

        console2.log("Vault %s", address(vault));

        console2.log("DepositQueue (ETH) %s", address(vault.queueAt(Constants.ETH, 0)));
        console2.log("DepositQueue (WETH) %s", address(vault.queueAt(Constants.WETH, 0)));
        console2.log("DepositQueue (WSTETH) %s", address(vault.queueAt(Constants.WSTETH, 0)));
        console2.log("DepositQueue (RSTETH) %s", address(vault.queueAt(Constants.RSTETH, 0)));
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
            uint256 ETHUSDPriceD8 = IAaveOracle(Constants.AAVE_V3_ORACLE).getAssetPrice(Constants.WETH);
            uint256 rsETHUSDPriceD8 = IAaveOracle(Constants.AAVE_V3_ORACLE).getAssetPrice(Constants.RSETH);
            uint256 weETHUSDPriceD8 = IAaveOracle(Constants.AAVE_V3_ORACLE).getAssetPrice(Constants.WEETH);

            IOracle.Report[] memory reports = new IOracle.Report[](assets_.length);
            for (uint256 i = 0; i < reports.length; i++) {
                reports[i].asset = assets_[i];
            }
            reports[0].priceD18 = 1 ether;
            reports[1].priceD18 = 1 ether;
            reports[2].priceD18 = uint224(WSTETHInterface(Constants.WSTETH).getStETHByWstETH(1 ether)); // WSTETH
            reports[3].priceD18 = uint224(rsETHUSDPriceD8 * 1e18 / ETHUSDPriceD8); // rsETH
            reports[4].priceD18 = uint224(weETHUSDPriceD8 * 1e18 / ETHUSDPriceD8); // weETH
            reports[5].priceD18 = uint224(
                WSTETHInterface(Constants.WSTETH).getStETHByWstETH(IERC4626(Constants.RSTETH).convertToAssets(1 ether))
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
                holders: _getExpectedHolders(address(timelockController)),
                depositHook: address($.redirectingDepositHook),
                redeemHook: address($.basicRedeemHook),
                assets: assets_,
                depositQueueAssets: ArraysLibrary.makeAddressArray(
                    abi.encode(Constants.ETH, Constants.WETH, Constants.WSTETH, Constants.RSTETH)
                ),
                redeemQueueAssets: ArraysLibrary.makeAddressArray(abi.encode(Constants.WSTETH)),
                subvaultVerifiers: verifiers,
                timelockControllers: ArraysLibrary.makeAddressArray(abi.encode(address(timelockController))),
                timelockProposers: ArraysLibrary.makeAddressArray(abi.encode(lazyVaultAdmin, deployer)),
                timelockExecutors: ArraysLibrary.makeAddressArray(abi.encode(pauser))
            })
        );

        revert("ok");
    }

    function acceptReport() internal {
        Vault vault = Vault(payable(address(0x5E77D4497f34E5Cb51150A7cc4aBFc84f1F145Da)));

        IOracle oracle = vault.oracle();
        address[] memory assets = ArraysLibrary.makeAddressArray(
            abi.encode(
                Constants.ETH, Constants.WETH, Constants.WSTETH, Constants.RSETH, Constants.WEETH, Constants.RSTETH
            )
        );

        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);

        vm.startBroadcast(deployerPk);
        for (uint256 i = 0; i < assets.length; i++) {
            IOracle.DetailedReport memory report = oracle.getReport(assets[i]);
            oracle.acceptReport(assets[i], report.priceD18, uint32(report.timestamp));
            console2.log("asset %s priceD18 %s timestamp %s", assets[i], report.priceD18, report.timestamp);
        }

        IDepositQueue(address(vault.queueAt(Constants.ETH, 0))).deposit{value: 0.001 ether}(
            0.001 ether, address(0), new bytes32[](0)
        );

        vault.renounceRole(Permissions.SUBMIT_REPORTS_ROLE, deployer);
        vault.renounceRole(Permissions.ACCEPT_REPORT_ROLE, deployer);

        vm.stopBroadcast();
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

    function _createSubvault0Proofs(address subvault, address swapModuleSubvault)
        internal
        returns (bytes32 merkleRoot, SubvaultCalls memory calls)
    {
        rstETHPlusPlusLibrary.Info memory info = rstETHPlusPlusLibrary.Info({
            curator: curator,
            subvault: subvault,
            subvaultName: "subvault0",
            swapModule: swapModuleSubvault,
            claimDistributor: Constants.ANGLE_DISTRIBUTOR,
            claimOperators: ArraysLibrary.makeAddressArray(abi.encode(curator)),
            aaveCollaterals: ArraysLibrary.makeAddressArray(abi.encode(Constants.WEETH, Constants.RSETH)),
            aaveLoans: ArraysLibrary.makeAddressArray(abi.encode(Constants.WETH)),
            morphoMarketId: ArraysLibrary.makeBytes32Array(
                abi.encode(MORPHO_WEWETH_WETH_MARKET_ID, MORPHO_RSETH_WETH_MARKET_ID)
            )
        });
        string[] memory descriptions = rstETHPlusPlusLibrary.getSubvault0Descriptions(info);
        IVerifier.VerificationPayload[] memory leaves;
        (merkleRoot, leaves) = rstETHPlusPlusLibrary.getSubvault0Proofs(info);
        ProofLibrary.storeProofs("ethereum:rstETH++:subvault0", merkleRoot, leaves, descriptions);
        calls = rstETHPlusPlusLibrary.getSubvault0Calls(info, leaves);
    }

    function _deploySwapModuleSubvault0(address subvault) internal returns (address swapModule) {
        ProtocolDeployment memory $ = Constants.protocolDeployment();
        /*
            WETH - router
            WETH/wstETH/weETH/rsETH - tokenIn
            WETH/wstETH/weETH/rsETH - tokenOut
        */
        address[] memory holders = ArraysLibrary.makeAddressArray(
            abi.encode(
                curator,
                Constants.KYBERSWAP_ROUTER,
                Constants.WETH,
                Constants.WETH,
                Constants.WSTETH,
                Constants.WEETH,
                Constants.RSETH,
                Constants.WETH,
                Constants.WSTETH,
                Constants.WEETH,
                Constants.RSETH
            )
        );
        bytes32[] memory roles = ArraysLibrary.makeBytes32Array(
            abi.encode(
                Permissions.SWAP_MODULE_CALLER_ROLE,
                Permissions.SWAP_MODULE_ROUTER_ROLE,
                Permissions.SWAP_MODULE_ROUTER_ROLE,
                Permissions.SWAP_MODULE_TOKEN_IN_ROLE,
                Permissions.SWAP_MODULE_TOKEN_IN_ROLE,
                Permissions.SWAP_MODULE_TOKEN_IN_ROLE,
                Permissions.SWAP_MODULE_TOKEN_IN_ROLE,
                Permissions.SWAP_MODULE_TOKEN_OUT_ROLE,
                Permissions.SWAP_MODULE_TOKEN_OUT_ROLE,
                Permissions.SWAP_MODULE_TOKEN_OUT_ROLE,
                Permissions.SWAP_MODULE_TOKEN_OUT_ROLE
            )
        );

        console2.log("SwapModuleFactory %s", address($.swapModuleFactory));
        swapModule = $.swapModuleFactory.create(
            0, proxyAdmin, abi.encode(lazyVaultAdmin, subvault, Constants.AAVE_V3_ORACLE, 0.995e8, holders, roles)
        );
        console2.log("Subvault0 SwapModule %s", swapModule);
    }

    function _updateMerkleRoot() internal {
        Vault vault = Vault(payable(address(0x5E77D4497f34E5Cb51150A7cc4aBFc84f1F145Da)));
        address swapModuleSubvault = 0xA0Ca8fA2D18E59BFc3E104C7e727557B9565e9C2;
        
        bytes32[] memory merkleRoot = new bytes32[](1);
        SubvaultCalls[] memory calls = new SubvaultCalls[](1);

        address subvault = vault.subvaultAt(0);
        (merkleRoot[0], calls[0]) = _createSubvault0Proofs(subvault, swapModuleSubvault);

        for (uint256 i = 0; i < calls.length; i++) {
            Subvault subvault = Subvault(payable(IVaultModule(vault).subvaultAt(i)));
            IVerifier verifier = Subvault(payable(subvault)).verifier();

            vm.prank(lazyVaultAdmin);
            verifier.setMerkleRoot(merkleRoot[i]);

            for (uint256 j = 0; j < calls[i].payloads.length; j++) {
                AcceptanceLibrary._verifyCalls(verifier, calls[i].calls[j], calls[i].payloads[j]);
            }
        }
    }
}
