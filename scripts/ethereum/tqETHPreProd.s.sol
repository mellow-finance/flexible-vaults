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

contract Deploy is Script {
    // Actors
    address public proxyAdmin = 0xC1211878475Cd017fecb922Ae63cc3815FA45652;
    address public lazyVaultAdmin = 0xE8bEc6Fb52f01e487415D3Ed3797ab92cBfdF498;
    address public activeVaultAdmin = 0x7885B30F0DC0d8e1aAf0Ed6580caC22d5D09ff4f;
    address public oracleUpdater = 0x3F1C3Eb0bC499c1A091B635dEE73fF55E19cdCE9;
    address public curator = 0x55666095cD083a92E368c0CBAA18d8a10D3b65Ec;
    address public pauser1 = 0xFeCeb0255a4B7Cd05995A7d617c0D52c994099CF;
    address public pauser2 = 0x8b7C1b52e2d606a526abD73f326c943c75e45Bd3;

    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);

        vm.startBroadcast(deployerPk);

        Vault.RoleHolder[] memory holders = new Vault.RoleHolder[](42);
        TimelockController timelockController;

        {
            address[] memory proposers = _makeArray(lazyVaultAdmin, deployer);
            address[] memory executors = _makeArray(pauser1, pauser2);
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
                    timeout: 1 hours,
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

        console2.log("Vault %s", address(vault));

        console2.log("DepositQueue (ETH) %s", address(vault.queueAt(Constants.ETH, 0)));
        console2.log("DepositQueue (WETH) %s", address(vault.queueAt(Constants.WETH, 0)));
        console2.log("DepositQueue (WSTETH) %s", address(vault.queueAt(Constants.WSTETH, 0)));
        console2.log("RedeemQueue (ETH) %s", address(vault.queueAt(Constants.ETH, 1)));
        console2.log("RedeemQueue (WETH) %s", address(vault.queueAt(Constants.WETH, 1)));
        console2.log("RedeemQueue (WSTETH) %s", address(vault.queueAt(Constants.WSTETH, 1)));

        console2.log("Oracle %s", address(vault.oracle()));
        console2.log("ShareManager %s", address(vault.shareManager()));
        console2.log("FeeManager %s", address(vault.feeManager()));
        console2.log("RiskManager %s", address(vault.riskManager()));

        IDepositQueue(address(vault.queueAt(Constants.ETH, 0))).deposit{value: 1 gwei}(
            1 gwei, address(0), new bytes32[](0)
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
                depositQueueAssets: assets_,
                redeemQueueAssets: assets_,
                subvaultVerifiers: _makeArray(verifier),
                timelockControllers: _makeArray(address(timelockController)),
                timelockProposers: _makeArray(lazyVaultAdmin, deployer),
                timelockExecutors: _makeArray(pauser1, pauser2)
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
        uint256 i = 0;
        IVerifier.VerificationPayload[] memory leaves = new IVerifier.VerificationPayload[](6);
        string[] memory descriptions = new string[](6);
        descriptions[i] = "WETH.deposit{value: any}()";
        leaves[i++] = ProofLibrary.makeVerificationPayload(
            $.bitmaskVerifier,
            curator,
            Constants.WETH,
            0,
            abi.encodeCall(WETHInterface.deposit, ()),
            ProofLibrary.makeBitmask(true, true, false, true, abi.encodeCall(WETHInterface.deposit, ()))
        );
        descriptions[i] = "WETH.withdraw(any)";
        leaves[i++] = ProofLibrary.makeVerificationPayload(
            $.bitmaskVerifier,
            curator,
            Constants.WETH,
            0,
            abi.encodeCall(WETHInterface.withdraw, (0)),
            ProofLibrary.makeBitmask(true, true, true, true, abi.encodeCall(WETHInterface.withdraw, (0)))
        );
        descriptions[i] = "WETH.approve(CowswapVaultRelayer, any)";
        leaves[i++] = ProofLibrary.makeVerificationPayload(
            $.bitmaskVerifier,
            curator,
            Constants.WETH,
            0,
            abi.encodeCall(IERC20.approve, (Constants.COWSWAP_VAULT_RELAYER, 0)),
            ProofLibrary.makeBitmask(
                true, true, true, true, abi.encodeCall(IERC20.approve, (address(type(uint160).max), 0))
            )
        );
        descriptions[i] = "WstETH.approve(CowswapVaultRelayer, any)";
        leaves[i++] = ProofLibrary.makeVerificationPayload(
            $.bitmaskVerifier,
            curator,
            Constants.WSTETH,
            0,
            abi.encodeCall(IERC20.approve, (Constants.COWSWAP_VAULT_RELAYER, 0)),
            ProofLibrary.makeBitmask(
                true, true, true, true, abi.encodeCall(IERC20.approve, (address(type(uint160).max), 0))
            )
        );

        descriptions[i] = "CowswapSettlement.setPerSignature(coswapOrderUid(owner=address(0)), anyBool)";
        {
            bytes memory orderUid = new bytes(56);
            address subvaultMask = address(type(uint160).max);
            // src: https://github.com/cowprotocol/contracts/blob/v1.8.0/src/contracts/libraries/GPv2Order.sol#L178
            assembly {
                mstore(add(orderUid, 52), subvaultMask) // validate orderUid.length == 56
            }
            bytes memory callData = abi.encodeCall(ICowswapSettlement.setPreSignature, (orderUid, false));
            assembly {
                mstore(add(callData, 0x64), not(0))
            }
            leaves[i++] = ProofLibrary.makeVerificationPayload(
                $.bitmaskVerifier,
                curator,
                Constants.COWSWAP_SETTLEMENT,
                0,
                abi.encodeCall(ICowswapSettlement.setPreSignature, (new bytes(56), false)),
                ProofLibrary.makeBitmask(true, true, true, true, callData)
            );
        }

        descriptions[i] = "CowswapSettlement.invalidateOrder(anyBytes(56))";
        {
            bytes memory callData = abi.encodeCall(ICowswapSettlement.invalidateOrder, (new bytes(56)));
            assembly {
                mstore(add(callData, 0x44), not(0)) // validate orderUid.length == 56
            }
            leaves[i++] = ProofLibrary.makeVerificationPayload(
                $.bitmaskVerifier,
                curator,
                Constants.COWSWAP_SETTLEMENT,
                0,
                abi.encodeCall(ICowswapSettlement.invalidateOrder, (new bytes(56))),
                ProofLibrary.makeBitmask(true, true, true, true, callData)
            );
        }
        assembly {
            mstore(leaves, i)
            mstore(descriptions, i)
        }
        bytes32 root;
        (root, leaves) = ProofLibrary.generateMerkleProofs(leaves);
        ProofLibrary.storeProofs("ethereum:tqETHPreProd:subvault0", root, leaves, descriptions);

        calls.payloads = leaves;
        calls.calls = new Call[][](leaves.length);

        // 1. weth.deposit{value: <any>}();
        {
            Call[] memory tmp = new Call[](5);
            tmp[0] = Call(curator, $.weth, 1 ether, abi.encodeCall(WETHInterface.deposit, ()), true);
            tmp[1] = Call(curator, $.weth, 0, abi.encodeCall(WETHInterface.deposit, ()), true);
            tmp[2] = Call($.deployer, $.weth, 1 ether, abi.encodeCall(WETHInterface.deposit, ()), false);
            tmp[3] = Call(curator, $.wsteth, 1 ether, abi.encodeCall(WETHInterface.deposit, ()), false);
            tmp[4] = Call(curator, $.weth, 1 ether, abi.encodePacked(WETHInterface.deposit.selector, uint256(0)), false);
            calls.calls[0] = tmp;
        }

        // 2. weth.withdraw(<any>);
        {
            Call[] memory tmp = new Call[](6);
            tmp[0] = Call(curator, $.weth, 0, abi.encodeCall(WETHInterface.withdraw, (0)), true);
            tmp[1] = Call(curator, $.weth, 0, abi.encodeCall(WETHInterface.withdraw, (type(uint256).max)), true);
            tmp[2] = Call($.deployer, $.weth, 0, abi.encodeCall(WETHInterface.withdraw, (0)), false);
            tmp[3] = Call(curator, $.wsteth, 0, abi.encodeCall(WETHInterface.withdraw, (0)), false);
            tmp[4] = Call(curator, $.weth, 0, abi.encodePacked(WETHInterface.withdraw.selector), false);
            tmp[5] = Call(curator, $.weth, 1 ether, abi.encodeCall(WETHInterface.withdraw, (0)), false);
            calls.calls[1] = tmp;
        }

        // 3. weth.approve(cowswapVaultRelayer, <any>);
        {
            Call[] memory tmp = new Call[](6);
            tmp[0] =
                Call(curator, $.weth, 0, abi.encodeCall(IERC20.approve, (Constants.COWSWAP_VAULT_RELAYER, 0)), true);
            tmp[1] = Call(
                curator,
                $.weth,
                0,
                abi.encodeCall(IERC20.approve, (Constants.COWSWAP_VAULT_RELAYER, type(uint256).max)),
                true
            );
            tmp[2] = Call(
                $.deployer,
                $.weth,
                0,
                abi.encodeCall(IERC20.approve, (Constants.COWSWAP_VAULT_RELAYER, type(uint256).max)),
                false
            );
            tmp[3] = Call(
                curator,
                $.wsteth,
                0,
                abi.encodeCall(IERC20.approve, (Constants.COWSWAP_VAULT_RELAYER, type(uint256).max)),
                false
            );
            tmp[4] = Call(
                curator,
                $.weth,
                0,
                abi.encodeCall(IERC20.transfer, (Constants.COWSWAP_VAULT_RELAYER, type(uint256).max)),
                false
            );
            tmp[5] = Call(
                curator,
                $.weth,
                1 ether,
                abi.encodeCall(IERC20.approve, (Constants.COWSWAP_VAULT_RELAYER, type(uint256).max)),
                false
            );
            calls.calls[2] = tmp;
        }

        //  4. wsteth.approve(cowswapVaultRelayer, <any>);
        {
            Call[] memory tmp = new Call[](6);
            tmp[0] =
                Call(curator, $.wsteth, 0, abi.encodeCall(IERC20.approve, (Constants.COWSWAP_VAULT_RELAYER, 0)), true);
            tmp[1] = Call(
                curator,
                $.wsteth,
                0,
                abi.encodeCall(IERC20.approve, (Constants.COWSWAP_VAULT_RELAYER, type(uint256).max)),
                true
            );
            tmp[2] = Call(
                $.deployer,
                $.wsteth,
                0,
                abi.encodeCall(IERC20.approve, (Constants.COWSWAP_VAULT_RELAYER, type(uint256).max)),
                false
            );
            tmp[3] = Call(
                curator,
                $.weth,
                0,
                abi.encodeCall(IERC20.approve, (Constants.COWSWAP_VAULT_RELAYER, type(uint256).max)),
                false
            );
            tmp[4] = Call(
                curator,
                $.wsteth,
                0,
                abi.encodeCall(IERC20.transfer, (Constants.COWSWAP_VAULT_RELAYER, type(uint256).max)),
                false
            );
            tmp[5] = Call(
                curator,
                $.wsteth,
                1 ether,
                abi.encodeCall(IERC20.approve, (Constants.COWSWAP_VAULT_RELAYER, type(uint256).max)),
                false
            );
            calls.calls[3] = tmp;
        }

        // 5. cowswapSettlement.setPerSignature(coswapOrderUid(owner=address(0)), anyBool);
        {
            Call[] memory tmp = new Call[](8);
            tmp[0] = Call(
                curator,
                Constants.COWSWAP_SETTLEMENT,
                0,
                abi.encodeCall(ICowswapSettlement.setPreSignature, (new bytes(56), false)),
                true
            );
            tmp[1] = Call(
                curator,
                Constants.COWSWAP_SETTLEMENT,
                0,
                abi.encodeCall(ICowswapSettlement.setPreSignature, (new bytes(56), true)),
                true
            );
            tmp[2] = Call(
                curator,
                Constants.COWSWAP_SETTLEMENT,
                0,
                abi.encodeCall(ICowswapSettlement.setPreSignature, (new bytes(57), true)),
                false
            );

            {
                bytes memory badOrderUid = new bytes(56);
                address badMask = address(type(uint160).max);
                assembly {
                    mstore(add(badOrderUid, 52), badMask)
                }
                tmp[3] = Call(
                    curator,
                    Constants.COWSWAP_SETTLEMENT,
                    0,
                    abi.encodeCall(ICowswapSettlement.setPreSignature, (badOrderUid, false)),
                    false
                );
            }

            tmp[4] = Call(
                curator,
                Constants.COWSWAP_SETTLEMENT,
                1 wei,
                abi.encodeCall(ICowswapSettlement.setPreSignature, (new bytes(56), true)),
                false
            );
            tmp[5] = Call(
                curator,
                Constants.COWSWAP_SETTLEMENT,
                0,
                abi.encodePacked(ICowswapSettlement.setPreSignature.selector, new bytes(56)),
                false
            );
            tmp[6] = Call(
                $.deployer,
                Constants.COWSWAP_SETTLEMENT,
                0,
                abi.encodeCall(ICowswapSettlement.setPreSignature, (new bytes(56), false)),
                false
            );
            tmp[7] = Call(
                curator, $.weth, 0, abi.encodeCall(ICowswapSettlement.setPreSignature, (new bytes(56), false)), false
            );

            calls.calls[4] = tmp;
        }

        // 6. cowswapSettlement.invalidateOrder(anyBytes);
        {
            Call[] memory tmp = new Call[](8);
            tmp[0] = Call(
                curator,
                Constants.COWSWAP_SETTLEMENT,
                0,
                abi.encodeCall(ICowswapSettlement.invalidateOrder, (new bytes(56))),
                true
            );
            bytes memory temp = new bytes(56);
            temp[0] = bytes1(uint8(1));
            tmp[1] = Call(
                curator,
                Constants.COWSWAP_SETTLEMENT,
                0,
                abi.encodeCall(ICowswapSettlement.invalidateOrder, (temp)),
                true
            );
            tmp[2] = Call(
                curator,
                Constants.COWSWAP_SETTLEMENT,
                0,
                abi.encodeCall(ICowswapSettlement.invalidateOrder, (new bytes(57))),
                false
            );
            tmp[3] = Call(
                $.deployer,
                Constants.COWSWAP_SETTLEMENT,
                0,
                abi.encodeCall(ICowswapSettlement.invalidateOrder, (new bytes(57))),
                false
            );
            tmp[4] =
                Call(curator, $.weth, 0, abi.encodeCall(ICowswapSettlement.invalidateOrder, (new bytes(57))), false);
            tmp[5] = Call(
                curator,
                Constants.COWSWAP_SETTLEMENT,
                1 wei,
                abi.encodeCall(ICowswapSettlement.invalidateOrder, (new bytes(57))),
                false
            );
            temp[25] = bytes1(uint8(1));
            tmp[6] = Call(
                curator,
                Constants.COWSWAP_SETTLEMENT,
                0,
                abi.encodeCall(ICowswapSettlement.invalidateOrder, (temp)),
                true
            );
            temp[55] = bytes1(uint8(1));
            tmp[7] = Call(
                curator,
                Constants.COWSWAP_SETTLEMENT,
                0,
                abi.encodeCall(ICowswapSettlement.invalidateOrder, (temp)),
                true
            );

            calls.calls[5] = tmp;
        }

        verifier = $.verifierFactory.create(0, proxyAdmin, abi.encode(vault, root));
    }
}
