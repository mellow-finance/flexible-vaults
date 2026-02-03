// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../test/Imports.sol";
import "forge-std/Script.sol";
import "forge-std/Test.sol";

import "../common/ArraysLibrary.sol";
import "../common/Permissions.sol";
import "./Constants.sol";

import {AcceptanceLibrary} from "../common/AcceptanceLibrary.sol";

contract Deploy is Script, Test {
    address public proxyAdminOwner = 0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0;
    address public lazyVaultAdmin = 0x0Fb1fe5b41cBA3c01BBF48f73bC82b19f32b3053;
    address public activeVaultAdmin = 0x65D692F223bC78da7024a0f0e018D9F35AB45472;
    address public oracleUpdater = 0xAed4BE0D6E933249F833cfF64600e3fB33597B82;
    address public curator = 0x1280e86Cd7787FfA55d37759C0342F8CD3c7594a;

    address public feeManagerOwner = 0x1D2d56EeA41488413cC11441a79F7fF444d469d4;

    address public pauser = 0x3B8Ad20814f782F5681C050eff66F3Df9dF0D0FF;

    uint256 public constant DEFAULT_MULTIPLIER = 0.995e8;

    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);

        vm.startBroadcast(deployerPk);

        TimelockController timelockController = new TimelockController(
            0,
            ArraysLibrary.makeAddressArray(abi.encode(deployer, lazyVaultAdmin)),
            ArraysLibrary.makeAddressArray(abi.encode(curator, activeVaultAdmin)),
            lazyVaultAdmin
        );

        address[] memory assets = ArraysLibrary.makeAddressArray(
            abi.encode(Constants.USDT0, Constants.SYRUP_USDT, Constants.WXPL, Constants.USDE, Constants.SUSDE)
        );

        Vault.RoleHolder[] memory holders = new Vault.RoleHolder[](50);
        {
            uint256 i = 0;

            // lazyVaultAdmin roles:
            holders[i++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, lazyVaultAdmin);

            // timelock roles:
            holders[i++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, address(timelockController));

            // curator roles:
            holders[i++] = Vault.RoleHolder(Permissions.CALLER_ROLE, curator);

            // deployer roles:
            holders[i++] = Vault.RoleHolder(Permissions.CREATE_SUBVAULT_ROLE, deployer);
            holders[i++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, deployer);
            holders[i++] = Vault.RoleHolder(Permissions.SET_SUBVAULT_LIMIT_ROLE, deployer);
            holders[i++] = Vault.RoleHolder(Permissions.ALLOW_SUBVAULT_ASSETS_ROLE, deployer);
            holders[i++] = Vault.RoleHolder(Permissions.ACCEPT_REPORT_ROLE, deployer);
            holders[i++] = Vault.RoleHolder(Permissions.SUBMIT_REPORTS_ROLE, deployer);

            assembly {
                mstore(holders, i)
            }
        }

        uint32 maxInterval = 1770144000;
        ProtocolDeployment memory deployment = Constants.protocolDeployment();
        VaultConfigurator.InitParams memory initParams = VaultConfigurator.InitParams({
            version: 0,
            proxyAdmin: proxyAdminOwner,
            vaultAdmin: lazyVaultAdmin,
            shareManagerVersion: 0,
            shareManagerParams: abi.encode(bytes32(0), "Restaking Vault ETH+", "rstETH+"),
            feeManagerVersion: 0,
            feeManagerParams: abi.encode(lazyVaultAdmin, lazyVaultAdmin, 0, 0, 0, 0),
            riskManagerVersion: 0,
            riskManagerParams: abi.encode(type(int256).max / 2),
            oracleVersion: 0,
            oracleParams: abi.encode(
                IOracle.SecurityParams({
                    maxAbsoluteDeviation: 1,
                    suspiciousAbsoluteDeviation: 1,
                    maxRelativeDeviationD18: 1,
                    suspiciousRelativeDeviationD18: 1,
                    timeout: type(uint32).max,
                    depositInterval: maxInterval,
                    redeemInterval: maxInterval
                }),
                assets
            ),
            defaultDepositHook: address(0),
            defaultRedeemHook: address(0),
            queueLimit: 0,
            roleHolders: holders
        });

        Vault vault;
        {
            (,,,, address vault_) = deployment.vaultConfigurator.create(initParams);
            vault = Vault(payable(vault_));
        }

        address[] memory verifiers = new address[](3);
        SubvaultCalls[] memory calls = new SubvaultCalls[](3);

        {
            IRiskManager riskManager = vault.riskManager();

            Factory verifierFactory = Constants.protocolDeployment().verifierFactory;
            {
                address verifier0 = verifierFactory.create(0, proxyAdminOwner, abi.encode(vault, bytes32(0)));
                address subvault0 = vault.createSubvault(0, proxyAdminOwner, verifier0);
                address swapModule0 = _createSwapModule0(subvault0);
                riskManager.setSubvaultLimit(subvault0, type(int256).max / 2);
                riskManager.allowSubvaultAssets(subvault0, assets);

                console2.log("Verifier 0:", verifier0);
                console2.log("Subvault 0:", subvault0);
                console2.log("SwapModule 0:", swapModule0);
                verifiers[0] = verifier0;
            }

            {
                address verifier1 = verifierFactory.create(0, proxyAdminOwner, abi.encode(vault, bytes32(0)));
                address subvault1 = vault.createSubvault(0, proxyAdminOwner, verifier1);
                riskManager.setSubvaultLimit(subvault1, type(int256).max / 2);
                riskManager.allowSubvaultAssets(subvault1, assets);
                console2.log("Verifier 1:", verifier1);
                console2.log("Subvault 1:", subvault1);
                verifiers[1] = verifier1;
            }

            {
                address verifier2 = verifierFactory.create(0, proxyAdminOwner, abi.encode(vault, bytes32(0)));
                address subvault2 = vault.createSubvault(0, proxyAdminOwner, verifier2);
                riskManager.setSubvaultLimit(subvault2, type(int256).max / 2);
                riskManager.allowSubvaultAssets(subvault2, assets);

                console2.log("Verifier 2:", verifier2);
                console2.log("Subvault 2:", subvault2);
                verifiers[2] = verifier2;
            }
        }

        vault.renounceRole(Permissions.CREATE_SUBVAULT_ROLE, deployer);
        vault.renounceRole(Permissions.SET_SUBVAULT_LIMIT_ROLE, deployer);
        vault.renounceRole(Permissions.ALLOW_SUBVAULT_ASSETS_ROLE, deployer);

        for (uint256 i = 0; i < verifiers.length; i++) {
            timelockController.schedule(
                verifiers[i], 0, abi.encodeCall(IVerifier.setMerkleRoot, (bytes32(0))), bytes32(0), bytes32(0), 0
            );
        }

        timelockController.renounceRole(timelockController.PROPOSER_ROLE(), deployer);
        timelockController.renounceRole(timelockController.CANCELLER_ROLE(), deployer);

        console2.log("Vault: %s", address(vault));
        console2.log("TimelockController: %s", address(timelockController));

        {
            IOracle.Report[] memory reports = new IOracle.Report[](assets.length);
            for (uint256 i = 0; i < assets.length; i++) {
                reports[i].asset = assets[i];
                reports[i].priceD18 = uint224(1 ether);
            }
            vault.oracle().submitReports(reports);
        }

        _acceptReports(vault, deployer);

        vm.stopBroadcast();

        AcceptanceLibrary.runProtocolDeploymentChecks(Constants.protocolDeployment());
        AcceptanceLibrary.runVaultDeploymentChecks(
            Constants.protocolDeployment(),
            VaultDeployment({
                vault: vault,
                calls: calls,
                initParams: initParams,
                holders: _getExpectedHolders(timelockController, deployer),
                depositHook: address(0),
                redeemHook: address(0),
                assets: assets,
                depositQueueAssets: new address[](0),
                redeemQueueAssets: new address[](0),
                subvaultVerifiers: verifiers,
                timelockControllers: ArraysLibrary.makeAddressArray(abi.encode(timelockController)),
                timelockProposers: ArraysLibrary.makeAddressArray(abi.encode(lazyVaultAdmin)),
                timelockExecutors: ArraysLibrary.makeAddressArray(abi.encode(curator, activeVaultAdmin))
            })
        );
        revert("ok");
    }

    function _acceptReports(Vault vault, address deployer) internal {
        IOracle oracle = vault.oracle();
        for (uint256 i = 0; i < oracle.supportedAssets(); i++) {
            address a = oracle.supportedAssetAt(i);
            IOracle.DetailedReport memory r = oracle.getReport(a);
            oracle.acceptReport(a, r.priceD18, r.timestamp);
        }
        vault.renounceRole(Permissions.SUBMIT_REPORTS_ROLE, deployer);
        vault.renounceRole(Permissions.ACCEPT_REPORT_ROLE, deployer);
    }

    function _getExpectedHolders(TimelockController timelockController, address deployer)
        internal
        view
        returns (Vault.RoleHolder[] memory holders)
    {
        holders = new Vault.RoleHolder[](50);
        uint256 i = 0;

        // lazyVaultAdmin roles:
        holders[i++] = Vault.RoleHolder(Permissions.DEFAULT_ADMIN_ROLE, lazyVaultAdmin);
        holders[i++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, lazyVaultAdmin);

        // timelock roles:
        holders[i++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, address(timelockController));

        // curator roles:
        holders[i++] = Vault.RoleHolder(Permissions.CALLER_ROLE, curator);

        // deployer roles:
        holders[i++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, deployer);

        assembly {
            mstore(holders, i)
        }
    }

    function _createSwapModule0(address subvault) internal returns (address swapModule) {
        IFactory swapModuleFactory = Constants.protocolDeployment().swapModuleFactory;

        address[5] memory assets =
            [Constants.WXPL, Constants.SYRUP_USDT, Constants.USDT0, Constants.USDE, Constants.SUSDE];

        address[] memory actors =
            ArraysLibrary.makeAddressArray(abi.encode(curator, assets, assets, Constants.KYBERSWAP_ROUTER));

        bytes32[] memory permissions = ArraysLibrary.makeBytes32Array(
            abi.encode(
                Permissions.SWAP_MODULE_CALLER_ROLE,
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
                Permissions.SWAP_MODULE_ROUTER_ROLE
            )
        );
        return swapModuleFactory.create(
            0,
            proxyAdminOwner,
            abi.encode(lazyVaultAdmin, subvault, Constants.AAVE_V3_ORACLE, DEFAULT_MULTIPLIER, actors, permissions)
        );
    }
}
