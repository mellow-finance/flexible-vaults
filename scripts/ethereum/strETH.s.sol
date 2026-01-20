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
    address public proxyAdmin = 0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0;
    address public lazyVaultAdmin = 0xAbE20D266Ae54b9Ae30492dEa6B6407bF18fEeb5;
    address public activeVaultAdmin = 0xeb1CaFBcC8923eCbc243ff251C385C201A6c734a;
    address public oracleUpdater = 0xd27fFB15Dd00D5E52aC2BFE6d5AFD36caE850081;
    address public curator = 0x5Dbf9287787A5825beCb0321A276C9c92d570a75;
    address public treasury = 0xb1E5a8F26C43d019f2883378548a350ecdD1423B;

    address public lidoPauser = 0xA916fD5252160A7E56A6405741De76dc0Da5A0Cd;
    address public mellowPauser = 0xa6278B726d4AA09D14f9E820D7785FAd82E7196F;

    uint256 public constant DEFAULT_MULTIPLIER = 0.995e8;

    // function _x() internal {
    //     address subvault = 0xCDfA7EfE670869c6b6be4375654E0b206eF49c89;
    //     IVerifier verifier = IVerifier(0x9C5D826e1BcdF67f0596725CbB931dC02132D88d);
    //     address swapModule = 0x2a166aE48F9F1FC27685582a61250011fd5363D8;

    //     bytes32 merkleRoot;
    //     SubvaultCalls memory calls;
    //     (merkleRoot, calls) = _createSubvault6Verifier(subvault, swapModule);
    //     vm.stopBroadcast();

    //     vm.startPrank(lazyVaultAdmin);
    //     verifier.setMerkleRoot(merkleRoot);
    //     vm.stopPrank();

    //     _verifyCalls(verifier, calls);
    // }

    // function _verifyCalls(IVerifier verifier, SubvaultCalls memory calls) internal view {
    //     for (uint256 i = 0; i < calls.payloads.length; i++) {
    //         AcceptanceLibrary._verifyCalls(verifier, calls.calls[i], calls.payloads[i]);
    //     }
    // }

    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);

        vm.startBroadcast(deployerPk);

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
            abi.encode(Constants.ETH, Constants.WETH, Constants.WSTETH, Constants.USDC, Constants.USDT, Constants.USDS)
        );

        ProtocolDeployment memory $ = Constants.protocolDeployment();
        VaultConfigurator.InitParams memory initParams = VaultConfigurator.InitParams({
            version: 0,
            proxyAdmin: proxyAdmin,
            vaultAdmin: lazyVaultAdmin,
            shareManagerVersion: 0,
            shareManagerParams: abi.encode(bytes32(0), "Mellow stRATEGY", "strETH"),
            feeManagerVersion: 0,
            feeManagerParams: abi.encode(deployer, treasury, uint24(0), uint24(0), uint24(1e5), uint24(1e4)),
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
        address[] memory verifiers = new address[](5);
        SubvaultCalls[] memory calls = new SubvaultCalls[](5);

        {
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

            {
                uint256 subvaultIndex = 2;
                verifiers[subvaultIndex] = $.verifierFactory.create(0, proxyAdmin, abi.encode(vault, bytes32(0)));
                address subvault = vault.createSubvault(0, proxyAdmin, verifiers[subvaultIndex]); // wsteth, usdc, usdt, usds, usdce
                bytes32 merkleRoot2;
                (merkleRoot2, calls[subvaultIndex]) = _createSubvault2Verifier(subvault);
                IVerifier(verifiers[subvaultIndex]).setMerkleRoot(merkleRoot2);
                riskManager.setSubvaultLimit(subvault, type(int256).max / 2);
                riskManager.allowSubvaultAssets(
                    subvault,
                    ArraysLibrary.makeAddressArray(
                        abi.encode(Constants.WSTETH, Constants.USDC, Constants.USDT, Constants.USDS, Constants.USDE)
                    )
                );
            }

            {
                uint256 subvaultIndex = 3;
                verifiers[subvaultIndex] = $.verifierFactory.create(0, proxyAdmin, abi.encode(vault, bytes32(0)));
                address subvault = vault.createSubvault(0, proxyAdmin, verifiers[subvaultIndex]); // usdc, usdt, usds, usde

                address swapModule = _deploySwapModule3(subvault);
                bytes32 merkleRoot3;
                (merkleRoot3, calls[subvaultIndex]) = _createSubvault3Verifier(subvault, swapModule);
                IVerifier(verifiers[subvaultIndex]).setMerkleRoot(merkleRoot3);
                riskManager.setSubvaultLimit(subvault, type(int256).max / 2);
                riskManager.allowSubvaultAssets(
                    subvault,
                    ArraysLibrary.makeAddressArray(
                        abi.encode(Constants.USDC, Constants.USDT, Constants.USDS, Constants.USDE)
                    )
                );
            }

            {
                uint256 subvaultIndex = 4;
                verifiers[subvaultIndex] = $.verifierFactory.create(0, proxyAdmin, abi.encode(vault, bytes32(0)));
                address subvault = vault.createSubvault(0, proxyAdmin, verifiers[subvaultIndex]); // weth, wsteth
                address swapModule = _deploySwapModule4(subvault);
                bytes32 merkleRoot;
                (merkleRoot, calls[subvaultIndex]) = _createSubvault4Verifier(subvault, swapModule);
                IVerifier(verifiers[subvaultIndex]).setMerkleRoot(merkleRoot);
                riskManager.allowSubvaultAssets(
                    subvault, ArraysLibrary.makeAddressArray(abi.encode(Constants.WETH, Constants.WSTETH))
                );
                riskManager.setSubvaultLimit(subvault, type(int256).max / 2);
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

        for (uint256 i = 0; i < vault.subvaults(); i++) {
            address subvault = vault.subvaultAt(i);
            console2.log("Subvault %s %s", i, subvault);
            console2.log("Verifier %s %s", i, address(Subvault(payable(subvault)).verifier()));
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
                    abi.encode(Constants.ETH, Constants.WETH, Constants.WSTETH)
                ),
                redeemQueueAssets: ArraysLibrary.makeAddressArray(abi.encode(Constants.WSTETH)),
                subvaultVerifiers: verifiers,
                timelockControllers: ArraysLibrary.makeAddressArray(abi.encode(address(timelockController))),
                timelockProposers: ArraysLibrary.makeAddressArray(abi.encode(lazyVaultAdmin, deployer)),
                timelockExecutors: ArraysLibrary.makeAddressArray(abi.encode(lidoPauser, mellowPauser))
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

    function _createSubvault0Verifier(address subvault, address swapModule)
        internal
        returns (bytes32 merkleRoot, SubvaultCalls memory calls)
    {
        console2.log("SwapModule 0: %s", swapModule);
        string[] memory descriptions = strETHLibrary.getSubvault0Descriptions(curator, subvault, swapModule);
        IVerifier.VerificationPayload[] memory leaves;
        (merkleRoot, leaves) = strETHLibrary.getSubvault0Proofs(curator, subvault, swapModule);
        ProofLibrary.storeProofs("ethereum:strETH:subvault0", merkleRoot, leaves, descriptions);
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
        ProofLibrary.storeProofs("ethereum:strETH:subvault1", merkleRoot, leaves, descriptions);
        calls = strETHLibrary.getSubvault1SubvaultCalls(curator, subvault, swapModule, leaves);
    }

    function _createSubvault2Verifier(address subvault)
        internal
        returns (bytes32 merkleRoot2, SubvaultCalls memory calls2)
    {
        string[] memory descriptions = strETHLibrary.getSubvault2Descriptions(curator, subvault);
        IVerifier.VerificationPayload[] memory leaves2;
        (merkleRoot2, leaves2) = strETHLibrary.getSubvault2Proofs(curator, subvault);
        ProofLibrary.storeProofs("ethereum:strETH:subvault2", merkleRoot2, leaves2, descriptions);
        calls2 = strETHLibrary.getSubvault2SubvaultCalls(curator, subvault, leaves2);
    }

    function _createSubvault3Verifier(address subvault, address swapModule)
        internal
        returns (bytes32 merkleRoot3, SubvaultCalls memory calls3)
    {
        console2.log("SwapModule 3: %s", swapModule);
        string[] memory descriptions = strETHLibrary.getSubvault3Descriptions(curator, subvault, swapModule);
        IVerifier.VerificationPayload[] memory leaves3;
        (merkleRoot3, leaves3) = strETHLibrary.getSubvault3Proofs(curator, subvault, swapModule);
        ProofLibrary.storeProofs("ethereum:strETH:subvault3", merkleRoot3, leaves3, descriptions);
        calls3 = strETHLibrary.getSubvault3SubvaultCalls(curator, subvault, swapModule, leaves3);
    }

    function _createSubvault4Verifier(address subvault, address swapModule)
        internal
        returns (bytes32 merkleRoot, SubvaultCalls memory calls)
    {
        console2.log("SwapModule 4: %s", swapModule);
        string[] memory descriptions = strETHLibrary.getSubvault4Descriptions(curator, subvault, swapModule);
        IVerifier.VerificationPayload[] memory leaves;
        (merkleRoot, leaves) = strETHLibrary.getSubvault4Proofs(curator, subvault, swapModule);
        ProofLibrary.storeProofs("ethereum:strETH:subvault4", merkleRoot, leaves, descriptions);
        calls = strETHLibrary.getSubvault4SubvaultCalls(curator, subvault, swapModule, leaves);
    }

    function _createSubvault5Verifier(address subvault, address swapModule)
        internal
        returns (bytes32 merkleRoot, SubvaultCalls memory calls)
    {
        console2.log("SwapModule 5: %s", swapModule);
        string[] memory descriptions = strETHLibrary.getSubvault5Descriptions(curator, subvault, swapModule);
        IVerifier.VerificationPayload[] memory leaves;
        (merkleRoot, leaves) = strETHLibrary.getSubvault5Proofs(curator, subvault, swapModule);
        ProofLibrary.storeProofs("ethereum:strETH:subvault5", merkleRoot, leaves, descriptions);
        calls = strETHLibrary.getSubvault5SubvaultCalls(curator, subvault, swapModule, leaves);
    }

    function _createSubvault6Verifier(address subvault, address swapModule)
        internal
        returns (bytes32 merkleRoot, SubvaultCalls memory calls)
    {
        console2.log("SwapModule 6: %s", swapModule);
        string[] memory descriptions = strETHLibrary.getSubvault6Descriptions(curator, subvault, swapModule);
        IVerifier.VerificationPayload[] memory leaves;
        (merkleRoot, leaves) = strETHLibrary.getSubvault6Proofs(curator, subvault, swapModule);
        ProofLibrary.storeProofs("ethereum:strETH:subvault6", merkleRoot, leaves, descriptions);
        calls = strETHLibrary.getSubvault6SubvaultCalls(curator, subvault, swapModule, leaves);
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

    function _deploySwapModule3(address subvault) internal returns (address swapModule) {
        return _deployEthenaLeverageSwapModule(subvault);
    }

    function _deploySwapModule4(address subvault) internal returns (address swapModule) {
        return _deployLidoLeverageSwapModule(subvault);
    }

    function _deploySwapModule5(address subvault) internal returns (address swapModule) {
        return _deployEthenaLeverageSwapModule(subvault);
    }

    function _deploySwapModule6(address subvault) internal returns (address swapModule) {
        return _deployRsETHLeverageSwapModule(subvault);
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

    function _deployEthenaLeverageSwapModule(address subvault) internal returns (address) {
        IFactory swapModuleFactory = Constants.protocolDeployment().swapModuleFactory;
        address[5] memory ethenaLeverage =
            [Constants.USDC, Constants.USDT, Constants.USDS, Constants.USDE, Constants.SUSDE];
        address[] memory actors =
            ArraysLibrary.makeAddressArray(abi.encode(curator, ethenaLeverage, ethenaLeverage, _routers()));

        bytes32[] memory permissions = ArraysLibrary.makeBytes32Array(
            abi.encode(
                [Permissions.SWAP_MODULE_CALLER_ROLE],
                [
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
                    Permissions.SWAP_MODULE_TOKEN_OUT_ROLE
                ],
                [
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

    function _deployRsETHLeverageSwapModule(address subvault) internal returns (address) {
        IFactory swapModuleFactory = Constants.protocolDeployment().swapModuleFactory;
        address[2] memory lidoLeverage = [Constants.WETH, Constants.RSETH];
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
