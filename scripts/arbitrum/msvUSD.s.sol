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
    address public proxyAdmin = 0x54977739CF18B316f47B1e10E3068Bb3F04e08B6; // +
    address public lazyVaultAdmin = 0x0571A6ca8e1AD9822FA69e9cb7854110FD77d24d; // +
    address public activeVaultAdmin = 0x0f01301a869B7C15a782bd2e60beB08C8709CC08; // +
    address public oracleUpdater = 0x96ff6055DFdcd0d370D77b6dCd6a465438A613D5; // +
    address public curator = 0x3c9B9D820188fF57c8482EbFdF1093b1EFeFf068; // +

    address public pauser = 0x2EE0AB05EB659E0681DC5f2EabFf1F4D284B3Ef7; // +

    address subvault0Ethereum = 0x9757bbb42B3fAAc201d5Ba2374b9Ac62dc77a584;

    function run() external {
        // create fork just to replay deployment for the vault 0x13515096066708d14a06eAA2600c5c692954242E
        string memory rpcUrl = vm.envString("ARBITRUM_RPC");
        uint256 forkId = vm.createSelectFork(rpcUrl, 423615509);
        vm.selectFork(forkId);

        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);

        vm.startBroadcast(deployerPk);

        Vault.RoleHolder[] memory holders = new Vault.RoleHolder[](42);
        TimelockController timelockController;

        {
            address[] memory proposers = ArraysLibrary.makeAddressArray(abi.encode(lazyVaultAdmin, deployer));
            address[] memory executors = ArraysLibrary.makeAddressArray(abi.encode(pauser, activeVaultAdmin));
            timelockController = new TimelockController(0, proposers, executors, lazyVaultAdmin);
        }
        {
            uint256 i = 0;

            // activeVaultAdmin roles:
            holders[i++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, activeVaultAdmin);

            // timelock roles:
            holders[i++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, address(timelockController));

            // curator roles:
            holders[i++] = Vault.RoleHolder(Permissions.CALLER_ROLE, curator);

            // deployer roles:
            holders[i++] = Vault.RoleHolder(Permissions.CREATE_SUBVAULT_ROLE, deployer);
            holders[i++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, deployer);

            assembly {
                mstore(holders, i)
            }
        }

        ProtocolDeployment memory $ = Constants.protocolDeployment();
        Vault vault;
        VaultConfigurator.InitParams memory initParams = VaultConfigurator.InitParams({
            version: 0,
            proxyAdmin: proxyAdmin,
            vaultAdmin: lazyVaultAdmin,
            shareManagerVersion: 0,
            shareManagerParams: abi.encode(bytes32(0), "Mezo Stable Vault", "msvUSD"),
            feeManagerVersion: 0,
            feeManagerParams: abi.encode(lazyVaultAdmin, lazyVaultAdmin, uint24(0), uint24(0), uint24(0), uint24(0)),
            riskManagerVersion: 0,
            riskManagerParams: abi.encode(0),
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
        {
            (,,,, address vault_) = $.vaultConfigurator.create(initParams);
            vault = Vault(payable(vault_));
        }

        // subvault setup
        address[] memory verifiers = new address[](1);
        SubvaultCalls[] memory calls = new SubvaultCalls[](1);

        (verifiers[0], calls[0]) = _createSubvault0(vault);

        // emergency pause setup

        timelockController.schedule(
            verifiers[0], 0, abi.encodeCall(IVerifier.setMerkleRoot, (bytes32(0))), bytes32(0), bytes32(0), 0
        );

        timelockController.renounceRole(timelockController.PROPOSER_ROLE(), deployer);
        timelockController.renounceRole(timelockController.CANCELLER_ROLE(), deployer);

        vault.renounceRole(Permissions.CREATE_SUBVAULT_ROLE, deployer);
        vault.renounceRole(Permissions.SET_MERKLE_ROOT_ROLE, deployer);

        console2.log("Vault %s", address(vault));

        for (uint256 i = 0; i < vault.subvaults(); i++) {
            address subvault = vault.subvaultAt(i);
            console2.log("Subvault %s %s", i, subvault);
            console2.log("Verifier %s %s", i, address(IVerifierModule(subvault).verifier()));
        }

        console2.log("Timelock controller:", address(timelockController));

        vm.stopBroadcast();
        ProtocolDeployment memory protocolDeployment = Constants.protocolDeployment();
        protocolDeployment.deployer = deployer;

        AcceptanceLibrary.runProtocolDeploymentChecks(protocolDeployment);
        AcceptanceLibrary.runVaultDeploymentChecks(
            protocolDeployment,
            VaultDeployment({
                vault: vault,
                calls: calls,
                initParams: initParams,
                holders: _getExpectedHolders(timelockController),
                depositHook: address(0),
                redeemHook: address(0),
                assets: new address[](0),
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

    function _getExpectedHolders(TimelockController timelockController)
        internal
        view
        returns (Vault.RoleHolder[] memory holders)
    {
        holders = new Vault.RoleHolder[](50);
        uint256 i = 0;

        // lazyVaultAdmin roles:
        holders[i++] = Vault.RoleHolder(Permissions.DEFAULT_ADMIN_ROLE, lazyVaultAdmin);

        // timelock roles:
        holders[i++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, address(timelockController));

        // activeVaultAdmin roles:
        holders[i++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, activeVaultAdmin);

        // curator roles:
        holders[i++] = Vault.RoleHolder(Permissions.CALLER_ROLE, curator);

        assembly {
            mstore(holders, i)
        }
    }

    function _createSubvault0(Vault vault) internal returns (address verifier, SubvaultCalls memory calls) {
        verifier = vault.verifierFactory().create(0, proxyAdmin, abi.encode(vault, bytes32(0)));
        vault.createSubvault(0, proxyAdmin, verifier);
        (, calls) = _createSubvault0Proofs(vault);
    }

    function _deploySwapModule(address subvault) internal returns (address swapModule, address[] memory assets) {
        IFactory swapModuleFactory = Constants.protocolDeployment().swapModuleFactory;
        address[2] memory tokens = [Constants.USDT, Constants.USDC];
        address[] memory actors =
            ArraysLibrary.makeAddressArray(abi.encode(curator, tokens, tokens, Constants.KYBERSWAP_ROUTER));
        bytes32[] memory permissions = ArraysLibrary.makeBytes32Array(
            abi.encode(
                Permissions.SWAP_MODULE_CALLER_ROLE,
                Permissions.SWAP_MODULE_TOKEN_IN_ROLE,
                Permissions.SWAP_MODULE_TOKEN_IN_ROLE,
                Permissions.SWAP_MODULE_TOKEN_OUT_ROLE,
                Permissions.SWAP_MODULE_TOKEN_OUT_ROLE,
                Permissions.SWAP_MODULE_ROUTER_ROLE
            )
        );

        swapModule = swapModuleFactory.create(
            0, proxyAdmin, abi.encode(lazyVaultAdmin, subvault, Constants.AAVE_V3_ORACLE, 0.995e8, actors, permissions)
        );
        return (swapModule, ArraysLibrary.makeAddressArray(abi.encode(tokens)));
    }

    function _createSubvault0Proofs(Vault vault) internal returns (bytes32 merkleRoot, SubvaultCalls memory calls) {
        address payable subvault0Arbitrum = payable(vault.subvaultAt(0));
        (address swapModule, address[] memory swapModuleAssets) = _deploySwapModule(subvault0Arbitrum);

        msvUSDLibrary.Info memory info = msvUSDLibrary.Info({
            curator: curator,
            subvaultEth: subvault0Ethereum,
            subvaultArb: subvault0Arbitrum,
            swapModule: swapModule,
            subvaultEthName: "subvault0:ethereum",
            subvaultArbName: "subvault0:arbitrum",
            targetChainName: "Ethereum",
            oftUSDT: Constants.USDT_OFT_ADAPTER,
            fUSDT: Constants.FLUID_USDT_FTOKEN,
            fUSDC: Constants.FLUID_USDC_FTOKEN,
            swapModuleAssets: swapModuleAssets,
            kyberRouter: Constants.KYBERSWAP_ROUTER,
            kyberSwapAssets: ArraysLibrary.makeAddressArray(abi.encode(Constants.CRV, Constants.FLUID))
        });

        IVerifier.VerificationPayload[] memory leaves;
        (merkleRoot, leaves) = msvUSDLibrary.getSubvault0Proofs(info);

        Subvault(subvault0Arbitrum).verifier().setMerkleRoot(merkleRoot);

        string[] memory descriptions = msvUSDLibrary.getSubvault0Descriptions(info);
        ProofLibrary.storeProofs("arbitrum:msvUSD:subvault0", merkleRoot, leaves, descriptions);

        calls = msvUSDLibrary.getSubvault0Calls(info, leaves);
    }
}
