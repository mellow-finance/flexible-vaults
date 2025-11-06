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

import "../common/ArraysLibrary.sol";

import "../common/protocols/BracketVaultLibrary.sol";
import "../common/protocols/CurveLibrary.sol";

import "../common/protocols/DigiFTILibrary.sol";
import "../common/protocols/ERC4626Library.sol";
import "../common/protocols/TermMaxLibrary.sol";

import "./mAlphaLibrary.sol";

contract Deploy is Script {
    // Actors
    address public proxyAdmin = 0xEB4Af6fA3AFA08B10d593EC8fF87efB03BC04645;
    address public lazyVaultAdmin = 0xEB4Af6fA3AFA08B10d593EC8fF87efB03BC04645;
    address public activeVaultAdmin = 0xEB4Af6fA3AFA08B10d593EC8fF87efB03BC04645;
    address public oracleUpdater = 0xEB4Af6fA3AFA08B10d593EC8fF87efB03BC04645;
    address public pauser = 0xEB4Af6fA3AFA08B10d593EC8fF87efB03BC04645;

    address public curator = 0x6788c8ad65E85CCa7224a0B46D061EF7D81F9Da5;

    address public feeManagerAdmin = 0xb1E5a8F26C43d019f2883378548a350ecdD1423B;
    address public treasury = 0xb1E5a8F26C43d019f2883378548a350ecdD1423B;

    address public constant market = 0x1B7F1Fb1AC54396B3039A817714d8a7176099328;

    function run() external {
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
        address[] memory assets_ = ArraysLibrary.makeAddressArray(abi.encode(Constants.USDC));

        ProtocolDeployment memory $ = Constants.protocolDeployment();
        VaultConfigurator.InitParams memory initParams = VaultConfigurator.InitParams({
            version: 0,
            proxyAdmin: proxyAdmin,
            vaultAdmin: lazyVaultAdmin,
            shareManagerVersion: 0,
            shareManagerParams: abi.encode(bytes32(0), "Alpha Mellow Core", "mAlpha"),
            feeManagerVersion: 0,
            feeManagerParams: abi.encode(deployer, treasury, uint24(0), uint24(0), uint24(0), uint24(1e4)),
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
            queueLimit: 8,
            roleHolders: holders
        });

        Vault vault;
        {
            (,,,, address vault_) = $.vaultConfigurator.create(initParams);
            vault = Vault(payable(vault_));
        }

        // queues setup
        vault.createQueue(0, true, proxyAdmin, Constants.USDC, new bytes(0));
        vault.createQueue(0, false, proxyAdmin, Constants.USDC, new bytes(0));

        // fee manager setup
        vault.feeManager().setBaseAsset(address(vault), Constants.USDC);
        Ownable(address(vault.feeManager())).transferOwnership(feeManagerAdmin);

        // subvault setup
        address[] memory verifiers = new address[](1);
        SubvaultCalls[] memory calls = new SubvaultCalls[](1);

        IRiskManager riskManager = vault.riskManager();
        {
            verifiers[0] = $.verifierFactory.create(0, proxyAdmin, abi.encode(vault, bytes32(0)));
            vault.createSubvault(0, proxyAdmin, verifiers[0]);
            bytes32 merkleRoot;
            (merkleRoot, calls[0]) = _createSubvault0Verifier(vault.subvaultAt(0));
            IVerifier(verifiers[0]).setMerkleRoot(merkleRoot);
            riskManager.allowSubvaultAssets(
                vault.subvaultAt(0), ArraysLibrary.makeAddressArray(abi.encode(Constants.USDC))
            );
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
        for (uint256 i = 0; i < assets_.length; i++) {
            address asset = assets_[i];
            uint256 count = vault.getQueueCount(asset);
            for (uint256 j = 0; j < count; j++) {
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

        string memory symbol = IERC20Metadata(Constants.USDC).symbol();
        for (uint256 j = 0; j < vault.getQueueCount(Constants.USDC); j++) {
            address queue = vault.queueAt(Constants.USDC, j);
            if (vault.isDepositQueue(queue)) {
                console2.log("DepositQueue (%s): %s", symbol, queue);
            } else {
                console2.log("RedeemQueue (%s): %s", symbol, queue);
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

        {
            IOracle.Report[] memory reports = new IOracle.Report[](assets_.length);
            for (uint256 i = 0; i < reports.length; i++) {
                reports[i].asset = assets_[i];
            }
            // abi.encode(Constants.USDC)
            reports[0].priceD18 = 1e30;

            IOracle oracle = vault.oracle();
            oracle.submitReports(reports);
            uint256 timestamp = oracle.getReport(Constants.USDC).timestamp;
            for (uint256 i = 0; i < reports.length; i++) {
                oracle.acceptReport(reports[i].asset, reports[i].priceD18, uint32(timestamp));
            }
        }

        vault.renounceRole(Permissions.SUBMIT_REPORTS_ROLE, deployer);
        vault.renounceRole(Permissions.ACCEPT_REPORT_ROLE, deployer);

        IERC20(Constants.USDC).approve(address(vault.queueAt(Constants.USDC, 0)), 1e6);
        IDepositQueue(address(vault.queueAt(Constants.USDC, 0))).deposit(1e6, address(0), new bytes32[](0));
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
                subvaultVerifiers: verifiers,
                timelockControllers: ArraysLibrary.makeAddressArray(abi.encode(address(timelockController))),
                timelockProposers: ArraysLibrary.makeAddressArray(abi.encode(lazyVaultAdmin, deployer)),
                timelockExecutors: ArraysLibrary.makeAddressArray(abi.encode(pauser))
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

    function _createSubvault0Verifier(address subvault0)
        internal
        returns (bytes32 merkleRoot, SubvaultCalls memory calls)
    {
        /*
            0. IERC20(USDC).approve(UMINT_ENTRY, ...)
            1. IERC20(uMINT).approve(TERMMAX_ROUTER, ...)
            2. IERC20(USDU).approve(CURVE_POOL, ...)
            3. UMINT_ENTRY.subscribe(UMINT, USDC, ...) / UMINT_ENTRY.redeem(UMINT, USDC, ...)
            4. TERMMAX_ROUTER.borrowTokenFromCollateral(subvault0, MARKET, ...) (uMINT->USDU)
            5. Swap USDU for USDC on Curve
        */
        string[] memory descriptions = mAlphaUMINTLibrary.getSubvault0Descriptions(
            mAlphaUMINTLibrary.Info({curator: curator, subvault: subvault0, market: market})
        );
        IVerifier.VerificationPayload[] memory leaves;
        (merkleRoot, leaves) = mAlphaUMINTLibrary.getSubvault0Proofs(
            mAlphaUMINTLibrary.Info({curator: curator, subvault: subvault0, market: market})
        );
        ProofLibrary.storeProofs("ethereum:mAlphaUmint:subvault0", merkleRoot, leaves, descriptions);
        calls = mAlphaUMINTLibrary.getSubvault0SubvaultCalls(
            mAlphaUMINTLibrary.Info({curator: curator, subvault: subvault0, market: market}), leaves
        );
    }

    /// @dev just for testing UMINT token behavior, because it is not verified
    function testUmintToken() internal {
        // valid on 23710403 block
        address holder1 = 0x54b930e2f72472773234B9edaeBA3f7a971fc4a8; // whitelisted user
        address holder2 = 0x19E42f0fDC345ebC662f0B62D5039e3816cF48f0; // whitelisted user

        uint256 balanceBefore1 = IERC20(Constants.UMINT).balanceOf(holder1);
        uint256 balanceBefore2 = IERC20(Constants.UMINT).balanceOf(holder2);

        MockSpender spender = new MockSpender();

        vm.startPrank(holder1);
        IERC20(Constants.UMINT).transfer(holder2, balanceBefore1 / 2);
        uint256 balanceAfter = IERC20(Constants.UMINT).balanceOf(holder1);
        require(balanceBefore1 - balanceAfter == balanceBefore1 / 2, "UMINT transfer failed");

        /// @dev approve is not checking that spender is whitelisted
        IERC20(Constants.UMINT).approve(address(spender), type(uint256).max);
        vm.stopPrank();

        spender.transferFrom(Constants.UMINT, holder1, holder2, IERC20(Constants.UMINT).balanceOf(holder1));
        balanceAfter = IERC20(Constants.UMINT).balanceOf(holder2);
        IERC20(Constants.UMINT).balanceOf(holder1);
        require(balanceBefore1 + balanceBefore2 == balanceAfter, "UMINT transferFrom failed");
    }

    function testBorrow() internal {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);

        vm.startBroadcast(deployerPk);
        address[] memory orders = new address[](1);
        orders[0] = 0xD2ccc855c096FdfEC46FE4A38c04a6F7011B44b7;
        uint128[] memory tokenAmtsWantBuy = new uint128[](1);
        tokenAmtsWantBuy[0] = 2500;
        ITermMaxRouter(Constants.TERMMAX_ROUTER).borrowTokenFromCollateral(
            deployer, market, 3000, orders, tokenAmtsWantBuy, 2600, block.timestamp + 1 hours
        );
    }
}

contract MockSpender {
    function transferFrom(address token, address from, address to, uint256 amount) external {
        IERC20(token).transferFrom(from, to, amount);
    }
}
