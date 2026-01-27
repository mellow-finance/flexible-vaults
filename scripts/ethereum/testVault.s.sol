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

    address testMultisig = 0xaACd51Ec497E9217c986E4F77FfD2F98477734DD;
    string public vaultSymbol = "MUITV";
    string public vaultName = "Mellow UI TestVault";

    uint256 public constant DEFAULT_MULTIPLIER = 0.9e8;

    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);

        vm.startBroadcast(deployerPk);

        Vault.RoleHolder[] memory holders = new Vault.RoleHolder[](42);
        {
            uint256 i = 0;

            holders[i++] = Vault.RoleHolder(Permissions.ACCEPT_REPORT_ROLE, testMultisig);
            holders[i++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, testMultisig);
            holders[i++] = Vault.RoleHolder(Permissions.SUBMIT_REPORTS_ROLE, testMultisig);
            holders[i++] = Vault.RoleHolder(Permissions.CALLER_ROLE, testMultisig);
            holders[i++] = Vault.RoleHolder(Permissions.PULL_LIQUIDITY_ROLE, testMultisig);
            holders[i++] = Vault.RoleHolder(Permissions.PUSH_LIQUIDITY_ROLE, testMultisig);

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
        address[] memory assets_ =
            ArraysLibrary.makeAddressArray(abi.encode(Constants.ETH, Constants.WETH, Constants.WSTETH));

        ProtocolDeployment memory $ = Constants.protocolDeployment();
        VaultConfigurator.InitParams memory initParams = VaultConfigurator.InitParams({
            version: 0,
            proxyAdmin: testMultisig,
            vaultAdmin: testMultisig,
            shareManagerVersion: 0,
            shareManagerParams: abi.encode(bytes32(0), vaultName, vaultSymbol),
            feeManagerVersion: 0,
            feeManagerParams: abi.encode(deployer, testMultisig, uint24(0), uint24(0), uint24(0), uint24(0)),
            riskManagerVersion: 0,
            riskManagerParams: abi.encode(type(int256).max / 2),
            oracleVersion: 0,
            oracleParams: abi.encode(
                IOracle.SecurityParams({
                    maxAbsoluteDeviation: 0.005 ether,
                    suspiciousAbsoluteDeviation: 0.001 ether,
                    maxRelativeDeviationD18: 0.005 ether,
                    suspiciousRelativeDeviationD18: 0.001 ether,
                    timeout: 1 seconds,
                    depositInterval: 1 seconds,
                    redeemInterval: 1 seconds
                }),
                assets_
            ),
            defaultDepositHook: address($.redirectingDepositHook),
            defaultRedeemHook: address($.basicRedeemHook),
            queueLimit: type(uint256).max,
            roleHolders: holders
        });

        Vault vault;
        {
            (,,,, address vault_) = $.vaultConfigurator.create(initParams);
            vault = Vault(payable(vault_));
        }

        // queues setup
        vault.createQueue(0, true, testMultisig, Constants.ETH, new bytes(0));
        vault.createQueue(0, true, testMultisig, Constants.WSTETH, new bytes(0));
        vault.createQueue(0, false, testMultisig, Constants.WSTETH, new bytes(0));

        // fee manager setup
        vault.feeManager().setBaseAsset(address(vault), Constants.ETH);
        Ownable(address(vault.feeManager())).transferOwnership(testMultisig);

        // subvault setup
        address[] memory verifiers = new address[](2);

        IRiskManager riskManager = vault.riskManager();
        {
            uint256 subvaultIndex = 0;
            verifiers[subvaultIndex] = $.verifierFactory.create(0, testMultisig, abi.encode(vault, bytes32(0)));
            address subvault = vault.createSubvault(0, testMultisig, verifiers[subvaultIndex]); // eth,weth,wsteth
            address swapModule = _deploySwapModule0(subvault);
            console2.log("SwapModule0:", swapModule);
            riskManager.allowSubvaultAssets(subvault, assets_);
            riskManager.setSubvaultLimit(subvault, type(int256).max / 2);
        }
        {
            uint256 subvaultIndex = 1;
            verifiers[subvaultIndex] = $.verifierFactory.create(0, testMultisig, abi.encode(vault, bytes32(0)));
            address subvault = vault.createSubvault(0, testMultisig, verifiers[subvaultIndex]); // wsteth, weth
            address swapModule = _deploySwapModule1(subvault);
            console2.log("SwapModule1:", swapModule);
            riskManager.allowSubvaultAssets(
                subvault, ArraysLibrary.makeAddressArray(abi.encode(Constants.WETH, Constants.WSTETH))
            );
            riskManager.setSubvaultLimit(subvault, type(int256).max / 2);
        }

        console2.log("Vault %s", address(vault));

        console2.log("DepositQueue (ETH) %s", address(vault.queueAt(Constants.ETH, 0)));
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
        }

        vm.stopBroadcast();
        // revert("ok");
    }

    function _acceptReports(Vault vault) internal {
        IOracle oracle = vault.oracle();
        for (uint256 i = 0; i < oracle.supportedAssets(); i++) {
            address asset = oracle.supportedAssetAt(i);
            IOracle.DetailedReport memory r = oracle.getReport(asset);
            oracle.acceptReport(asset, uint256(r.priceD18), uint32(r.timestamp));
        }
    }

    function _routers() internal pure returns (address[1] memory result) {
        result = [address(0x6131B5fae19EA4f9D964eAc0408E4408b66337b5)];
    }

    function _deploySwapModule0(address subvault) internal returns (address) {
        return _deployLidoLeverageSwapModule(subvault);
    }

    function _deploySwapModule1(address subvault) internal returns (address swapModule) {
        return _deployLidoLeverageSwapModule(subvault);
    }

    function _deployLidoLeverageSwapModule(address subvault) internal returns (address) {
        IFactory swapModuleFactory = Constants.protocolDeployment().swapModuleFactory;
        address[2] memory lidoLeverage = [Constants.WETH, Constants.WSTETH];
        address[] memory actors =
            ArraysLibrary.makeAddressArray(abi.encode(testMultisig, lidoLeverage, lidoLeverage, _routers()));
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
            testMultisig,
            abi.encode(testMultisig, subvault, Constants.AAVE_V3_ORACLE, DEFAULT_MULTIPLIER, actors, permissions)
        );
    }
}
