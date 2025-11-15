// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../common/interfaces/IAavePoolV3.sol";
import "../common/interfaces/ICowswapSettlement.sol";
import {IWETH as WETHInterface} from "../common/interfaces/IWETH.sol";

import "../collectors/defi/external/IAaveOracleV3.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";

import "../../src/vaults/Subvault.sol";
import "../../src/vaults/VaultConfigurator.sol";

import "../../scripts/collectors/Collector.sol";
import "../common/AcceptanceLibrary.sol";
import "../common/Permissions.sol";
import "../common/ProofLibrary.sol";
import "forge-std/Script.sol";

import "./Constants.sol";
import {monLibrary} from "./monLibrary.sol";

contract Deploy is Script {
    // Actors
    address public deployer;
    address public testEOA = address(0xEcA63DEc77E59EFB15196A610aefF3229Ecd44Ec);
    address public proxyAdmin = testEOA;
    address public lazyVaultAdmin = testEOA;
    address public activeVaultAdmin = testEOA;
    address public oracleUpdater = testEOA;
    address public curator = testEOA;
    address public pauser = testEOA;

    function run() external {
        makeSupply();
        //return;
        revert("ok");

        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        deployer = vm.addr(deployerPk);

        vm.startBroadcast(deployerPk);
        deployMonadTestnet();
        vm.stopBroadcast();
        //  revert("ok");
    }

    function deployMonadTestnet() internal {
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
        address[] memory assets_ = ArraysLibrary.makeAddressArray(
            abi.encode(Constants.ETH, Constants.WETH, Constants.WBTC, Constants.USDC, Constants.USDT)
        );

        address[] memory depositAssets = ArraysLibrary.makeAddressArray(abi.encode(Constants.ETH, Constants.WETH));

        address[] memory withdrawAssets = ArraysLibrary.makeAddressArray(abi.encode(Constants.WETH));

        ProtocolDeployment memory $ = Constants.protocolDeployment();
        VaultConfigurator.InitParams memory initParams = VaultConfigurator.InitParams({
            version: 0,
            proxyAdmin: proxyAdmin,
            vaultAdmin: lazyVaultAdmin,
            shareManagerVersion: 0,
            shareManagerParams: abi.encode(bytes32(0), "Monad Test Vault", "tvMON"),
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
                    timeout: 1 minutes,
                    depositInterval: 1 minutes,
                    redeemInterval: 1 minutes
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
        {
            // deposit queues setup
            for (uint256 i = 0; i < depositAssets.length; i++) {
                vault.createQueue(0, true, proxyAdmin, depositAssets[i], new bytes(0));
            }
            // withdraw queues setup
            for (uint256 i = 0; i < withdrawAssets.length; i++) {
                vault.createQueue(0, false, proxyAdmin, withdrawAssets[i], new bytes(0));
            }
        }

        // fee manager setup
        vault.feeManager().setBaseAsset(address(vault), Constants.ETH);
        Ownable(address(vault.feeManager())).transferOwnership(lazyVaultAdmin);

        // subvault setup
        address verifier;
        SubvaultCalls[] memory calls = new SubvaultCalls[](1);

        {
            IRiskManager riskManager = vault.riskManager();
            (verifier, calls[0]) = _createVerifier(address(vault));
            vault.createSubvault(0, proxyAdmin, verifier); // mon,wmon,usdc,usdt
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

        for (uint256 i = 0; i < assets_.length; i++) {
            if (vault.getQueueCount(assets_[i]) > 0) {
                address queue = vault.queueAt(assets_[i], 0);
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

        console2.log("Vault %s", address(vault));

        for (uint256 i = 0; i < depositAssets.length; i++) {
            console2.log(
                "DepositQueue (%s) %s", getSymbol(depositAssets[i]), address(vault.queueAt(depositAssets[i], 0))
            );
        }
        for (uint256 i = 0; i < withdrawAssets.length; i++) {
            console2.log(
                "RedeemQueue (%s) %s", getSymbol(withdrawAssets[i]), address(vault.queueAt(withdrawAssets[i], 1))
            );
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

        {
            IOracle.Report[] memory reports = new IOracle.Report[](assets_.length);
            for (uint256 i = 0; i < assets_.length; i++) {
                reports[i].asset = assets_[i];
            }
            reports[0].priceD18 = 1 ether;
            reports[1].priceD18 = 1 ether;
            IAaveOracleV3 aaveOracle = IAaveOracleV3(Constants.AAVE_V3_ORACLE);

            reports[2].priceD18 = uint224(
                Math.mulDiv(1 ether, aaveOracle.getAssetPrice(Constants.WBTC), aaveOracle.getAssetPrice(Constants.WETH))
            );
            reports[3].priceD18 = uint224(
                Math.mulDiv(1 ether, aaveOracle.getAssetPrice(Constants.USDC), aaveOracle.getAssetPrice(Constants.WETH))
            );
            reports[4].priceD18 = uint224(
                Math.mulDiv(1 ether, aaveOracle.getAssetPrice(Constants.USDT), aaveOracle.getAssetPrice(Constants.WETH))
            );
            IOracle oracle = vault.oracle();
            oracle.submitReports(reports);
            /* uint256 timestamp = oracle.getReport(Constants.ETH).timestamp;
            for (uint256 i = 0; i < reports.length; i++) {
                oracle.acceptReport(reports[i].asset, reports[i].priceD18, uint32(timestamp));
            } */
        }

        vault.renounceRole(Permissions.SUBMIT_REPORTS_ROLE, deployer);
        vault.renounceRole(Permissions.ACCEPT_REPORT_ROLE, deployer);

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
                depositQueueAssets: depositAssets,
                redeemQueueAssets: withdrawAssets,
                subvaultVerifiers: ArraysLibrary.makeAddressArray(abi.encode(verifier)),
                timelockControllers: ArraysLibrary.makeAddressArray(abi.encode(timelockController)),
                timelockProposers: ArraysLibrary.makeAddressArray(abi.encode(lazyVaultAdmin, deployer)),
                timelockExecutors: ArraysLibrary.makeAddressArray(abi.encode(lazyVaultAdmin))
            })
        );
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

    function _createVerifier(address vault) internal returns (address verifier, SubvaultCalls memory calls) {
        ProtocolDeployment memory $ = Constants.protocolDeployment();
        /*
            1. weth.deposit{value: <any>}();
            2. weth.withdraw(<any>);
            3. aave proofs
        */
        monLibrary.Info memory info = monLibrary.Info({
            subvault: vault,
            subvaultName: "subvault0",
            curator: curator,
            aaveInstance: Constants.AAVE_CORE,
            aaveInstanceName: "regular",
            collaterals: ArraysLibrary.makeAddressArray(abi.encode(Constants.WETH, Constants.USDC, Constants.USDT)),
            loans: ArraysLibrary.makeAddressArray(abi.encode(Constants.WBTC, Constants.USDC, Constants.USDT))
        });
        string[] memory descriptions = monLibrary.getSubvault0Descriptions(info);
        (bytes32 merkleRoot, IVerifier.VerificationPayload[] memory leaves) = monLibrary.getSubvault0Proofs(info);
        ProofLibrary.storeProofs("monad:mon:subvault0", merkleRoot, leaves, descriptions);
        calls = monLibrary.getSubvault0SubvaultCalls(info, leaves);
        verifier = $.verifierFactory.create(0, proxyAdmin, abi.encode(vault, merkleRoot));
    }

    function getSymbol(address token) internal view returns (string memory) {
        if (token == Constants.ETH) {
            return "MON";
        } else {
            return IERC20Metadata(token).symbol();
        }
    }

    function action() internal {
        /*
            Vault 0x8769b724e264D38d0d70eD16F965FA9Fa680EcDe
            DepositQueue (MON) 0xDaC0Fc37994Af060b2a13D7F2E2f45cCc9a7AE4F
            DepositQueue (WMON) 0x45023d2CbbcC62B8B05347a652E195cb8A0F6aB6
            RedeemQueue (WMON) 0x74820486AE498AEF97C7Af6Bc4017c1312EfebE1
            Oracle 0x31E92B97a3EAC3a33b579a83D38C75519A71D6F7
            ShareManager 0xD031137112Af2969892ea66764ED447317f6489F
            FeeManager 0x2Dbc6584d82F649c698215876e771Df691420977
            RiskManager 0x725F5c87BE5f12bb26346694590d254EA0330593
            Subvault 0 0x8e2D23E6A59EffD2fd55CE3020c28eC650F2fbc5
            Verifier 0 0xf99362EEAc9d3597608f58FefD83b3cB8BAA39CD
            Timelock controller: 0x5283C7B1d1569EfCF8A35dD16c9e7253911b5afa
        */
        Vault vault = Vault(payable(0x8769b724e264D38d0d70eD16F965FA9Fa680EcDe));
        IOracle oracle = vault.oracle();
        address[] memory assets = ArraysLibrary.makeAddressArray(
            abi.encode(Constants.ETH, Constants.WETH, Constants.WBTC, Constants.USDC, Constants.USDT)
        );

        uint256 timestamp = oracle.getReport(Constants.ETH).timestamp;

        uint256 deployerPK = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        uint256 adminPK = uint256(bytes32(vm.envBytes("MONAD_TEST_ADMIN")));
        address admin = vm.addr(adminPK);

        vm.startBroadcast(adminPK);
        for (uint256 i = 0; i < assets.length; i++) {
            IOracle.DetailedReport memory report = oracle.getReport(assets[i]);
            if (report.isSuspicious) {
                oracle.acceptReport(assets[i], report.priceD18, uint32(report.timestamp));
            }
        }
        vm.stopBroadcast();

        vm.startBroadcast(deployerPK);
        IDepositQueue(address(vault.queueAt(Constants.ETH, 0))).deposit{value: 0.001 ether}(
            0.001 ether, address(0), new bytes32[](0)
        );
        vm.stopBroadcast();
    }

    function pushReport() internal {
        Vault vault = Vault(payable(0x8769b724e264D38d0d70eD16F965FA9Fa680EcDe));

        uint256 deployerPK = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        /*         vm.startBroadcast(deployerPK);
        IDepositQueue(address(vault.queueAt(Constants.ETH, 0))).deposit{value: 0.001 ether}(
            0.001 ether, address(0), new bytes32[](0)
        );
        vm.stopBroadcast(); */

        IOracle oracle = vault.oracle();
        address[] memory assets = ArraysLibrary.makeAddressArray(
            abi.encode(Constants.ETH, Constants.WETH, Constants.WBTC, Constants.USDC, Constants.USDT)
        );

        IOracle.Report[] memory reports = new IOracle.Report[](assets.length);
        for (uint256 i = 0; i < assets.length; i++) {
            IOracle.DetailedReport memory report = oracle.getReport(assets[i]);
            reports[i] = IOracle.Report({asset: assets[i], priceD18: report.priceD18});
        }
        uint256 adminPK = uint256(bytes32(vm.envBytes("MONAD_TEST_ADMIN")));
        address admin = vm.addr(adminPK);

        vm.startBroadcast(adminPK);
        oracle.submitReports(reports);
        vm.stopBroadcast();
    }

    function makeDepositCall() internal {
        /* Collector(0x20Cc87d330400DC051b7dcA2Ae8d2005cb4894D6).collect(
            address(0),
            Vault(payable(0x8769b724e264D38d0d70eD16F965FA9Fa680EcDe)),
            Collector.Config({baseAssetFallback: Constants.WETH, oracleUpdateInterval: 60, redeemHandlingInterval: 60})
        ); */

        uint256 adminPK = uint256(bytes32(vm.envBytes("MONAD_TEST_ADMIN")));
        address admin = vm.addr(adminPK);

        Vault vault = Vault(payable(0x8769b724e264D38d0d70eD16F965FA9Fa680EcDe));
        address subvault = vault.subvaultAt(0);
        bytes memory verificationData =
            hex"0000000000000000000000007eba8f20eba1b62e894c6877de5fa48ac85d6ee46daeda26d0c877ec0c1ec8663856c7d6727976954295c462e71224d47bc1bca600000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000064ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000000000000000ffffffff00000000000000000000000000000000000000000000000000000000";
        bytes32[] memory proof = new bytes32[](5);
        proof[0] = 0x469b06fde976ddccfb355cf49c423cd217ba25c9553567d2eb2af585ddc5f665;
        proof[1] = 0xd42b361e96964f59ea2053a3ac26f6d6e3b2ae073e0a390d4a79d1a02d704aca;
        proof[2] = 0xe9f7b63e759c6eeb65ced8a29daa38174ec273d9b6ad9763f196d05db84e4731;
        proof[3] = 0x59fc257cf3960d377df9bebb00103269d4fdae9fd205275906e27805e1d66001;
        proof[4] = 0x0caa6966f935e3de9d5afa753ee3dda575e47dfb8e21d427384c1efa71fca16c;
        vm.startBroadcast(adminPK);
        bytes memory data = abi.encodeCall(WETHInterface.deposit, ());
        CallModule(payable(subvault)).call(
            Constants.WETH,
            0.001 ether,
            data,
            IVerifier.VerificationPayload({
                verificationType: IVerifier.VerificationType.CUSTOM_VERIFIER,
                verificationData: verificationData,
                proof: proof
            })
        );
        vm.stopBroadcast();
    }

    function makeSupply() internal {
        uint256 adminPK = uint256(bytes32(vm.envBytes("MONAD_TEST_ADMIN")));
        address admin = vm.addr(adminPK);

        Vault vault = Vault(payable(0x8769b724e264D38d0d70eD16F965FA9Fa680EcDe));
        address subvault = vault.subvaultAt(0);
        bytes memory verificationData =
            hex"0000000000000000000000007eba8f20eba1b62e894c6877de5fa48ac85d6ee41639bbb8aafe508654ed48f1d4e33036da64ce80216aadfa89e0909b6471e309000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000e4ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000ffffffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
        bytes32[] memory proof = new bytes32[](4);
        proof[0] = 0xbcecc9d1a41f8ae2cd1c6df18b948334d27d8d1780da606edfa872fb4aa85707;
        proof[1] = 0xa88b15b9f364c371f5d3c052545f9a8cefa14eb66b3e0de52a8f06f23730585e;
        proof[2] = 0xc9f37d019f9f7d1939dca0f2304982735fec1f1a028de191bc47c0dea575af24;
        proof[3] = 0xfcbfe9567c49a6753a0275bd6b6a3fbf1fa0821ebc1dc940c300f7ff79132f99;
        vm.startBroadcast(adminPK);
        bytes memory data = abi.encodeCall(IAavePoolV3.supply, (Constants.WETH, 0.001 ether, subvault, 0));
        CallModule(payable(subvault)).call(
            Constants.WETH,
            0,
            data,
            IVerifier.VerificationPayload({
                verificationType: IVerifier.VerificationType.CUSTOM_VERIFIER,
                verificationData: verificationData,
                proof: proof
            })
        );
        vm.stopBroadcast();
    }
}
