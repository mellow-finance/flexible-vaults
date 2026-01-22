// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";

import "../../src/oracles/OracleSubmitter.sol";
import "../../src/vaults/Subvault.sol";
import "../../src/vaults/VaultConfigurator.sol";

import "../common/AcceptanceLibrary.sol";
import "../common/Permissions.sol";
import "../common/ProofLibrary.sol";

import "./Constants.sol";
import "./msvUSDLibrary.sol";

import "../common/ArraysLibrary.sol";

contract Deploy is Script, Test {
    // Actors
    address public proxyAdmin = 0x54977739CF18B316f47B1e10E3068Bb3F04e08B6;
    address public lazyVaultAdmin = 0x0571A6ca8e1AD9822FA69e9cb7854110FD77d24d;
    address public activeVaultAdmin = 0x0f01301a869B7C15a782bd2e60beB08C8709CC08;
    address public oracleUpdater = 0x96ff6055DFdcd0d370D77b6dCd6a465438A613D5;
    address public curator = 0x3c9B9D820188fF57c8482EbFdF1093b1EFeFf068;

    address public pauser = 0x2EE0AB05EB659E0681DC5f2EabFf1F4D284B3Ef7;

    Vault public vault = Vault(payable(0x7207595E4c18a9A829B9dc868F11F3ADd8FCF626));

    address arbitrumSubvault0 = 0x9214Fb3563BC6FE429c608071CBc5278b0e43639;

    function _x() internal {
        OracleSubmitter submitter = new OracleSubmitter(
            lazyVaultAdmin, oracleUpdater, activeVaultAdmin, 0xccB10707cc3105178CBef8ee5b7DC84D5d1b277F
        );

        console2.log("submitter: %s", address(submitter));
    }

    function run() external {
        _createSubvault0Proofs();
        revert("ok");
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);

        vm.startBroadcast(deployerPk);

        if (true) {
            _x();
            return;
        }

        Vault.RoleHolder[] memory holders = new Vault.RoleHolder[](42);
        TimelockController timelockController;

        {
            address[] memory proposers = ArraysLibrary.makeAddressArray(abi.encode(lazyVaultAdmin, deployer));
            address[] memory executors = ArraysLibrary.makeAddressArray(abi.encode(pauser));
            timelockController = new TimelockController(0, proposers, executors, lazyVaultAdmin);
        }
        {
            uint256 i = 0;

            // lazyVaultAdmin roles:
            holders[i++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, lazyVaultAdmin);
            holders[i++] = Vault.RoleHolder(Permissions.ALLOW_CALL_ROLE, lazyVaultAdmin);
            holders[i++] = Vault.RoleHolder(Permissions.DISALLOW_CALL_ROLE, lazyVaultAdmin);
            holders[i++] = Vault.RoleHolder(Permissions.CREATE_SUBVAULT_ROLE, lazyVaultAdmin);
            holders[i++] = Vault.RoleHolder(Permissions.ALLOW_SUBVAULT_ASSETS_ROLE, activeVaultAdmin);
            holders[i++] = Vault.RoleHolder(Permissions.SET_SUBVAULT_LIMIT_ROLE, activeVaultAdmin);

            // activeVaultAdmin roles:
            holders[i++] = Vault.RoleHolder(Permissions.ACCEPT_REPORT_ROLE, activeVaultAdmin);
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
            holders[i++] = Vault.RoleHolder(Permissions.ALLOW_SUBVAULT_ASSETS_ROLE, deployer);
            holders[i++] = Vault.RoleHolder(Permissions.SET_SUBVAULT_LIMIT_ROLE, deployer);
            holders[i++] = Vault.RoleHolder(Permissions.SUBMIT_REPORTS_ROLE, deployer);
            holders[i++] = Vault.RoleHolder(Permissions.ACCEPT_REPORT_ROLE, deployer);
            assembly {
                mstore(holders, i)
            }
        }
        address[] memory assets_ =
            ArraysLibrary.makeAddressArray(abi.encode(Constants.USDC, Constants.USDT, Constants.MUSD));

        ProtocolDeployment memory $ = Constants.protocolDeployment();
        VaultConfigurator.InitParams memory initParams = VaultConfigurator.InitParams({
            version: 0,
            proxyAdmin: proxyAdmin,
            vaultAdmin: lazyVaultAdmin,
            shareManagerVersion: 0,
            shareManagerParams: abi.encode(bytes32(0), "Mezo Stable Vault", "msvUSD"),
            feeManagerVersion: 0,
            feeManagerParams: abi.encode(deployer, lazyVaultAdmin, uint24(0), uint24(0), uint24(0), uint24(5e3)),
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
                    redeemInterval: 72 hours
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
        vault.createQueue(0, true, proxyAdmin, Constants.USDC, new bytes(0));
        vault.createQueue(0, true, proxyAdmin, Constants.USDT, new bytes(0));
        vault.createQueue(0, true, proxyAdmin, Constants.MUSD, new bytes(0));
        vault.createQueue(0, false, proxyAdmin, Constants.USDC, new bytes(0));
        vault.createQueue(0, false, proxyAdmin, Constants.USDT, new bytes(0));
        vault.createQueue(0, false, proxyAdmin, Constants.MUSD, new bytes(0));

        // fee manager setup
        vault.feeManager().setBaseAsset(address(vault), Constants.USDC);
        Ownable(address(vault.feeManager())).transferOwnership(lazyVaultAdmin);

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

        {
            address[6] memory queues = [
                vault.queueAt(Constants.USDC, 0),
                vault.queueAt(Constants.USDT, 0),
                vault.queueAt(Constants.MUSD, 0),
                vault.queueAt(Constants.USDC, 1),
                vault.queueAt(Constants.USDT, 1),
                vault.queueAt(Constants.MUSD, 1)
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
        vault.renounceRole(Permissions.SET_SUBVAULT_LIMIT_ROLE, deployer);
        vault.renounceRole(Permissions.SET_MERKLE_ROOT_ROLE, deployer);

        console2.log("Vault %s", address(vault));

        console2.log("DepositQueue (USDC) %s", address(vault.queueAt(Constants.USDC, 0)));
        console2.log("DepositQueue (USDT) %s", address(vault.queueAt(Constants.USDT, 0)));
        console2.log("DepositQueue (MUSD) %s", address(vault.queueAt(Constants.MUSD, 0)));

        console2.log("RedeemQueue (USDC) %s", address(vault.queueAt(Constants.USDC, 1)));
        console2.log("RedeemQueue (USDT) %s", address(vault.queueAt(Constants.USDT, 1)));
        console2.log("RedeemQueue (MUSD) %s", address(vault.queueAt(Constants.MUSD, 1)));

        console2.log("Oracle %s", address(vault.oracle()));
        console2.log("ShareManager %s", address(vault.shareManager()));
        console2.log("FeeManager %s", address(vault.feeManager()));
        console2.log("RiskManager %s", address(vault.riskManager()));

        console2.log("Timelock controller:", address(timelockController));

        {
            IOracle.Report[] memory reports = new IOracle.Report[](assets_.length);
            for (uint256 i = 0; i < reports.length; i++) {
                reports[i].asset = assets_[i];
            }
            reports[0].priceD18 = 1e30;
            reports[1].priceD18 = 1e30;
            reports[2].priceD18 = 1 ether;

            IOracle oracle = vault.oracle();
            oracle.submitReports(reports);
            // uint256 timestamp = oracle.getReport(Constants.USDC).timestamp;
            // for (uint256 i = 0; i < reports.length; i++) {
            //     oracle.acceptReport(reports[i].asset, reports[i].priceD18, uint32(timestamp));
            // }
        }

        vault.renounceRole(Permissions.SUBMIT_REPORTS_ROLE, deployer);
        vault.renounceRole(Permissions.ACCEPT_REPORT_ROLE, deployer);

        revert("ok");
    }

    function _createSubvault0() internal {
        IRiskManager riskManager = vault.riskManager();
        vm.startPrank(lazyVaultAdmin);

        vault.grantRole(Permissions.ALLOW_SUBVAULT_ASSETS_ROLE, lazyVaultAdmin);
        vault.grantRole(Permissions.SET_SUBVAULT_LIMIT_ROLE, lazyVaultAdmin);
        address verifier = vault.verifierFactory().create(0, proxyAdmin, abi.encode(vault, bytes32(0)));

        address subvault0 = vault.createSubvault(0, proxyAdmin, verifier);
        riskManager.allowSubvaultAssets(
            subvault0, ArraysLibrary.makeAddressArray(abi.encode(Constants.USDC, Constants.USDT))
        );
        riskManager.setSubvaultLimit(subvault0, type(int256).max / 2);
        vm.stopPrank();
    }

    function _deploySwapModule(address subvault) internal returns (address swapModule, address[] memory assets) {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);

        IFactory swapModuleFactory = Constants.protocolDeployment().swapModuleFactory;
        address[3] memory tokens = [Constants.USDT, Constants.USDC, Constants.CRV];
        address[] memory actors =
            ArraysLibrary.makeAddressArray(abi.encode(curator, tokens, tokens, Constants.KYBERSWAP_ROUTER));
        bytes32[] memory permissions = ArraysLibrary.makeBytes32Array(
            abi.encode(
                Permissions.SWAP_MODULE_CALLER_ROLE,
                Permissions.SWAP_MODULE_TOKEN_IN_ROLE,
                Permissions.SWAP_MODULE_TOKEN_IN_ROLE,
                Permissions.SWAP_MODULE_TOKEN_IN_ROLE,
                Permissions.SWAP_MODULE_TOKEN_OUT_ROLE,
                Permissions.SWAP_MODULE_TOKEN_OUT_ROLE,
                Permissions.SWAP_MODULE_TOKEN_OUT_ROLE,
                Permissions.SWAP_MODULE_ROUTER_ROLE
            )
        );

        vm.startBroadcast(deployerPk);
        swapModule = swapModuleFactory.create(
            0, proxyAdmin, abi.encode(lazyVaultAdmin, subvault, Constants.AAVE_V3_ORACLE, 0.995e8, actors, permissions)
        );
        vm.stopBroadcast();
        return (swapModule, ArraysLibrary.makeAddressArray(abi.encode(tokens)));
    }

    function _createSubvault0Proofs() internal returns (bytes32 merkleRoot, SubvaultCalls memory calls) {
        address payable subvault0Mainnet = payable(vault.subvaultAt(0));
        (address swapModule, address[] memory swapModuleAssets) = _deploySwapModule(subvault0Mainnet);

        msvUSDLibrary.Info memory info = msvUSDLibrary.Info({
            curator: curator,
            subvaultEth: subvault0Mainnet,
            subvaultArb: arbitrumSubvault0,
            swapModule: swapModule,
            subvaultEthName: "subvault0:ethereum",
            subvaultArbName: "subvault0:arbitrum",
            targetChainName: "Arbitrum",
            oftUSDT: Constants.ETHEREUM_USDT_OFT_ADAPTER,
            fUSDT: Constants.ETHEREUM_FLUID_USDT_FTOKEN,
            fUSDC: Constants.ETHEREUM_FLUID_USDC_FTOKEN,
            swapModuleAssets: swapModuleAssets,
            kyberRouter: Constants.KYBERSWAP_ROUTER,
            kyberSwapAssets: ArraysLibrary.makeAddressArray(abi.encode(Constants.FLUID))
        });

        IVerifier.VerificationPayload[] memory leaves;
        (merkleRoot, leaves) = msvUSDLibrary.getSubvault0Proofs(info);

        IVerifier verifier = Subvault(subvault0Mainnet).verifier();

        vm.startPrank(lazyVaultAdmin);
        verifier.setMerkleRoot(merkleRoot);
        vm.stopPrank();

        console2.log("Subvault0 Merkle Root at verifier %s:", address(verifier));
        console2.logBytes32(merkleRoot);

        string[] memory descriptions = msvUSDLibrary.getSubvault0Descriptions(info);
        ProofLibrary.storeProofs("ethereum:msvUSD:subvault0", merkleRoot, leaves, descriptions);

        calls = msvUSDLibrary.getSubvault0Calls(info, leaves);

        _runChecks(verifier, calls);
    }

    function _runChecks(IVerifier verifier, SubvaultCalls memory calls) internal view {
        for (uint256 i = 0; i < calls.payloads.length; i++) {
            AcceptanceLibrary._verifyCalls(verifier, calls.calls[i], calls.payloads[i]);
        }
    }
}
