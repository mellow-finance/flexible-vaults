// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./interfaces/ICowswapSettlement.sol";
import {IWETH as WETHInterface} from "./interfaces/IWETH.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";

import "../../src/vaults/Subvault.sol";
import "../../src/vaults/VaultConfigurator.sol";

import "./Permissions.sol";
import "./ProofLibrary.sol";
import "forge-std/Script.sol";

contract Deploy is Script {
    // Constants
    address public WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address public COWSWAP_SETTLEMENT = 0x9008D19f58AAbD9eD0D60971565AA8510560ab41;
    address public COWSWAP_VAULT_RELAYER = 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110;

    // Deployment
    VaultConfigurator public vaultConfigurator = VaultConfigurator(0x000000028be48f9E62E13403480B60C4822C5aa5);
    BitmaskVerifier public bitmaskVerifier = BitmaskVerifier(0x0000000263Fb29C3D6B0C5837883519eF05ea20A);
    address public redirectingDepositHook = 0x00000004d3B17e5391eb571dDb8fDF95646ca827;
    address public basicRedeemHook = 0x0000000637f1b1ccDA4Af2dB6CDDf5e5Ec45fd93;
    IFactory public verifierFactory = IFactory(0x04B30b1e98950e6A13550d84e991bE0d734C2c61);

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
            assembly {
                mstore(holders, i)
            }
        }
        address[] memory assets_ = new address[](3);
        assets_[0] = TransferLibrary.ETH;
        assets_[1] = WETH;
        assets_[2] = WSTETH;

        (,,,, address vault_) = vaultConfigurator.create(
            VaultConfigurator.InitParams({
                version: 0,
                proxyAdmin: proxyAdmin,
                vaultAdmin: lazyVaultAdmin,
                shareManagerVersion: 0,
                shareManagerParams: abi.encode(bytes32(0), "Theoriq AlphaVault ETH", "tqETH"),
                feeManagerVersion: 0,
                feeManagerParams: abi.encode(deployer, lazyVaultAdmin, uint24(0), uint24(0), uint24(1e5), uint24(0)),
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
                defaultDepositHook: redirectingDepositHook,
                defaultRedeemHook: basicRedeemHook,
                queueLimit: 6,
                roleHolders: holders
            })
        );
        Vault vault = Vault(payable(vault_));

        // queues setup
        vault.createQueue(0, true, proxyAdmin, TransferLibrary.ETH, new bytes(0));
        vault.createQueue(0, true, proxyAdmin, WETH, new bytes(0));
        vault.createQueue(0, true, proxyAdmin, WSTETH, new bytes(0));
        vault.createQueue(0, false, proxyAdmin, TransferLibrary.ETH, new bytes(0));
        vault.createQueue(0, false, proxyAdmin, WETH, new bytes(0));
        vault.createQueue(0, false, proxyAdmin, WSTETH, new bytes(0));

        // fee manager setup
        vault.feeManager().setBaseAsset(vault_, TransferLibrary.ETH);
        Ownable(address(vault.feeManager())).transferOwnership(lazyVaultAdmin);

        // subvault setup
        IRiskManager riskManager = vault.riskManager();
        vault.createSubvault(0, proxyAdmin, _createCowswapVerifier(address(vault))); // eth,weth,wsteth
        riskManager.allowSubvaultAssets(vault.subvaultAt(0), assets_);
        riskManager.setSubvaultLimit(vault.subvaultAt(0), type(int256).max);

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
            vault.queueAt(WSTETH, 0),
            vault.queueAt(WSTETH, 1),
            vault.queueAt(WETH, 0),
            vault.queueAt(WETH, 1),
            vault.queueAt(TransferLibrary.ETH, 0),
            vault.queueAt(TransferLibrary.ETH, 1)
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

        vault.renounceRole(Permissions.CREATE_QUEUE_ROLE, deployer);
        vault.renounceRole(Permissions.CREATE_SUBVAULT_ROLE, deployer);
        vault.renounceRole(Permissions.SET_VAULT_LIMIT_ROLE, deployer);
        vault.renounceRole(Permissions.ALLOW_SUBVAULT_ASSETS_ROLE, deployer);
        vault.renounceRole(Permissions.SET_SUBVAULT_LIMIT_ROLE, deployer);

        vm.stopBroadcast();
        revert("ok");
    }

    function _createCowswapVerifier(address vault) internal returns (address verifier) {
        /*
            1. weth.deposit{value: <any>}();
            2. weth.withdraw(<any>);
            3. weth.approve(cowswapVaultRelayer, <any>);
            4. wsteth.approve(cowswapVaultRelayer, <any>);
            5. cowswapSettlement.setPreSignature(anyBytes, anyBool); // bytes - fixed length always
            6. cowswapSettlement.invalidateOrder(anyBytes); // bytes - fixed length always    
        */
        uint256 i = 0;
        IVerifier.VerificationPayload[] memory leaves = new IVerifier.VerificationPayload[](6);
        leaves[i++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            curator,
            WETH,
            0,
            abi.encodeCall(WETHInterface.deposit, ()),
            ProofLibrary.makeBitmask(true, true, false, true, abi.encodeCall(WETHInterface.deposit, ()))
        );
        leaves[i++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            curator,
            WETH,
            0,
            abi.encodeCall(WETHInterface.withdraw, (0)),
            ProofLibrary.makeBitmask(true, true, true, true, abi.encodeCall(WETHInterface.withdraw, (0)))
        );
        leaves[i++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            curator,
            WETH,
            0,
            abi.encodeCall(IERC20.approve, (COWSWAP_VAULT_RELAYER, 0)),
            ProofLibrary.makeBitmask(
                true, true, true, true, abi.encodeCall(IERC20.approve, (address(type(uint160).max), 0))
            )
        );
        leaves[i++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            curator,
            WSTETH,
            0,
            abi.encodeCall(IERC20.approve, (COWSWAP_VAULT_RELAYER, 0)),
            ProofLibrary.makeBitmask(
                true, true, true, true, abi.encodeCall(IERC20.approve, (address(type(uint160).max), 0))
            )
        );
        leaves[i++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            curator,
            COWSWAP_SETTLEMENT,
            0,
            abi.encodeCall(ICowswapSettlement.setPreSignature, (new bytes(56), false)),
            ProofLibrary.makeBitmask(
                true, true, true, true, abi.encodeCall(ICowswapSettlement.setPreSignature, (new bytes(56), false))
            )
        );
        leaves[i++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            curator,
            COWSWAP_SETTLEMENT,
            0,
            abi.encodeCall(ICowswapSettlement.invalidateOrder, (new bytes(56))),
            ProofLibrary.makeBitmask(
                true, true, true, true, abi.encodeCall(ICowswapSettlement.invalidateOrder, (new bytes(56)))
            )
        );
        assembly {
            mstore(leaves, i)
        }
        bytes32 root;
        (root, leaves) = ProofLibrary.generateMerkleProofs(leaves);
        ProofLibrary.storeProofs("ethereum:tqETH:subvault0", root, leaves);
        return verifierFactory.create(0, proxyAdmin, abi.encode(vault, root));
    }
}
