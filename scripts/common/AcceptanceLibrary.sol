// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/utils/Strings.sol";
import {VmSafe} from "forge-std/Vm.sol";

import "./interfaces/Imports.sol";

import "./ArraysLibrary.sol";
import "./Permissions.sol";
import "./ProofLibrary.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "forge-std/console.sol";

library AcceptanceLibrary {
    struct OracleSubmitterDeployment {
        OracleSubmitter oracleSubmitter;
        address admin;
        address submitter;
        address accepter;
    }

    function _this() private pure returns (VmSafe) {
        return VmSafe(address(uint160(uint256(keccak256("hevm cheat code")))));
    }

    function removeMetadata(bytes memory bytecode) internal pure returns (bytes memory) {
        // src: https://docs.soliditylang.org/en/v0.8.25/metadata.html#encoding-of-the-metadata-hash-in-the-bytecode
        bytes1 b1 = 0xa2;
        bytes1 b2 = 0x64;
        for (uint256 i = 0; i < bytecode.length; i++) {
            if (bytecode[i] == b1 && bytecode[i + 1] == b2) {
                assembly {
                    mstore(bytecode, i)
                }
                break;
            }
        }

        if (bytecode.length == 0x41e) {
            uint256 mask = type(uint256).max ^ type(uint160).max;
            assembly {
                let ptr := add(bytecode, 48)
                let word := mload(ptr)
                word := and(word, mask)
                mstore(ptr, word)
            }
        }
        return bytecode;
    }

    function compareBytecode(string memory title, address a, address b) internal view {
        if (a == address(0)) {
            return;
        }
        bytes memory aBytecode = removeMetadata(a.code);
        bytes memory bBytecode = removeMetadata(b.code);

        if (keccak256(aBytecode) != keccak256(bBytecode)) {
            console.logBytes(aBytecode);

            console.logBytes(bBytecode);
            revert(
                string.concat(
                    title,
                    ": invalid bytecode. Impl: ",
                    Strings.toHexString(a),
                    " vs Instance: ",
                    Strings.toHexString(b)
                )
            );
        }
    }

    function getProxyInfo(address proxyContract) internal view returns (address implementation, address owner) {
        ProxyAdmin proxyAdmin;
        bytes memory bytecode = proxyContract.code;
        assembly {
            proxyAdmin := mload(add(bytecode, 48))
        }
        owner = proxyAdmin.owner();
        bytes32 value = _this().load(proxyContract, ERC1967Utils.IMPLEMENTATION_SLOT);
        implementation = address(uint160(uint256(value)));
    }

    function runProtocolDeploymentChecks(ProtocolDeployment memory $) internal {
        compareBytecode(
            "Factory", address($.factoryImplementation), address(new Factory($.deploymentName, $.deploymentVersion))
        );
        compareBytecode(
            "Consensus",
            address($.consensusImplementation),
            address(new Consensus($.deploymentName, $.deploymentVersion))
        );
        compareBytecode(
            "DepositQueue",
            address($.depositQueueImplementation),
            address(new DepositQueue($.deploymentName, $.deploymentVersion))
        );
        compareBytecode(
            "SyncDepositQueue",
            address($.syncDepositQueueImplementation),
            address(new SyncDepositQueue($.deploymentName, $.deploymentVersion))
        );
        compareBytecode(
            "RedeemQueue",
            address($.redeemQueueImplementation),
            address(new RedeemQueue($.deploymentName, $.deploymentVersion))
        );

        compareBytecode(
            "SignatureDepositQueue",
            address($.signatureDepositQueueImplementation),
            address(new SignatureDepositQueue($.deploymentName, $.deploymentVersion, address($.consensusFactory)))
        );
        compareBytecode(
            "SignatureRedeemQueue",
            address($.signatureRedeemQueueImplementation),
            address(new SignatureRedeemQueue($.deploymentName, $.deploymentVersion, address($.consensusFactory)))
        );

        compareBytecode(
            "SyncRedeemQueue",
            address($.syncRedeemQueueImplementation),
            address(new SyncRedeemQueue($.deploymentName, $.deploymentVersion))
        );

        compareBytecode(
            "FeeManager",
            address($.feeManagerImplementation),
            address(new FeeManager($.deploymentName, $.deploymentVersion))
        );
        compareBytecode(
            "Oracle", address($.oracleImplementation), address(new Oracle($.deploymentName, $.deploymentVersion))
        );
        compareBytecode(
            "RiskManager",
            address($.riskManagerImplementation),
            address(new RiskManager($.deploymentName, $.deploymentVersion))
        );

        compareBytecode(
            "TokenizedShareManager",
            address($.tokenizedShareManagerImplementation),
            address(new TokenizedShareManager($.deploymentName, $.deploymentVersion))
        );
        compareBytecode(
            "BasicShareManager",
            address($.basicShareManagerImplementation),
            address(new BasicShareManager($.deploymentName, $.deploymentVersion))
        );
        compareBytecode(
            "BurnableTokenizedShareManager",
            address($.burnableTokenizedShareManagerImplementation),
            address(new BurnableTokenizedShareManager($.deploymentName, $.deploymentVersion))
        );

        compareBytecode(
            "Subvault", address($.subvaultImplementation), address(new Subvault($.deploymentName, $.deploymentVersion))
        );
        compareBytecode(
            "Verifier", address($.verifierImplementation), address(new Verifier($.deploymentName, $.deploymentVersion))
        );
        compareBytecode("MellowAccountV1", address($.mellowAccountV1Implementation), address(new MellowAccountV1()));

        compareBytecode(
            "SwapModule",
            address($.swapModuleImplementation),
            address(
                new SwapModule(
                    $.deploymentName, $.deploymentVersion, $.cowswapSettlement, $.cowswapVaultRelayer, $.weth
                )
            )
        );

        compareBytecode(
            "Vault",
            address($.vaultImplementation),
            address(
                new Vault(
                    $.deploymentName,
                    $.deploymentVersion,
                    address($.depositQueueFactory),
                    address($.redeemQueueFactory),
                    address($.subvaultFactory),
                    address($.verifierFactory)
                )
            )
        );

        compareBytecode("BitmaskVerifier", address($.bitmaskVerifier), address(new BitmaskVerifier()));

        compareBytecode(
            "ERC20Verifier",
            address($.erc20VerifierImplementation),
            address(new ERC20Verifier($.deploymentName, $.deploymentVersion))
        );

        compareBytecode(
            "SymbioticVerifier",
            address($.symbioticVerifierImplementation),
            address(
                new SymbioticVerifier(
                    $.symbioticVaultFactory, $.symbioticFarmFactory, $.deploymentName, $.deploymentVersion
                )
            )
        );

        compareBytecode(
            "EigenLayerVerifier",
            address($.eigenLayerVerifierImplementation),
            address(
                new EigenLayerVerifier(
                    $.eigenLayerDelegationManager,
                    $.eigenLayerStrategyManager,
                    $.eigenLayerRewardsCoordinator,
                    $.deploymentName,
                    $.deploymentVersion
                )
            )
        );

        compareBytecode(
            "VaultConfigurator",
            address($.vaultConfigurator),
            address(
                new VaultConfigurator(
                    address($.shareManagerFactory),
                    address($.feeManagerFactory),
                    address($.riskManagerFactory),
                    address($.oracleFactory),
                    address($.vaultFactory)
                )
            )
        );

        compareBytecode("BasicRedeemHook", address($.basicRedeemHook), address(new BasicRedeemHook()));

        compareBytecode(
            "RedirectingDepositHook", address($.redirectingDepositHook), address(new RedirectingDepositHook())
        );

        if (address($.lidoDepositHook) != address(0)) {
            compareBytecode(
                "LidoDepositHook",
                address($.lidoDepositHook),
                address(new LidoDepositHook($.wsteth, $.weth, address($.redirectingDepositHook)))
            );
        }

        compareBytecode("OracleHelper", address($.oracleHelper), address(new OracleHelper()));

        address cleanFactory = address(
            new TransparentUpgradeableProxy(
                address($.factoryImplementation),
                $.proxyAdmin,
                abi.encodeCall(IFactoryEntity.initialize, (abi.encode($.deployer)))
            )
        );

        _checkFactoryInstance(
            $.factory,
            cleanFactory,
            "Factory",
            $.proxyAdmin,
            ArraysLibrary.makeAddressArray(abi.encode($.factoryImplementation))
        );

        _checkFactoryInstance(
            $.erc20VerifierFactory,
            cleanFactory,
            "ERC20Verifier",
            $.proxyAdmin,
            ArraysLibrary.makeAddressArray(abi.encode($.erc20VerifierImplementation))
        );

        _checkFactoryInstance(
            $.symbioticVerifierFactory,
            cleanFactory,
            "SymbioticVerifier",
            $.proxyAdmin,
            ArraysLibrary.makeAddressArray(abi.encode($.symbioticVerifierImplementation))
        );

        _checkFactoryInstance(
            $.eigenLayerVerifierFactory,
            cleanFactory,
            "EigenLayerVerifier",
            $.proxyAdmin,
            ArraysLibrary.makeAddressArray(abi.encode($.eigenLayerVerifierImplementation))
        );

        _checkFactoryInstance(
            $.riskManagerFactory,
            cleanFactory,
            "RiskManager",
            $.proxyAdmin,
            ArraysLibrary.makeAddressArray(abi.encode($.riskManagerImplementation))
        );

        _checkFactoryInstance(
            $.subvaultFactory,
            cleanFactory,
            "Subvault",
            $.proxyAdmin,
            ArraysLibrary.makeAddressArray(abi.encode($.subvaultImplementation))
        );

        _checkFactoryInstance(
            $.verifierFactory,
            cleanFactory,
            "Verifier",
            $.proxyAdmin,
            ArraysLibrary.makeAddressArray(abi.encode($.verifierImplementation))
        );

        _checkFactoryInstance(
            $.vaultFactory,
            cleanFactory,
            "Vault",
            $.proxyAdmin,
            ArraysLibrary.makeAddressArray(abi.encode($.vaultImplementation))
        );

        _checkFactoryInstance(
            $.shareManagerFactory,
            cleanFactory,
            "ShareManager",
            $.proxyAdmin,
            ArraysLibrary.makeAddressArray(
                abi.encode($.tokenizedShareManagerImplementation, $.basicShareManagerImplementation)
            ),
            ArraysLibrary.makeAddressArray(abi.encode($.burnableTokenizedShareManagerImplementation))
        );

        _checkFactoryInstance(
            $.consensusFactory,
            cleanFactory,
            "Consensus",
            $.proxyAdmin,
            ArraysLibrary.makeAddressArray(abi.encode($.consensusImplementation))
        );

        _checkFactoryInstance(
            $.depositQueueFactory,
            cleanFactory,
            "DepositQueue",
            $.proxyAdmin,
            ArraysLibrary.makeAddressArray(
                abi.encode($.depositQueueImplementation, $.signatureDepositQueueImplementation)
            ),
            ArraysLibrary.makeAddressArray(abi.encode($.syncDepositQueueImplementation))
        );

        _checkFactoryInstance(
            $.redeemQueueFactory,
            cleanFactory,
            "RedeemQueue",
            $.proxyAdmin,
            ArraysLibrary.makeAddressArray(
                abi.encode($.redeemQueueImplementation, $.signatureRedeemQueueImplementation)
            ),
            ArraysLibrary.makeAddressArray(abi.encode($.syncRedeemQueueImplementation))
        );

        _checkFactoryInstance(
            $.feeManagerFactory,
            cleanFactory,
            "FeeManager",
            $.proxyAdmin,
            ArraysLibrary.makeAddressArray(abi.encode($.feeManagerImplementation))
        );

        _checkFactoryInstance(
            $.oracleFactory,
            cleanFactory,
            "Oracle",
            $.proxyAdmin,
            ArraysLibrary.makeAddressArray(abi.encode($.oracleImplementation))
        );

        _checkFactoryInstance(
            $.accountFactory,
            cleanFactory,
            "Account",
            $.proxyAdmin,
            new address[](0),
            ArraysLibrary.makeAddressArray(abi.encode($.mellowAccountV1Implementation))
        );

        (address implementation, address owner) = getProxyInfo(address($.factory));
        require(implementation == address($.factoryImplementation), "Invalid base factory implementation");
        require(owner == $.proxyAdmin, "Invalid base factory proxy admin");

        _checkFactoryEntity($.factory, address($.erc20VerifierFactory), "ERC20Verifier Factory", $.proxyAdmin);
        _checkFactoryEntity($.factory, address($.riskManagerFactory), "RiskManager Factory", $.proxyAdmin);
        _checkFactoryEntity($.factory, address($.subvaultFactory), "Subvault Factory", $.proxyAdmin);
        _checkFactoryEntity($.factory, address($.verifierFactory), "Verifier Factory", $.proxyAdmin);
        _checkFactoryEntity($.factory, address($.vaultFactory), "Vault Factory", $.proxyAdmin);
        _checkFactoryEntity($.factory, address($.shareManagerFactory), "ShareManager Factory", $.proxyAdmin);
        _checkFactoryEntity($.factory, address($.consensusFactory), "Consensus Factory", $.proxyAdmin);
        _checkFactoryEntity($.factory, address($.feeManagerFactory), "FeeManager Factory", $.proxyAdmin);
        _checkFactoryEntity($.factory, address($.oracleFactory), "Oracle Factory", $.proxyAdmin);
        _checkFactoryEntity($.factory, address($.accountFactory), "Account Factory", $.proxyAdmin);
        _checkFactoryEntity($.factory, address($.swapModuleFactory), "SwapModule Factory", $.proxyAdmin);
        _checkFactoryEntity($.factory, address($.depositQueueFactory), "DepositQueue Factory", $.proxyAdmin);
        _checkFactoryEntity($.factory, address($.redeemQueueFactory), "RedeemQueue Factory", $.proxyAdmin);

        if (address($.symbioticVerifierFactory) != address(0)) {
            _checkFactoryEntity(
                $.factory, address($.symbioticVerifierFactory), "SymbioticVerifier Factory", $.proxyAdmin
            );
        }

        if (address($.eigenLayerVerifierFactory) != address(0)) {
            _checkFactoryEntity(
                $.factory, address($.eigenLayerVerifierFactory), "EigenLayerVerifier Factory", $.proxyAdmin
            );
        }
    }

    function runVaultDeploymentChecks(ProtocolDeployment memory $, VaultDeployment memory deployment) internal {
        _verifyImplementations($, deployment);

        for (uint256 i = 0; i < deployment.calls.length; i++) {
            Subvault subvault = Subvault(payable(deployment.vault.subvaultAt(i)));
            IVerifier verifier = subvault.verifier();
            for (uint256 j = 0; j < deployment.calls[i].payloads.length; j++) {
                Call[] memory calls = deployment.calls[i].calls[j];
                _verifyCalls(verifier, calls, deployment.calls[i].payloads[j]);
            }
        }

        _verifyPermissions(deployment);

        _verifyGetters($, deployment);
        _verifyVerifiersParams(deployment);
        _verifyTimelockControllers($, deployment);
    }

    function runVaultDeploymentChecks(
        ProtocolDeployment memory $,
        VaultDeployment memory deployment,
        OracleSubmitterDeployment memory oracleSubmitterDeployment
    ) internal {
        _verifyImplementations($, deployment);

        for (uint256 i = 0; i < deployment.calls.length; i++) {
            Subvault subvault = Subvault(payable(deployment.vault.subvaultAt(i)));
            IVerifier verifier = subvault.verifier();
            for (uint256 j = 0; j < deployment.calls[i].payloads.length; j++) {
                Call[] memory calls = deployment.calls[i].calls[j];
                _verifyCalls(verifier, calls, deployment.calls[i].payloads[j]);
            }
        }

        _verifyPermissions(deployment);

        _verifyGetters($, deployment);
        _verifyVerifiersParams(deployment);
        _verifyTimelockControllers($, deployment);
        _verifyOracleSubmitter(oracleSubmitterDeployment, deployment.vault);
    }

    function _verifyOracleSubmitter(OracleSubmitterDeployment memory $, Vault vault) internal {
        if (address($.oracleSubmitter) == address(0)) {
            return;
        }
        {
            bytes memory bytecode1 = address($.oracleSubmitter).code;
            bytes memory bytecode2 = address(
                new OracleSubmitter(address(type(uint160).max), $.submitter, $.accepter, address(vault.oracle()))
            ).code;
            require(
                bytecode1.length == bytecode2.length && keccak256(bytecode1) == keccak256(bytecode2),
                "OracleSubmitter: invalid bytecode"
            );
        }

        require(address($.oracleSubmitter.oracle()) == address(vault.oracle()), "OracleSubmitter: invalid oracle");

        require(
            $.oracleSubmitter.getRoleMemberCount(Permissions.DEFAULT_ADMIN_ROLE) == 1,
            "OracleSubmitter: invalid role count"
        );
        require(
            $.oracleSubmitter.hasRole(Permissions.DEFAULT_ADMIN_ROLE, $.admin), "OracleSubmitter: invalid role holder"
        );
        require(
            $.oracleSubmitter.getRoleMemberCount(Permissions.SUBMIT_REPORTS_ROLE) == 1,
            "OracleSubmitter: invalid role count"
        );
        require(
            $.oracleSubmitter.hasRole(Permissions.SUBMIT_REPORTS_ROLE, $.submitter),
            "OracleSubmitter: invalid role holder"
        );
        require(
            $.oracleSubmitter.getRoleMemberCount(Permissions.ACCEPT_REPORT_ROLE) == 1,
            "OracleSubmitter: invalid role count"
        );
        require(
            $.oracleSubmitter.hasRole(Permissions.ACCEPT_REPORT_ROLE, $.accepter),
            "OracleSubmitter: invalid role holder"
        );
    }

    function _verifyVerifiersParams(VaultDeployment memory deployment) internal view {
        for (uint256 i = 0; i < deployment.subvaultVerifiers.length; i++) {
            Verifier verifier = Verifier(deployment.subvaultVerifiers[i]);
            if (address(deployment.vault) != address(verifier.vault())) {
                revert("Verifier: invalid vault address");
            }
            if (verifier.allowedCalls() != 0) {
                revert("Verifier: allowed calls exist");
            }
            (bytes32 merkleRoot,) = ProofLibrary.generateMerkleProofs(deployment.calls[i].payloads);
            if (merkleRoot != verifier.merkleRoot()) {
                revert("Verifier: invalid merkle root");
            }
        }
    }

    function _verifyTimelockControllers(ProtocolDeployment memory $, VaultDeployment memory deployment) internal {
        for (uint256 i = 0; i < deployment.timelockControllers.length; i++) {
            TimelockController controller = TimelockController(payable(deployment.timelockControllers[i]));
            require(
                !controller.hasRole(Permissions.DEFAULT_ADMIN_ROLE, $.deployer),
                "TimelockController: deployer has DEFAULT_ADMIN_ROLE"
            );
            require(
                !controller.hasRole(controller.EXECUTOR_ROLE(), $.deployer),
                "TimelockController: deployer has EXECUTOR_ROLE"
            );
            require(
                !controller.hasRole(controller.PROPOSER_ROLE(), $.deployer),
                "TimelockController: deployer has PROPOSER_ROLE"
            );
            require(
                !controller.hasRole(controller.CANCELLER_ROLE(), $.deployer),
                "TimelockController: deployer has CANCELLER_ROLE"
            );
            require(
                controller.hasRole(Permissions.DEFAULT_ADMIN_ROLE, deployment.initParams.vaultAdmin),
                "TimelockController: vault admin does not have DEFAULT_ADMIN_ROLE"
            );
            require(controller.getMinDelay() == 0, "TimelockController: non-zero min delay");
            compareBytecode(
                "TimelockController",
                address(controller),
                address(
                    new TimelockController(
                        0, deployment.timelockProposers, deployment.timelockExecutors, deployment.initParams.vaultAdmin
                    )
                )
            );
        }
    }

    function _verifyCalls(IVerifier verifier, Call[] memory calls, IVerifier.VerificationPayload memory payload)
        internal
        view
    {
        for (uint256 k = 0; k < calls.length; k++) {
            Call memory call = calls[k];
            require(
                verifier.getVerificationResult(call.who, call.where, call.value, call.data, payload)
                    == call.verificationResult,
                string(abi.encodePacked("Verifier: invalid verification result at call #", Strings.toString(k)))
            );
        }
    }

    function runVerifyCallsChecks(IVerifier verifier, SubvaultCalls memory calls) internal view {
        for (uint256 i = 0; i < calls.payloads.length; i++) {
            _verifyCalls(verifier, calls.calls[i], calls.payloads[i]);
        }
    }

    function _verifyPermissions(VaultDeployment memory deployment) internal view {
        Vault vault = deployment.vault;
        Vault.RoleHolder[] memory holders = deployment.holders;
        bytes32[] memory permissions = new bytes32[](holders.length);
        uint256[] memory count = new uint256[](holders.length);
        uint256 cnt = 0;
        for (uint256 i = 0; i < holders.length; i++) {
            bool isNew = true;
            for (uint256 j = 0; j < cnt; j++) {
                if (permissions[j] == holders[i].role) {
                    count[j]++;
                    isNew = false;
                    break;
                }
            }
            if (isNew) {
                permissions[cnt] = holders[i].role;
                count[cnt] = 1;
                cnt++;
            }
        }

        assembly {
            mstore(permissions, cnt)
            mstore(count, cnt)
        }

        require(vault.supportedRoles() == cnt, "Vault: invalid number of supported roles");
        for (uint256 i = 0; i < cnt; i++) {
            if (vault.getRoleMemberCount(permissions[i]) != count[i]) {
                for (uint256 j = 0; j < vault.getRoleMemberCount(permissions[i]); j++) {
                    console.log("holder #%s: %s", j, vault.getRoleMember(permissions[i], j));
                }
                revert("Vault: expected role not supported or number of role holders does not match");
            }
            for (uint256 j = 0; j < holders.length; j++) {
                if (holders[j].role == permissions[i]) {
                    if (!vault.hasRole(holders[j].role, holders[j].holder)) {
                        revert("Vault: user does not have an expected role");
                    }
                }
            }
        }
    }

    function _verifyImplementations(ProtocolDeployment memory $, VaultDeployment memory deployment) internal view {
        address owner = deployment.initParams.proxyAdmin;
        Vault vault = deployment.vault;
        _checkFactoryEntity($.vaultFactory, address(vault), "Vault", owner);
        _checkFactoryEntity($.shareManagerFactory, address(vault.shareManager()), "ShareManager", owner);
        _checkFactoryEntity($.riskManagerFactory, address(vault.riskManager()), "RiskManager", owner);
        _checkFactoryEntity($.feeManagerFactory, address(vault.feeManager()), "FeeManager", owner);
        _checkFactoryEntity($.oracleFactory, address(vault.oracle()), "Oracle", owner);
        for (uint256 i = 0; i < deployment.assets.length; i++) {
            address asset = deployment.assets[i];
            uint256 m = vault.getQueueCount(asset);
            for (uint256 j = 0; j < m; j++) {
                address queue = vault.queueAt(asset, j);
                if (vault.isDepositQueue(queue)) {
                    _checkFactoryEntity($.depositQueueFactory, queue, "DepositQueue", owner);
                } else {
                    _checkFactoryEntity($.redeemQueueFactory, queue, "RedeemQuee", owner);
                }
            }
        }

        uint256 subvaults = vault.subvaults();
        require(subvaults == deployment.calls.length, "Vault: invalid subvault count");
        for (uint256 i = 0; i < subvaults; i++) {
            Subvault subvault = Subvault(payable(vault.subvaultAt(i)));
            _checkFactoryEntity($.subvaultFactory, address(subvault), "Subvault", owner);
            if (address(subvault.verifier()) != deployment.subvaultVerifiers[i]) {
                revert("Subault: invalid subvault verifier");
            }
            _checkFactoryEntity($.verifierFactory, deployment.subvaultVerifiers[i], "Verifier", owner);
            if (subvault.vault() != address(vault)) {
                revert("Subvault: invalid vault address");
            }
        }
    }

    function _verifyGetters(ProtocolDeployment memory $, VaultDeployment memory deployment) internal view {
        Vault vault = deployment.vault;

        require(
            address(vault.defaultDepositHook()) == deployment.depositHook, "DepositHook: invalid default deposit hook"
        );
        require(address(vault.defaultRedeemHook()) == deployment.redeemHook, "RedeemHook: invalid default redeem hook");

        require(
            deployment.depositHook == address(0) || deployment.depositHook == address($.redirectingDepositHook)
                || deployment.depositHook == address($.lidoDepositHook),
            "DepositHook: unsupported deposit hook"
        );

        require(
            deployment.redeemHook == address(0) || deployment.redeemHook == address($.basicRedeemHook),
            "RedeemHook: unsupported deposit hook"
        );
        require(
            address(vault.depositQueueFactory()) == address($.depositQueueFactory),
            "Vault: invalid deposit queue factory"
        );
        require(
            address(vault.redeemQueueFactory()) == address($.redeemQueueFactory), "Vault: invalid redeem queue factory"
        );
        require(address(vault.subvaultFactory()) == address($.subvaultFactory), "Vault: invalid subvault factory");
        require(address(vault.verifierFactory()) == address($.verifierFactory), "Vault: invalid verifier factory");

        {
            address[] memory allQueueAssets =
                new address[](deployment.depositQueueAssets.length + deployment.redeemQueueAssets.length);
            ArraysLibrary.insert(allQueueAssets, deployment.depositQueueAssets, 0);
            ArraysLibrary.insert(allQueueAssets, deployment.redeemQueueAssets, deployment.depositQueueAssets.length);
            allQueueAssets = ArraysLibrary.unique(allQueueAssets);

            uint256 n = vault.getAssetCount();
            require(n == allQueueAssets.length, "Vault: invalid asset count");
            for (uint256 i = 0; i < n; i++) {
                require(vault.hasAsset(allQueueAssets[i]), "Vault: expected queue asset does not supported");
            }

            IOracle oracle = vault.oracle();
            require(deployment.assets.length == oracle.supportedAssets(), "Oracle: invalid asset count");
            for (uint256 i = 0; i < n; i++) {
                require(oracle.isSupportedAsset(deployment.assets[i]), "Oracle: expected assets does not supported");
            }
        }

        uint256[] memory depositQueueCount = new uint256[](deployment.assets.length);
        for (uint256 i = 0; i < deployment.depositQueueAssets.length; i++) {
            require(
                vault.hasAsset(deployment.depositQueueAssets[i]), "Vault: expected deposit assets does not supported"
            );
            for (uint256 index = 0; index < deployment.assets.length; index++) {
                if (deployment.assets[index] == deployment.depositQueueAssets[i]) {
                    depositQueueCount[index] += 1;
                    break;
                }
            }
        }

        uint256[] memory redeemQueueCount = new uint256[](deployment.assets.length);
        for (uint256 i = 0; i < deployment.redeemQueueAssets.length; i++) {
            require(vault.hasAsset(deployment.redeemQueueAssets[i]), "Vault: expected redeem assets does not supported");
            for (uint256 index = 0; index < deployment.assets.length; index++) {
                if (deployment.assets[index] == deployment.redeemQueueAssets[i]) {
                    redeemQueueCount[index] += 1;
                    break;
                }
            }
        }

        for (uint256 i = 0; i < deployment.assets.length; i++) {
            uint256 m = vault.getQueueCount(deployment.assets[i]);
            if (m != depositQueueCount[i] + redeemQueueCount[i]) {
                revert("Vault: queue length mismatch");
            }
            for (uint256 j = 0; j < m; j++) {
                address queue = vault.queueAt(deployment.assets[i], j);
                if (vault.isDepositQueue(queue)) {
                    depositQueueCount[i] -= 1;
                } else {
                    redeemQueueCount[i] -= 1;
                }
            }
            if (depositQueueCount[i] != 0 || redeemQueueCount[i] != 0) {
                revert("Vault: invalid queue length (invalid state)");
            }
        }

        // FeeManager
        {
            IFeeManager feeManager = vault.feeManager();
            (, address feeRecipient, uint24 depositFee, uint24 redeemFee, uint24 performanceFee, uint24 protocolFee) =
                abi.decode(deployment.initParams.feeManagerParams, (address, address, uint24, uint24, uint24, uint24));
            require(feeManager.depositFeeD6() == depositFee, "FeeManager: invalid deposit fee");
            require(feeManager.redeemFeeD6() == redeemFee, "FeeManager: invalid redeem fee");
            require(feeManager.performanceFeeD6() == performanceFee, "FeeManager: invalid performance fee");
            require(feeManager.protocolFeeD6() == protocolFee, "FeeManager: invalid protocol fee");
            require(
                Ownable(address(feeManager)).owner() == deployment.initParams.vaultAdmin
                    || Ownable(address(feeManager)).owner() == feeRecipient,
                "FeeManager: invalid owner"
            );
            require(feeManager.feeRecipient() == feeRecipient, "FeeManager: inalid initial fee recipient");
            require(
                feeManager.baseAsset(address(vault)) == address(0)
                    || vault.oracle().isSupportedAsset(feeManager.baseAsset(address(vault))),
                "FeeManager: invalid base asset"
            );
        }

        // RiskManager

        {
            IRiskManager riskManager = vault.riskManager();
            require(riskManager.vault() == address(deployment.vault), "RiskManager: invalid vault address");
        }

        // ShareManager
        {
            IShareManager shareManager = vault.shareManager();
            require(shareManager.vault() == address(deployment.vault), "ShareManager: invalid vault address");

            try IERC20(address(shareManager)).totalSupply() returns (uint256) {
                // TokenizedShareManager
                (bytes32 whitelistMerkleRoot_, string memory name_, string memory symbol_) =
                    abi.decode(deployment.initParams.shareManagerParams, (bytes32, string, string));
                require(
                    whitelistMerkleRoot_ == shareManager.whitelistMerkleRoot(),
                    "TokenizedShareManager: invalid whitelist merkle root"
                );
                require(
                    keccak256(abi.encode(name_)) == keccak256(abi.encode(IERC20Metadata(address(shareManager)).name())),
                    "TokenizedShareManager: invalid ERC20 name"
                );
                require(
                    keccak256(abi.encode(symbol_))
                        == keccak256(abi.encode(IERC20Metadata(address(shareManager)).symbol())),
                    "TokenizedShareManager: invalid ERC20 name"
                );
                require(
                    IERC20Metadata(address(shareManager)).decimals() == 18, "TokenizedShareManager: invalid decimals"
                );
            } catch {
                // BasicShareManager
                (bytes32 whitelistMerkleRoot_) = abi.decode(deployment.initParams.shareManagerParams, (bytes32));
                require(
                    whitelistMerkleRoot_ == shareManager.whitelistMerkleRoot(),
                    "BasicShareManager: invalid whitelist merkle root"
                );
            }
        }

        // Oracle
        {
            IOracle oracle = vault.oracle();
            require(address(oracle.vault()) == address(deployment.vault), "Oracle: invalid vault address");
            for (uint256 i = 0; i < deployment.assets.length; i++) {
                address asset = deployment.assets[i];
                require(oracle.isSupportedAsset(asset), "Oracle: unsupported assets");
            }
            (IOracle.SecurityParams memory securityParams_,) =
                abi.decode(deployment.initParams.oracleParams, (IOracle.SecurityParams, address[]));
            require(
                keccak256(abi.encode(securityParams_)) == keccak256(abi.encode(oracle.securityParams())),
                "Oracle: invalid security params"
            );
        }
    }

    function _checkFactoryInstance(
        Factory factory,
        address cleanFactory,
        string memory name,
        address expectedOwner,
        address[] memory expectedImplementations
    ) internal view {
        _checkFactoryInstance(factory, cleanFactory, name, expectedOwner, expectedImplementations, new address[](0));
    }

    function _checkFactoryInstance(
        Factory factory,
        address cleanFactory,
        string memory name,
        address expectedOwner,
        address[] memory expectedImplementations,
        address[] memory optionalImplementations
    ) internal view {
        if (address(factory) == address(0)) {
            return;
        }
        compareBytecode(string.concat("Factory ", name), address(factory), cleanFactory);

        if (factory.owner() != expectedOwner) {
            revert(string.concat("Invalid Factory ", name, " owner"));
        }

        uint256 implementations = factory.implementations();
        uint256 matchingImplementations = 0;
        for (uint256 i = 0; i < implementations; i++) {
            address impl = factory.implementationAt(i);
            if (factory.isBlacklisted(i)) {
                if (
                    ArraysLibrary.has(expectedImplementations, impl) || ArraysLibrary.has(optionalImplementations, impl)
                ) {
                    revert(string.concat("Factory ", name, " has valid implementation as blacklisted"));
                }
            } else {
                if (ArraysLibrary.has(optionalImplementations, impl)) {
                    continue;
                }
                if (!ArraysLibrary.has(expectedImplementations, impl)) {
                    revert(string.concat("Factory ", name, " has unexpected whitelisted implementation"));
                }
                matchingImplementations++;
            }
        }

        if (expectedImplementations.length > matchingImplementations) {
            revert(string.concat("Factory ", name, " does not have all expected implementations whitelisted"));
        }
    }

    function _checkFactoryEntity(Factory factory, address entity, string memory name, address expectedOwner)
        internal
        view
    {
        if (entity == address(0)) {
            return;
        }
        if (!factory.isEntity(entity)) {
            revert(string(abi.encodePacked("Contract is not an entity for ", name, " factory")));
        }
        (address implementation, address owner) = getProxyInfo(entity);
        if (owner != expectedOwner) {
            revert("ProxyAdmin: invalid owner");
        }
        uint256 n = factory.implementations();
        for (uint256 i = 0; i < n; i++) {
            if (factory.implementationAt(i) == implementation) {
                return;
            }
        }
        revert(string(abi.encodePacked("Factory: implementation not found for contract ", name)));
    }
}
