// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/governance/TimelockController.sol";
import "forge-std/Test.sol";

import "../../src/vaults/Subvault.sol";
import "../common/AcceptanceLibrary.sol";
import "./Constants.sol";

import "scripts/common/interfaces/IDeployVaultFactory.sol";

abstract contract DeployAbstractScript is Test {
    enum SubvaultVersion {
        DEFAULT
    }
    enum QueueVersion {
        DEFAULT,
        SIGNATURE,
        SYNC
    }

    error ZeroLength();
    error ZeroAddress();
    error ZeroValue();
    error LengthMismatch();
    error AssetNotAllowed(address);
    error SubvaultNotAllowed(address);
    error AlreadyInitialized();
    error NotYetDeployed();
    error Forbidden();

    IDeployVaultFactory internal deployVault = IDeployVaultFactory(payable(address(0)));

    /**
     * @dev STEP 0:
     *   - fill admin/operational addresses and fee parameters
     *   - set assets at getAssetsWithPrices() (assumption: subvault count == allowedSubvaultAssets.length)
     *   - set holders at getVaultRoleHolders()
     *   - set security params at securityParams
     *   - set logic for merkle roots in getSubvaultMerkleRoot()
     *
     * @dev STEP 1:
     *   - run the script with Vault vault = Vault(payable(address(0)))
     *   - then run with the deployed vault address to finalize
     */
    string public vaultName;
    string public vaultSymbol;
    address public proxyAdmin;
    address public lazyVaultAdmin;
    address public activeVaultAdmin;
    address public oracleUpdater;
    address public curator;
    address public feeManagerOwner;
    address public pauser;

    uint24 public depositFeeD6;
    uint24 public redeemFeeD6;
    uint24 public performanceFeeD6;
    uint24 public protocolFeeD6;

    IOracle.SecurityParams public securityParams;

    address defaultDepositHook;
    address defaultRedeemHook;

    /// @dev fill after step one and run script again to finalize deployment
    Vault internal vault;

    function getVaultRoleHolders(address timelockController)
        internal
        view
        virtual
        returns (Vault.RoleHolder[] memory holders);

    function getAssetsWithPrices()
        internal
        pure
        virtual
        returns (address[] memory allowedAssets, uint256[] memory allowedAssetsPrices);

    function getSubvaultParams()
        internal
        view
        virtual
        returns (IDeployVaultFactory.SubvaultParams[] memory subvaultParams);

    function getQueues()
        internal
        virtual
        returns (IDeployVaultFactory.QueueParams[] memory queues, uint256 queueLimit);

    function setUp() public virtual;

    function getSubvaultMerkleRoot(Vault vault, uint256 index) internal view virtual returns (bytes32 merkleRoot);

    function _run() internal {
        setUp();

        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        vm.startBroadcast(deployerPk);

        ProtocolDeployment memory $ = Constants.protocolDeployment();

        defaultDepositHook = address($.redirectingDepositHook);
        defaultRedeemHook = address($.basicRedeemHook);

        /* deployVault = new IDeployVaultFactory(
            address($.vaultConfigurator),
            address($.verifierFactory),
            address($.redirectingDepositHook),
            address($.basicRedeemHook)
        ); */

        IDeployVaultFactory.DeployVaultConfig memory config = getConfig();

        if (vault == Vault(payable(address(0)))) {
            // step one: deploy vault with one queue for base asset, push report and make initial deposit
            vault = stepOne(config);
            vm.stopBroadcast();
        } else {
            SubvaultCalls[] memory calls = stepTwo(vault);
            vm.stopBroadcast();
            checkDeployment(address(vault), calls, config, Constants.protocolDeployment());
            logDeployment(address(vault));
        }
    }

    /// @dev simulate the full deployment in one go
    function _simulate() internal {
        IDeployVaultFactory.DeployVaultConfig memory config = getConfig();

        Vault vault_ = stepOne(config);
        skip(1 seconds);
        SubvaultCalls[] memory calls = stepTwo(vault_);

        checkDeployment(address(vault_), calls, config, Constants.protocolDeployment());
    }

    /**
     * @dev make sure before running step one:
     *   - fill admin/operational addresses and fee parameters
     *   - set assets at getAssetsWithPrices() and holders at getVaultRoleHolders()
     *   - set logic for merkle roots in getSubvaultMerkleRoot()
     */
    function stepOne(IDeployVaultFactory.DeployVaultConfig memory config) internal virtual returns (Vault vault) {
        vault = deployVault.deployVault(config);
        console2.log("Deployed vault at:", address(vault));
    }

    /*
    * @dev make sure before running step two:
    *   - Vault vault is set to the deployed vault address
    */
    function stepTwo(Vault vault) internal virtual returns (SubvaultCalls[] memory calls) {
        IDeployVaultFactory.VaultDeployment memory deployment = getVaultDeployment(address(vault));
        IDeployVaultFactory.SubvaultRoot[] memory subvaultRoots =
            new IDeployVaultFactory.SubvaultRoot[](deployment.subvaults.length);

        calls = new SubvaultCalls[](deployment.subvaults.length);
        for (uint256 i = 0; i < deployment.subvaults.length; i++) {
            subvaultRoots[i].subvault = deployment.subvaults[i];
            subvaultRoots[i].merkleRoot = getSubvaultMerkleRoot(vault, i);
        }

        Vault.RoleHolder[] memory holders = getVaultRoleHolders(address(0));
        deployVault.finalizeDeployment(vault, subvaultRoots, holders);
    }

    function getConfig() internal returns (IDeployVaultFactory.DeployVaultConfig memory config) {
        (address[] memory allowedAssets, uint256[] memory allowedAssetsPrices) = getAssetsWithPrices();

        (IDeployVaultFactory.QueueParams[] memory queues, uint256 queueLimit) = getQueues();

        config = IDeployVaultFactory.DeployVaultConfig({
            vaultName: vaultName,
            vaultSymbol: vaultSymbol,
            proxyAdmin: proxyAdmin,
            lazyVaultAdmin: lazyVaultAdmin,
            activeVaultAdmin: activeVaultAdmin,
            oracleUpdater: oracleUpdater,
            curator: curator,
            pauser: pauser,
            feeManagerParams: IDeployVaultFactory.FeeManagerParams({
                owner: feeManagerOwner,
                depositFeeD6: depositFeeD6,
                redeemFeeD6: redeemFeeD6,
                performanceFeeD6: performanceFeeD6,
                protocolFeeD6: protocolFeeD6
            }),
            allowedAssets: allowedAssets,
            allowedAssetsPrices: allowedAssetsPrices,
            subvaultParams: getSubvaultParams(),
            queues: queues,
            securityParams: securityParams,
            defaultDepositHook: defaultDepositHook,
            defaultRedeemHook: defaultRedeemHook,
            queueLimit: queueLimit
        });

        validateDeployConfig(config);
    }

    function getQueueAssets()
        internal
        returns (address[] memory depositQueueAssets, address[] memory redeemQueueAssets)
    {
        (IDeployVaultFactory.QueueParams[] memory queues,) = getQueues();
        depositQueueAssets = new address[](queues.length);
        redeemQueueAssets = new address[](queues.length);
        uint256 depositIndex;
        uint256 redeemIndex;
        for (uint256 i = 0; i < queues.length; i++) {
            if (queues[i].isDeposit == 1) {
                depositQueueAssets[depositIndex++] = queues[i].asset;
            } else {
                redeemQueueAssets[redeemIndex++] = queues[i].asset;
            }
        }

        assembly {
            mstore(depositQueueAssets, depositIndex)
            mstore(redeemQueueAssets, redeemIndex)
        }
    }

    function checkDeployment(
        address vaultAddress,
        SubvaultCalls[] memory calls,
        IDeployVaultFactory.DeployVaultConfig memory config,
        ProtocolDeployment memory $
    ) internal {
        IDeployVaultFactory.VaultDeployment memory deployment = getVaultDeployment(vaultAddress);
        (address[] memory depositQueueAssets, address[] memory redeemQueueAssets) = getQueueAssets();

        $.deployer = address(deployVault);
        AcceptanceLibrary.runProtocolDeploymentChecks($);
        AcceptanceLibrary.runVaultDeploymentChecks(
            $,
            VaultDeployment({
                vault: deployment.vault,
                calls: calls,
                initParams: deployVault.getInitVaultParams(config),
                holders: getVaultRoleHolders(address(deployment.timelockController)),
                depositHook: address($.redirectingDepositHook),
                redeemHook: address($.basicRedeemHook),
                assets: config.allowedAssets,
                depositQueueAssets: depositQueueAssets,
                redeemQueueAssets: redeemQueueAssets,
                subvaultVerifiers: deployment.verifiers,
                timelockControllers: ArraysLibrary.makeAddressArray(abi.encode(address(deployment.timelockController))),
                timelockProposers: ArraysLibrary.makeAddressArray(abi.encode(lazyVaultAdmin)),
                timelockExecutors: ArraysLibrary.makeAddressArray(abi.encode(pauser))
            })
        );
    }

    function logDeployment(address vault) internal view {
        IDeployVaultFactory.VaultDeployment memory deployment = getVaultDeployment(vault);
        console2.log("-------------------------------------------------------------");
        console2.log("Deployment details %s (%s) chain ID %s", vaultName, vaultSymbol, block.chainid);
        console2.log("-------------------------------------------------------------");
        console2.log("Vault              %s", vault);
        for (uint256 i = 0; i < deployment.subvaults.length; i++) {
            console2.log("  |--Subvault #%s   %s", i, address(deployment.subvaults[i]));
            console2.log("    |--Verifier    %s", address(deployment.verifiers[i]));
        }
        console2.log("Oracle             %s", address(deployment.oracle));
        console2.log("ShareManager       %s", address(deployment.shareManager));
        console2.log("FeeManager         %s", address(deployment.feeManager));
        console2.log("RiskManager        %s", address(deployment.riskManager));
        console2.log("TimelockController %s", address(deployment.timelockController));
        console2.log("-------------------------------------------------------------");
        for (uint256 i = 0; i < deployment.depositQueues.length; i++) {
            console2.log(
                "DepositQueue       %s (%s)",
                address(deployment.depositQueues[i]),
                getSymbol(IQueue(deployment.depositQueues[i]).asset())
            );
        }
        for (uint256 i = 0; i < deployment.redeemQueues.length; i++) {
            console2.log(
                "RedeemQueue        %s (%s)",
                address(deployment.redeemQueues[i]),
                getSymbol(IQueue(deployment.redeemQueues[i]).asset())
            );
        }
        console2.log("-------------------------------------------------------------");
    }

    function getSymbol(address token) internal view returns (string memory) {
        if (token == Constants.ETH) {
            return "ETH";
        }
        return IERC20Metadata(token).symbol();
    }

    function validateDeployConfig(IDeployVaultFactory.DeployVaultConfig memory $) public view {
        if (bytes($.vaultName).length == 0) {
            revert ZeroLength();
        }
        if (bytes($.vaultSymbol).length == 0) {
            revert ZeroLength();
        }
        _checkAddressRoles($);
        _checkAssets($);
    }

    function _checkAddressRoles(IDeployVaultFactory.DeployVaultConfig memory $) internal pure {
        if ($.proxyAdmin == address(0)) {
            revert ZeroAddress();
        }
        if ($.lazyVaultAdmin == address(0)) {
            revert ZeroAddress();
        }
        if ($.activeVaultAdmin == address(0)) {
            revert ZeroAddress();
        }
        if ($.oracleUpdater == address(0)) {
            revert ZeroAddress();
        }
        if ($.curator == address(0)) {
            revert ZeroAddress();
        }
        if ($.pauser == address(0)) {
            revert ZeroAddress();
        }
        if ($.feeManagerParams.owner == address(0)) {
            revert ZeroAddress();
        }
    }

    function _checkAssets(IDeployVaultFactory.DeployVaultConfig memory $) internal view {
        if ($.allowedAssets.length == 0) {
            revert ZeroLength();
        }
        for (uint256 i = 0; i < $.allowedAssets.length; i++) {
            if ($.allowedAssets[i] == address(0)) {
                revert ZeroAddress();
            }
        }
        if ($.queues.length == 0) {
            revert ZeroLength();
        }

        for (uint256 i = 0; i < $.queues.length; i++) {
            bool found;
            for (uint256 j = 0; j < $.allowedAssets.length; j++) {
                if ($.queues[i].asset == $.allowedAssets[j]) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                revert AssetNotAllowed($.queues[i].asset);
            }
        }

        if ($.subvaultParams.length == 0) {
            revert ZeroLength();
        }

        for (uint256 i = 0; i < $.subvaultParams.length; i++) {
            if ($.subvaultParams[i].assets.length == 0) {
                revert ZeroLength();
            }
        }
        for (uint256 i = 0; i < $.subvaultParams.length; i++) {
            for (uint256 j = 0; j < $.subvaultParams[i].assets.length; j++) {
                bool found;
                for (uint256 k = 0; k < $.allowedAssets.length; k++) {
                    if ($.subvaultParams[i].assets[j] == $.allowedAssets[k]) {
                        found = true;
                        break;
                    }
                }
                if (!found) {
                    revert AssetNotAllowed($.subvaultParams[i].assets[j]);
                }
            }
        }
        if ($.allowedAssetsPrices.length != $.allowedAssets.length) {
            revert LengthMismatch();
        }

        for (uint256 i = 0; i < $.allowedAssetsPrices.length; i++) {
            if ($.allowedAssetsPrices[i] == 0) {
                revert ZeroValue();
            }
        }
    }

    function getVaultDeployment(address vaultAddress)
        internal
        view
        returns (IDeployVaultFactory.VaultDeployment memory deployment)
    {
        Vault vault = Vault(payable(vaultAddress));
        deployment.vault = vault;
        deployment.timelockController = deployVault.timelockControllers(address(vault));
        deployment.oracle = vault.oracle();
        deployment.shareManager = vault.shareManager();
        deployment.feeManager = vault.feeManager();
        deployment.riskManager = vault.riskManager();

        uint256 subvaultsCount = vault.subvaults();
        deployment.subvaults = new address[](subvaultsCount);
        deployment.verifiers = new address[](subvaultsCount);
        for (uint256 i = 0; i < subvaultsCount; i++) {
            deployment.subvaults[i] = vault.subvaultAt(i);
            deployment.verifiers[i] = address(Subvault(payable(deployment.subvaults[i])).verifier());
        }

        uint256 totalQueues;
        for (uint256 i = 0; i < vault.getAssetCount(); i++) {
            totalQueues += vault.getQueueCount(vault.assetAt(i));
        }

        address[] memory depositQueues = new address[](totalQueues);
        address[] memory redeemQueues = new address[](totalQueues);

        uint256 depositIndex;
        uint256 redeemIndex;
        for (uint256 i = 0; i < vault.getAssetCount(); i++) {
            address asset = vault.assetAt(i);
            uint256 queueCount = vault.getQueueCount(asset);
            for (uint256 j = 0; j < queueCount; j++) {
                address queue = vault.queueAt(asset, j);
                if (vault.isDepositQueue(queue)) {
                    depositQueues[depositIndex++] = queue;
                } else {
                    redeemQueues[redeemIndex++] = queue;
                }
            }
        }
        assembly {
            mstore(depositQueues, depositIndex)
            mstore(redeemQueues, redeemIndex)
        }
        deployment.depositQueues = depositQueues;
        deployment.redeemQueues = redeemQueues;
    }
}
