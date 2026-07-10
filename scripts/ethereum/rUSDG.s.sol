// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import "../common/interfaces/ICowswapSettlement.sol";
import {IWETH as WETHInterface} from "../common/interfaces/IWETH.sol";
import {IWSTETH as WSTETHInterface} from "../common/interfaces/IWSTETH.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "../../src/oracles/OracleSubmitter.sol";
import "../../src/vaults/Subvault.sol";
import "../../src/vaults/VaultConfigurator.sol";

import "../common/AcceptanceLibrary.sol";
import "../common/Permissions.sol";
import "../common/ProofLibrary.sol";

import "./Constants.sol";

import "../common/ArraysLibrary.sol";

import "../common/interfaces/IAggregatorV3.sol";

contract Deploy is Script, Test {
    // Actors
    // Lido + Mellow 5/8 multisig
    address public proxyAdmin = 0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0;
    address public lazyVaultAdmin = 0x5f56922c6B8a1329f27fBB10aD1BB162E1d9262a;
    address public activeVaultAdmin = 0xF1f8f662c5c8CCad4D9Fb9042de552c6909EDD12;
    address public curator = 0x43664447e88f8b1e7E5656c992310e71d47336B6;

    address public oracleUpdater = 0xd132171976852b6c9f76c1e48dc0CfF6971372f5;
    address public oracleAccepter = lazyVaultAdmin;
    address public treasury = lazyVaultAdmin;

    address public pauser = 0x5C5be9Ad704B28D79775Ff8303c5f599fA91412B;

    string public name = "USDG Yield Vault";
    string public symbol = "rUSDG";

    address public immutable CUSTOM_AAVE_V3_ORACLE = 0x926458ef12bf61F0B54cE66d459738B2A21EC716;
    uint256 public constant DEFAULT_MULTIPLIER = 0.995e8;

    address[] assets_ = ArraysLibrary.makeAddressArray(abi.encode(Constants.USDG));

    address[] verifiers = new address[](1);

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

        console.log("------------------------------------");
        console.log("%s (%s)", name, symbol);
        console.log("------------------------------------");
        console.log("Actors:");
        console.log("------------------------------------");
        console.log("ProxyAdmin", proxyAdmin);
        console.log("LazyAdmin", lazyVaultAdmin);
        console.log("ActiveAdmin", activeVaultAdmin);

        console.log("Curator", curator);

        console.log("OracleUpdater", oracleUpdater);
        console.log("OracleAccepter", oracleAccepter);
        console.log("Treasury", treasury);

        console.log("Pauser", pauser);

        console.log("------------------------------------");
        console.log("Addresses:");
        console.log("------------------------------------");

        {
            uint256 i = 0;
            // curator roles:
            holders[i++] = Vault.RoleHolder(Permissions.CALLER_ROLE, curator);

            // emergeny pauser roles:
            holders[i++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, address(timelockController));

            // deployer roles:
            holders[i++] = Vault.RoleHolder(Permissions.CREATE_SUBVAULT_ROLE, deployer);
            holders[i++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, deployer);

            assembly {
                mstore(holders, i)
            }
        }

        ProtocolDeployment memory $ = Constants.protocolDeployment();
        VaultConfigurator.InitParams memory initParams = VaultConfigurator.InitParams({
            version: 0,
            proxyAdmin: proxyAdmin,
            vaultAdmin: lazyVaultAdmin,
            shareManagerVersion: 2,
            shareManagerParams: abi.encode(bytes32(0), name, symbol),
            feeManagerVersion: 0,
            feeManagerParams: abi.encode(deployer, treasury, uint24(0), uint24(0), uint24(0), uint24(0)),
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
                    depositInterval: type(uint32).max,
                    redeemInterval: type(uint32).max
                }),
                new address[](0)
            ),
            defaultDepositHook: address(0),
            defaultRedeemHook: address(0),
            queueLimit: 0,
            roleHolders: holders
        });

        Vault vault;
        {
            (,,,, address vault_) = $.vaultConfigurator.create(initParams);
            vault = Vault(payable(vault_));
        }

        // fee manager setup
        vault.feeManager().setBaseAsset(address(vault), Constants.USDG);
        Ownable(address(vault.feeManager())).transferOwnership(lazyVaultAdmin);

        // subvault setup

        {
            uint256 subvaultIndex = 0;
            verifiers[subvaultIndex] = $.verifierFactory.create(0, proxyAdmin, abi.encode(vault, bytes32(0)));
            address subvault = vault.createSubvault(0, proxyAdmin, verifiers[subvaultIndex]);
            address swapModule = _deploySwapModule(subvault);
            console.log("SwapModule 0:", swapModule);
            console.log("Subvault 0:", subvault);
            console.log("Verifier 0:", verifiers[0]);
        }

        vault.renounceRole(Permissions.CREATE_SUBVAULT_ROLE, deployer);

        // emergency pause setup
        for (uint256 i = 0; i < verifiers.length; i++) {
            timelockController.schedule(
                verifiers[i], 0, abi.encodeCall(IVerifier.setMerkleRoot, (bytes32(0))), bytes32(0), bytes32(0), 0
            );
        }

        timelockController.renounceRole(timelockController.PROPOSER_ROLE(), deployer);
        timelockController.renounceRole(timelockController.CANCELLER_ROLE(), deployer);

        console.log("Vault %s", address(vault));

        console.log("Oracle %s", address(vault.oracle()));
        console.log("ShareManager %s", address(vault.shareManager()));
        console.log("FeeManager %s", address(vault.feeManager()));
        console.log("RiskManager %s", address(vault.riskManager()));

        for (uint256 i = 0; i < vault.subvaults(); i++) {
            address subvault = vault.subvaultAt(i);
            console.log("Subvault %s %s", i, subvault);
            console.log("Verifier %s %s", i, address(Subvault(payable(subvault)).verifier()));
        }
        console.log("Timelock controller:", address(timelockController));
        vm.stopBroadcast();

        // revert("ok");
    }


    function _routers() internal pure returns (address[1] memory result) {
        result = [address(0x6131B5fae19EA4f9D964eAc0408E4408b66337b5)];
    }

    function _deploySwapModule(address subvault) internal returns (address) {
        IFactory swapModuleFactory = Constants.protocolDeployment().swapModuleFactory;
        address[3] memory assets = [Constants.USDE, Constants.USDG, Constants.SYRUP_USDG];
        address[] memory actors = ArraysLibrary.makeAddressArray(abi.encode(curator, assets, assets, _routers()));
        bytes32[] memory permissions = ArraysLibrary.makeBytes32Array(
            abi.encode(
                Permissions.SWAP_MODULE_CALLER_ROLE,
                [
                    Permissions.SWAP_MODULE_TOKEN_IN_ROLE,
                    Permissions.SWAP_MODULE_TOKEN_IN_ROLE,
                    Permissions.SWAP_MODULE_TOKEN_IN_ROLE
                ],
                [
                    Permissions.SWAP_MODULE_TOKEN_OUT_ROLE,
                    Permissions.SWAP_MODULE_TOKEN_OUT_ROLE,
                    Permissions.SWAP_MODULE_TOKEN_OUT_ROLE
                ],
                Permissions.SWAP_MODULE_ROUTER_ROLE
            )
        );
        return swapModuleFactory.create(
            0,
            proxyAdmin,
            abi.encode(lazyVaultAdmin, subvault, CUSTOM_AAVE_V3_ORACLE, DEFAULT_MULTIPLIER, actors, permissions)
        );
    }
}
