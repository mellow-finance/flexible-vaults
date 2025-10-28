// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";

import "../../../src/vaults/Subvault.sol";
import "../../../src/vaults/VaultConfigurator.sol";

import "../../common/AcceptanceLibrary.sol";
import "../../common/ArraysLibrary.sol";
import "../../common/Permissions.sol";
import "../../common/ProofLibrary.sol";

import "../Constants.sol";
import "./AuroBTCLibrary.sol";

import "forge-std/Script.sol";

abstract contract AuroBTCDeployBase is Script {
    // wBTC address on Ethereum mainnet
    address public constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

    address public constant proxyAdmin = 0x0000000000000000000000000000000000000000;
    address public constant lazyVaultAdmin = 0x0000000000000000000000000000000000000000;
    address public constant activeVaultAdmin = 0x0000000000000000000000000000000000000000;
    address public constant oracleUpdater = 0x0000000000000000000000000000000000000000;
    address public constant curator = 0x0000000000000000000000000000000000000000;
    address public constant recipient = 0x0000000000000000000000000000000000000000;

    struct AcceptanceCheckParams {
        Vault vault;
        SubvaultCalls[] calls;
        VaultConfigurator.InitParams initParams;
        address[] assets;
        address mainVerifier;
        TimelockController timelockController;
        address deployer;
    }

    function getStorageKey() internal pure virtual returns (string memory);

    function shouldRunAcceptanceChecks() internal pure virtual returns (bool) {
        return false;
    }

    function getInitParams(address deployer, TimelockController timelockController, ProtocolDeployment memory $)
        internal
        view
        virtual
        returns (VaultConfigurator.InitParams memory initParams);

    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);

        vm.startBroadcast(deployerPk);

        TimelockController timelockController;
        {
            address[] memory proposers = ArraysLibrary.makeAddressArray(abi.encode(lazyVaultAdmin, deployer));
            address[] memory executors = ArraysLibrary.makeAddressArray(abi.encode(lazyVaultAdmin));
            timelockController = new TimelockController(0, proposers, executors, lazyVaultAdmin);
        }

        address[] memory assets_ = ArraysLibrary.makeAddressArray(abi.encode(WBTC));

        ProtocolDeployment memory $ = Constants.protocolDeployment();
        VaultConfigurator.InitParams memory initParams = getInitParams(deployer, timelockController, $);

        Vault vault;
        {
            (,,,, address vault_) = $.vaultConfigurator.create(initParams);
            vault = Vault(payable(vault_));
        }

        vault.createQueue(0, true, proxyAdmin, WBTC, new bytes(0));
        vault.createQueue(0, false, proxyAdmin, WBTC, new bytes(0));

        vault.feeManager().setBaseAsset(address(vault), WBTC);
        Ownable(address(vault.feeManager())).transferOwnership(lazyVaultAdmin);

        address erc20Verifier;
        address mainVerifier;
        SubvaultCalls[] memory calls = new SubvaultCalls[](1);

        {
            IRiskManager riskManager = vault.riskManager();

            bytes32 merkleRoot;
            (erc20Verifier, merkleRoot, calls[0]) = AuroBTCLibrary.createERC20Verifier(
                proxyAdmin, curator, recipient, WBTC, $.erc20VerifierFactory, getStorageKey()
            );

            // Create main verifier with merkle root that includes the ERC20Verifier
            mainVerifier = $.verifierFactory.create(0, proxyAdmin, abi.encode(address(vault), merkleRoot));

            vault.createSubvault(0, proxyAdmin, mainVerifier);
            riskManager.allowSubvaultAssets(vault.subvaultAt(0), assets_);
            riskManager.setSubvaultLimit(vault.subvaultAt(0), type(int256).max / 2);
        }

        timelockController.schedule(
            address(vault.shareManager()),
            0,
            abi.encodeCall(
                IShareManager.setFlags,
                (IShareManager.Flags({
                        hasMintPause: true,
                        hasBurnPause: true,
                        hasTransferPause: true,
                        hasWhitelist: true,
                        hasTransferWhitelist: true,
                        globalLockup: type(uint32).max
                    }))
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

        address[2] memory queues = [vault.queueAt(WBTC, 0), vault.queueAt(WBTC, 1)];
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

        console2.log("Vault %s", address(vault));
        console2.log("DepositQueue (WBTC) %s", address(vault.queueAt(WBTC, 0)));
        console2.log("RedeemQueue (WBTC) %s", address(vault.queueAt(WBTC, 1)));
        console2.log("Oracle %s", address(vault.oracle()));
        console2.log("ShareManager %s", address(vault.shareManager()));
        console2.log("FeeManager %s", address(vault.feeManager()));
        console2.log("RiskManager %s", address(vault.riskManager()));

        for (uint256 i = 0; i < vault.subvaults(); i++) {
            address subvault = vault.subvaultAt(i);
            console2.log("Subvault %s %s", i, subvault);
            console2.log("Verifier %s %s", i, address(Subvault(payable(subvault)).verifier()));
        }

        console2.log("ERC20Verifier %s", erc20Verifier);
        console2.log("Curator %s", curator);
        console2.log("Recipient %s", recipient);
        console2.log("Timelock controller: %s", address(timelockController));

        // Initialize oracle with wBTC price at 1:1 for predeposit phase
        // This ensures 1 wBTC deposit = 1 auroBTC token
        {
            IOracle.Report[] memory reports = new IOracle.Report[](1);
            reports[0].asset = WBTC;
            reports[0].priceD18 = 1 ether; // 1:1 pricing for predeposit

            IOracle oracle = vault.oracle();
            oracle.submitReports(reports);
        }

        // Renounce temporary deployer roles (acceptReport will be called in Accept script)
        vault.renounceRole(Permissions.SUBMIT_REPORTS_ROLE, deployer);

        vm.stopBroadcast();

        if (shouldRunAcceptanceChecks()) {
            _runAcceptanceChecks(
                AcceptanceCheckParams({
                    vault: vault,
                    calls: calls,
                    initParams: initParams,
                    assets: assets_,
                    mainVerifier: mainVerifier,
                    timelockController: timelockController,
                    deployer: deployer
                })
            );
        }

        console2.log("VAULT_ADDRESS_FOR_SCRIPT:", address(vault));
    }

    function _runAcceptanceChecks(AcceptanceCheckParams memory params) internal {
        AcceptanceLibrary.runProtocolDeploymentChecks(Constants.protocolDeployment());

        ProtocolDeployment memory $ = Constants.protocolDeployment();
        address[] memory subvaultVerifiersArray = ArraysLibrary.makeAddressArray(abi.encode(params.mainVerifier));
        address[] memory timelockControllersArray =
            ArraysLibrary.makeAddressArray(abi.encode(address(params.timelockController)));
        address[] memory timelockProposersArray =
            ArraysLibrary.makeAddressArray(abi.encode(lazyVaultAdmin, params.deployer));
        address[] memory timelockExecutorsArray = ArraysLibrary.makeAddressArray(abi.encode(lazyVaultAdmin));

        AcceptanceLibrary.runVaultDeploymentChecks(
            $,
            VaultDeployment({
                vault: params.vault,
                calls: params.calls,
                initParams: params.initParams,
                holders: _getExpectedHolders(address(params.timelockController)),
                depositHook: address($.redirectingDepositHook),
                redeemHook: address($.basicRedeemHook),
                assets: params.assets,
                depositQueueAssets: params.assets,
                redeemQueueAssets: params.assets,
                subvaultVerifiers: subvaultVerifiersArray,
                timelockControllers: timelockControllersArray,
                timelockProposers: timelockProposersArray,
                timelockExecutors: timelockExecutorsArray
            })
        );
    }

    function _getExpectedHolders(address timelockController) internal pure returns (Vault.RoleHolder[] memory holders) {
        holders = new Vault.RoleHolder[](17);
        holders[0] = Vault.RoleHolder(Permissions.DEFAULT_ADMIN_ROLE, lazyVaultAdmin);
        holders[1] = Vault.RoleHolder(Permissions.ACCEPT_REPORT_ROLE, activeVaultAdmin);
        holders[2] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, activeVaultAdmin);
        holders[3] = Vault.RoleHolder(Permissions.ALLOW_CALL_ROLE, activeVaultAdmin);
        holders[4] = Vault.RoleHolder(Permissions.DISALLOW_CALL_ROLE, activeVaultAdmin);
        holders[5] = Vault.RoleHolder(Permissions.SET_VAULT_LIMIT_ROLE, activeVaultAdmin);
        holders[6] = Vault.RoleHolder(Permissions.SET_SUBVAULT_LIMIT_ROLE, activeVaultAdmin);
        holders[7] = Vault.RoleHolder(Permissions.ALLOW_SUBVAULT_ASSETS_ROLE, activeVaultAdmin);
        holders[8] = Vault.RoleHolder(Permissions.MODIFY_VAULT_BALANCE_ROLE, activeVaultAdmin);
        holders[9] = Vault.RoleHolder(Permissions.MODIFY_SUBVAULT_BALANCE_ROLE, activeVaultAdmin);
        holders[10] = Vault.RoleHolder(Permissions.SET_FLAGS_ROLE, address(timelockController));
        holders[11] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, address(timelockController));
        holders[12] = Vault.RoleHolder(Permissions.SET_QUEUE_STATUS_ROLE, address(timelockController));
        holders[13] = Vault.RoleHolder(Permissions.SUBMIT_REPORTS_ROLE, oracleUpdater);
        holders[14] = Vault.RoleHolder(Permissions.CALLER_ROLE, curator);
        holders[15] = Vault.RoleHolder(Permissions.PULL_LIQUIDITY_ROLE, curator);
        holders[16] = Vault.RoleHolder(Permissions.PUSH_LIQUIDITY_ROLE, curator);
    }
}
