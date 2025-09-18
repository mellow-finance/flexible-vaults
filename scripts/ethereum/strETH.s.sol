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

contract Deploy is Script {
    // Actors
    address public proxyAdmin = 0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0;
    address public lazyVaultAdmin = 0xAbE20D266Ae54b9Ae30492dEa6B6407bF18fEeb5;
    address public activeVaultAdmin = 0xeb1CaFBcC8923eCbc243ff251C385C201A6c734a;
    address public oracleUpdater = 0xd27fFB15Dd00D5E52aC2BFE6d5AFD36caE850081;
    address public curator = 0x5Dbf9287787A5825beCb0321A276C9c92d570a75;
    address public treasury = 0xb1E5a8F26C43d019f2883378548a350ecdD1423B;

    address public lidoPauser = 0xA916fD5252160A7E56A6405741De76dc0Da5A0Cd;

    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);

        vm.startBroadcast(deployerPk);

        Vault.RoleHolder[] memory holders = new Vault.RoleHolder[](42);
        TimelockController timelockController;

        {
            address[] memory proposers = _makeArray(lazyVaultAdmin, deployer);
            address[] memory executors = _makeArray(lidoPauser);
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
            shareManagerParams: abi.encode(bytes32(0), "stRATEGY", "strETH"),
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
                    timeout: 20 hours,
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
        Ownable(address(vault.feeManager())).transferOwnership(lazyVaultAdmin);

        // subvault setup
        address[] memory verifiers = new address[](2);
        SubvaultCalls[] memory calls = new SubvaultCalls[](2);

        {
            IRiskManager riskManager = vault.riskManager();
            (verifiers[0], calls[0]) = _createCowswapVerifier(address(vault));
            vault.createSubvault(0, proxyAdmin, verifiers[0]); // eth,weth,wsteth
            riskManager.allowSubvaultAssets(vault.subvaultAt(0), assets_);
            riskManager.setSubvaultLimit(vault.subvaultAt(0), type(int256).max);

            verifiers[1] = $.verifierFactory.create(0, proxyAdmin, abi.encode(vault, bytes32(0)));
            vault.createSubvault(0, proxyAdmin, verifiers[1]); // wsteth
            bytes32 merkleRoot;
            (merkleRoot, calls[1]) = _createAaveWstETHLoopingVerifier(vault.subvaultAt(1));
            IVerifier(verifiers[1]).setMerkleRoot(merkleRoot);
            address[] memory x = new address[](1);
            x[0] = Constants.WSTETH;
            riskManager.allowSubvaultAssets(vault.subvaultAt(1), x);
            riskManager.setSubvaultLimit(vault.subvaultAt(1), type(int256).max);
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
        timelockController.schedule(
            address(Subvault(payable(vault.subvaultAt(1))).verifier()),
            0,
            abi.encodeCall(IVerifier.setMerkleRoot, (bytes32(0))),
            bytes32(0),
            bytes32(0),
            0
        );
        {
            address[4] memory queues = [
                vault.queueAt(Constants.WSTETH, 0),
                vault.queueAt(Constants.WSTETH, 1),
                vault.queueAt(Constants.WETH, 0),
                vault.queueAt(Constants.ETH, 0)
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
        vault.renounceRole(Permissions.SET_MERKLE_ROOT_ROLE, deployer);

        console2.log("Vault %s", address(vault));

        console2.log("DepositQueue (ETH) %s", address(vault.queueAt(Constants.ETH, 0)));
        console2.log("DepositQueue (WETH) %s", address(vault.queueAt(Constants.WETH, 0)));
        console2.log("DepositQueue (WSTETH) %s", address(vault.queueAt(Constants.WSTETH, 0)));
        console2.log("RedeemQueue (WSTETH) %s", address(vault.queueAt(Constants.WSTETH, 1)));

        console2.log("Oracle %s", address(vault.oracle()));
        console2.log("ShareManager %s", address(vault.shareManager()));
        console2.log("FeeManager %s", address(vault.feeManager()));
        console2.log("RiskManager %s", address(vault.riskManager()));

        console2.log("Subvault 0 %s", address(vault.subvaultAt(0)));
        console2.log("Verifier 0 %s", address(Subvault(payable(vault.subvaultAt(0))).verifier()));

        console2.log("Subvault 1 %s", address(vault.subvaultAt(1)));
        console2.log("Verifier 1 %s", address(Subvault(payable(vault.subvaultAt(1))).verifier()));

        console2.log("Timelock controller:", address(timelockController));

        IDepositQueue(address(vault.queueAt(Constants.ETH, 0))).deposit{value: 1 gwei}(
            1 gwei, address(0), new bytes32[](0)
        );
        vm.stopBroadcast();
        AcceptanceLibrary.runProtocolDeploymentChecks(Constants.protocolDeployment());
        address[] memory redeemQueueAssets = new address[](1);
        redeemQueueAssets[0] = Constants.WSTETH;
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
                redeemQueueAssets: redeemQueueAssets,
                subvaultVerifiers: verifiers,
                timelockControllers: _makeArray(address(timelockController)),
                timelockProposers: _makeArray(lazyVaultAdmin, deployer),
                timelockExecutors: _makeArray(lidoPauser)
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
        /*
            1. weth.deposit{value: <any>}();
            2. weth.approve(cowswapVaultRelayer, <any>);
            3. cowswapSettlement.setPreSignature(anyBytes, anyBool); // bytes - fixed length always
            4. cowswapSettlement.invalidateOrder(anyBytes); // bytes - fixed length always    
        */
        ProtocolDeployment memory $ = Constants.protocolDeployment();

        string[] memory descriptions = strETHLibrary.getSubvault0Descriptions();
        (bytes32 merkleRoot, IVerifier.VerificationPayload[] memory leaves) = strETHLibrary.getSubvault0Proofs(curator);
        ProofLibrary.storeProofs("ethereum:strETH:subvault0", merkleRoot, leaves, descriptions);
        calls = strETHLibrary.getSubvault0SubvaultCalls($, curator, leaves);
        verifier = $.verifierFactory.create(0, proxyAdmin, abi.encode(vault, merkleRoot));
    }

    function _createAaveWstETHLoopingVerifier(address subvault)
        internal
        returns (bytes32 merkleRoot, SubvaultCalls memory calls)
    {
        /*
            erc20:
                1. approve wsteth to cowswap/aave
                2. approve weth to cowswap/aave

            cowswap:
                1. create order (wsteth<->weth)
                2. close order (wsteth<->weth)
                
            aave:
                1. supply(wsteth)
                2. borrow(weth)
                3. repay(weth)
                4. withdraw(wsteth)
        */
        ProtocolDeployment memory $ = Constants.protocolDeployment();

        string[] memory descriptions = strETHLibrary.getSubvault1Descriptions();
        IVerifier.VerificationPayload[] memory leaves;
        (merkleRoot, leaves) = strETHLibrary.getSubvault1Proofs(curator, subvault);
        ProofLibrary.storeProofs("ethereum:strETH:subvault1", merkleRoot, leaves, descriptions);
        calls = strETHLibrary.getSubvault1SubvaultCalls($, curator, subvault, leaves);
    }

    // function _createAaveEthenaLoopingVerifiers() internal returns (address verifier0, address verifier1) {
    //     /*
    //         strategy 1:
    //             in:
    //                 subvault 0:
    //                         wsteth.approve(aave, type(uint256).max)
    //                         aave.supply(wsteth, amount0)
    //                         aave.borrow(usdt, amount1)

    //                     pullLiquidity(usdt, amount1)

    //                 subvault 1:
    //                     pushLiquidity(usdt, amount1)

    //                         cowswap(usdt, usde, amount1 / 2)
    //                         cowswap(usdt, susde, amount1 / 2)
    //                         aave.setEMode(...)
    //                         aave.supply(usde, amount1 / 2)
    //                         aave.supply(susde, amount1 / 2)
    //                         aave.borrow(usdt)
    //                     repeat;

    //             out:
    //                 subvault 1:
    //                     aave.withdraw(usde, x)
    //                     aave.withdraw(susde, y)
    //                     cowswap(usde, usdt, x)
    //                     cowswap(susde, usdt, y)
    //                     aave.repay(usdt, x + y)
    //                 repeat;
    //                     pullLiquidity(usdt, amount1)

    //                 subvault 0:
    //                     pushLiquiditY(usdt, amount1)
    //                     aave.repay(usdt, amount1)
    //                 aave.withdraw(wsteth, amount0)
    //     */
    // }
}
