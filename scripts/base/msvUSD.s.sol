// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../common/ArraysLibrary.sol";

import "../common/DeployVaultFactory.sol";
import "../common/DeployVaultFactoryRegistry.sol";
import "../common/OracleSubmitterFactory.sol";
import "../common/ProofLibrary.sol";

import "../common/interfaces/IPositionManagerV3.sol";
import {IPositionManagerV4} from "../common/interfaces/IPositionManagerV4.sol";

import "../common/protocols/UniswapV4Library.sol";
import "./DeployAbstractScript.s.sol";

contract Deploy is DeployAbstractScript {
    function run() external {
        ProtocolDeployment memory $ = Constants.protocolDeployment();

        deployVault = Constants.deployVaultFactory;

        /// @dev just on-chain simulation
        _simulate();

        /// @dev on-chain transaction
        //  if vault == address(0) -> step one
        //  else -> step two
        /// @dev fill in Vault address to run stepTwo
        vault = Vault(payable(address(0)));
        //_run();
        revert("ok");
    }

    function setUp() public override {
        /// @dev fill name and symbol
        vaultName = "Mezo Stable Vault";
        vaultSymbol = "msvUSD";
        emptyVault = true;
        deployOracleSubmitter = false;

        /// @dev fill admin/operational addresses
        proxyAdmin = 0x54977739CF18B316f47B1e10E3068Bb3F04e08B6; // 3/4 Mellow +
        lazyVaultAdmin = 0x0571A6ca8e1AD9822FA69e9cb7854110FD77d24d; // 3/4 Mellow +
        activeVaultAdmin = 0x0f01301a869B7C15a782bd2e60beB08C8709CC08; // 1/2 lhava +
        oracleUpdater = 0x96ff6055DFdcd0d370D77b6dCd6a465438A613D5; // 1/2 lhava +
        curator = 0x3c9B9D820188fF57c8482EbFdF1093b1EFeFf068; // 1/2 lhava +
        feeManagerOwner = lazyVaultAdmin; // Mellow+Sense 5/4+4
        pauser = 0x2EE0AB05EB659E0681DC5f2EabFf1F4D284B3Ef7; // 3/4 Mellow +

        timelockProposers = ArraysLibrary.makeAddressArray(abi.encode(lazyVaultAdmin));
        timelockExecutors = ArraysLibrary.makeAddressArray(abi.encode(lazyVaultAdmin, pauser));

        /// @dev fill fee parameters
        depositFeeD6 = 0;
        redeemFeeD6 = 0;
        performanceFeeD6 = 200000;
        protocolFeeD6 = 10000;

        /// @dev fill security params
        securityParams = IOracle.SecurityParams({
            maxAbsoluteDeviation: 1,
            suspiciousAbsoluteDeviation: 1,
            maxRelativeDeviationD18: 1,
            suspiciousRelativeDeviationD18: 1,
            timeout: 365 days,
            depositInterval: 365 days, // does not affect sync deposit queue
            redeemInterval: 365 days // no redemptions allowed
        });

        ProtocolDeployment memory $ = Constants.protocolDeployment();

        /// @dev fill default hooks
        defaultDepositHook = address($.redirectingDepositHook);
        defaultRedeemHook = address($.basicRedeemHook);

        /// @dev fill share manager params
        shareManagerWhitelistMerkleRoot = bytes32(0);

        /// @dev fill risk manager params
        riskManagerLimit = type(int256).max;

        /// @dev fill versions
        vaultVersion = 0;
        shareManagerVersion = 0; // TokenizedShareManager, impl: 0x0000000E8eb7173fA1a3ba60eCA325bcB6aaf378
        feeManagerVersion = 0;
        riskManagerVersion = 0;
        oracleVersion = 0;
    }

    /// @dev fill in subvault parameters
    function getSubvaultParams()
        internal
        pure
        override
        returns (IDeployVaultFactory.SubvaultParams[] memory subvaultParams)
    {
        subvaultParams = new IDeployVaultFactory.SubvaultParams[](1);

        subvaultParams[0].assets = ArraysLibrary.makeAddressArray(abi.encode(Constants.USDC, Constants.MUSD));
        subvaultParams[0].version = uint256(SubvaultVersion.DEFAULT);
        subvaultParams[0].verifierVersion = 0;
        subvaultParams[0].limit = type(int256).max;
    }

    /// @dev fill in queue parameters
    function getQueues()
        internal
        pure
        override
        returns (IDeployVaultFactory.QueueParams[] memory queues, uint256 queueLimit)
    {}

    /// @dev fill in allowed assets/base asset and subvault assets
    function getAssetsWithPrices()
        internal
        pure
        override
        returns (address[] memory allowedAssets, uint224[] memory allowedAssetsPrices)
    {
        allowedAssets = ArraysLibrary.makeAddressArray(abi.encode(Constants.USDC, Constants.MUSD));

        allowedAssetsPrices = new uint224[](allowedAssets.length);
        allowedAssetsPrices[0] = 1 ether; // 6 decimals
        allowedAssetsPrices[1] = 1e6; // 18 decimals
    }

    /// @dev fill in vault role holders
    function getVaultRoleHolders(address timelockController, address oracleSubmitter)
        internal
        view
        override
        returns (Vault.RoleHolder[] memory holders)
    {
        uint256 index;
        holders = new Vault.RoleHolder[](15 + (timelockController == address(0) ? 0 : 3));

        // lazyVaultAdmin roles:
        holders[index++] = Vault.RoleHolder(Permissions.DEFAULT_ADMIN_ROLE, lazyVaultAdmin);
        holders[index++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, lazyVaultAdmin);
        holders[index++] = Vault.RoleHolder(Permissions.ALLOW_CALL_ROLE, lazyVaultAdmin);
        holders[index++] = Vault.RoleHolder(Permissions.DISALLOW_CALL_ROLE, lazyVaultAdmin);
        holders[index++] = Vault.RoleHolder(Permissions.SET_VAULT_LIMIT_ROLE, lazyVaultAdmin);
        holders[index++] = Vault.RoleHolder(Permissions.SET_SECURITY_PARAMS_ROLE, lazyVaultAdmin);

        // activeVaultAdmin roles:
        holders[index++] = Vault.RoleHolder(Permissions.SET_SUBVAULT_LIMIT_ROLE, activeVaultAdmin);
        holders[index++] = Vault.RoleHolder(Permissions.ALLOW_SUBVAULT_ASSETS_ROLE, activeVaultAdmin);
        holders[index++] = Vault.RoleHolder(Permissions.MODIFY_VAULT_BALANCE_ROLE, activeVaultAdmin);
        holders[index++] = Vault.RoleHolder(Permissions.MODIFY_SUBVAULT_BALANCE_ROLE, activeVaultAdmin);

        // emergency pauser roles:
        if (timelockController != address(0)) {
            holders[index++] = Vault.RoleHolder(Permissions.SET_FLAGS_ROLE, timelockController);
            holders[index++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, timelockController);
            holders[index++] = Vault.RoleHolder(Permissions.SET_QUEUE_STATUS_ROLE, timelockController);
        }

        // oracle submitter roles:
        if (oracleSubmitter != address(0)) {
            holders[index++] = Vault.RoleHolder(Permissions.ACCEPT_REPORT_ROLE, oracleSubmitter);
            holders[index++] = Vault.RoleHolder(Permissions.SUBMIT_REPORTS_ROLE, oracleSubmitter);
        } else {
            holders[index++] = Vault.RoleHolder(Permissions.ACCEPT_REPORT_ROLE, activeVaultAdmin);
            holders[index++] = Vault.RoleHolder(Permissions.SUBMIT_REPORTS_ROLE, oracleUpdater);
        }

        // curator roles:
        holders[index++] = Vault.RoleHolder(Permissions.CALLER_ROLE, curator);
        holders[index++] = Vault.RoleHolder(Permissions.PULL_LIQUIDITY_ROLE, curator);
        holders[index++] = Vault.RoleHolder(Permissions.PUSH_LIQUIDITY_ROLE, curator);
    }

    /// @dev fill in merkle roots
    function getSubvaultMerkleRoot(uint256 index)
        internal
        override
        returns (bytes32 merkleRoot, SubvaultCalls memory calls)
    {
        Subvault subvault = Subvault(payable(vault.subvaultAt(index)));
        IVerifier verifier = subvault.verifier();

        IVerifier.VerificationPayload[] memory leaves;
        string[] memory descriptions;
        string memory jsonSubvaultName;

        if (index == 0) {
            (merkleRoot, leaves, descriptions, calls, jsonSubvaultName) = _getSubvault0MerkleRoot(address(subvault));
        } else {
            revert("Invalid subvault index");
        }
        /*
                ProofLibrary.storeProofs(jsonSubvaultName, merkleRoot, leaves, descriptions);

                vm.prank(lazyVaultAdmin);
                verifier.setMerkleRoot(merkleRoot);

                AcceptanceLibrary.runVerifyCallsChecks(verifier, calls); */
    }

    function _getSubvault0MerkleRoot(address subvault)
        private
        returns (
            bytes32 merkleRoot,
            IVerifier.VerificationPayload[] memory leaves,
            string[] memory descriptions,
            SubvaultCalls memory calls,
            string memory jsonSubvaultName
        )
    {
        jsonSubvaultName = "base:mbhBTC:subvault0";
    }

    function _deploySwapModule(address subvault, address[] memory actors, bytes32[] memory permissions)
        internal
        returns (address swapModule)
    {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);

        IFactory swapModuleFactory = Constants.protocolDeployment().swapModuleFactory;

        vm.startBroadcast(deployerPk);
        swapModule = swapModuleFactory.create(
            0, proxyAdmin, abi.encode(lazyVaultAdmin, subvault, Constants.AAVE_V3_ORACLE, 0.995e8, actors, permissions)
        );
        console2.log("Deployed SwapModule at", swapModule);
        vm.stopBroadcast();
        return swapModule;
    }
}
