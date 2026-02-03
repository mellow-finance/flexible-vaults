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
            "Subvault", address($.subvaultImplementation), address(new Subvault($.deploymentName, $.deploymentVersion))
        );
        compareBytecode(
            "Verifier", address($.verifierImplementation), address(new Verifier($.deploymentName, $.deploymentVersion))
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

        compareBytecode(
            "Factory Factory",
            address($.factory),
            address(
                new TransparentUpgradeableProxy(
                    address($.factoryImplementation),
                    $.proxyAdmin,
                    abi.encodeCall(IFactoryEntity.initialize, (abi.encode($.deployer)))
                )
            )
        );

        require($.factory.implementations() == 1, "Factory Factory: invalid implementations length");
        require(
            $.factory.implementationAt(0) == address($.factoryImplementation),
            "Factory Factory: invalid implementation at 0"
        );

        compareBytecode(
            "Factory ERC20Verifier",
            address($.erc20VerifierFactory),
            address(
                new TransparentUpgradeableProxy(
                    address($.factoryImplementation),
                    $.proxyAdmin,
                    abi.encodeCall(IFactoryEntity.initialize, (abi.encode($.deployer)))
                )
            )
        );
        require($.erc20VerifierFactory.implementations() == 1, "Factory ERC20Verifier: invalid implementations length");
        require(
            $.erc20VerifierFactory.implementationAt(0) == address($.erc20VerifierImplementation),
            "Factory ERC20Verifier: invalid implementation at 0"
        );

        compareBytecode(
            "Factory SymbioticVerifier",
            address($.symbioticVerifierFactory),
            address(
                new TransparentUpgradeableProxy(
                    address($.factoryImplementation),
                    $.proxyAdmin,
                    abi.encodeCall(IFactoryEntity.initialize, (abi.encode($.deployer)))
                )
            )
        );
        if (address($.symbioticVerifierFactory) != address(0)) {
            require(
                $.symbioticVerifierFactory.implementations() == 1,
                "Factory SymbioticVerifier: invalid implementations length"
            );
            require(
                $.symbioticVerifierFactory.implementationAt(0) == address($.symbioticVerifierImplementation),
                "Factory SymbioticVerifier: invalid implementation at 0"
            );
        }

        compareBytecode(
            "Factory EigenLayerVerifier",
            address($.eigenLayerVerifierFactory),
            address(
                new TransparentUpgradeableProxy(
                    address($.factoryImplementation),
                    $.proxyAdmin,
                    abi.encodeCall(IFactoryEntity.initialize, (abi.encode($.deployer)))
                )
            )
        );
        if (address($.eigenLayerVerifierFactory) != address(0)) {
            require(
                $.eigenLayerVerifierFactory.implementations() == 1,
                "Factory EigenLayerVerifier: invalid implementations length"
            );
            require(
                $.eigenLayerVerifierFactory.implementationAt(0) == address($.eigenLayerVerifierImplementation),
                "Factory EigenLayerVerifier: invalid implementation at 0"
            );
        }

        compareBytecode(
            "Factory RiskManager",
            address($.riskManagerFactory),
            address(
                new TransparentUpgradeableProxy(
                    address($.factoryImplementation),
                    $.proxyAdmin,
                    abi.encodeCall(IFactoryEntity.initialize, (abi.encode($.deployer)))
                )
            )
        );
        require($.riskManagerFactory.implementations() == 1, "Factory RiskManager: invalid implementations length");
        require(
            $.riskManagerFactory.implementationAt(0) == address($.riskManagerImplementation),
            "Factory RiskManager: invalid implementation at 0"
        );

        compareBytecode(
            "Factory Subvault",
            address($.subvaultFactory),
            address(
                new TransparentUpgradeableProxy(
                    address($.factoryImplementation),
                    $.proxyAdmin,
                    abi.encodeCall(IFactoryEntity.initialize, (abi.encode($.deployer)))
                )
            )
        );
        require($.subvaultFactory.implementations() == 1, "Factory Subvault: invalid implementations length");
        require(
            $.subvaultFactory.implementationAt(0) == address($.subvaultImplementation),
            "Factory Subvault: invalid implementation at 0"
        );

        compareBytecode(
            "Factory Verifier",
            address($.verifierFactory),
            address(
                new TransparentUpgradeableProxy(
                    address($.factoryImplementation),
                    $.proxyAdmin,
                    abi.encodeCall(IFactoryEntity.initialize, (abi.encode($.deployer)))
                )
            )
        );
        require($.verifierFactory.implementations() == 1, "Factory Verifier: invalid implementations length");
        require(
            $.verifierFactory.implementationAt(0) == address($.verifierImplementation),
            "Factory Verifier: invalid implementation at 0"
        );

        compareBytecode(
            "Factory Vault",
            address($.vaultFactory),
            address(
                new TransparentUpgradeableProxy(
                    address($.factoryImplementation),
                    $.proxyAdmin,
                    abi.encodeCall(IFactoryEntity.initialize, (abi.encode($.deployer)))
                )
            )
        );
        require($.vaultFactory.implementations() == 1, "Factory Vault: invalid implementations length");
        require(
            $.vaultFactory.implementationAt(0) == address($.vaultImplementation),
            "Factory Vault: invalid implementation at 0"
        );

        compareBytecode(
            "Factory ShareManager",
            address($.shareManagerFactory),
            address(
                new TransparentUpgradeableProxy(
                    address($.factoryImplementation),
                    $.proxyAdmin,
                    abi.encodeCall(IFactoryEntity.initialize, (abi.encode($.deployer)))
                )
            )
        );
        require($.shareManagerFactory.implementations() == 2, "Factory ShareManager: invalid implementations length");
        require(
            $.shareManagerFactory.implementationAt(0) == address($.tokenizedShareManagerImplementation),
            "Factory ShareManager: invalid implementation at 0"
        );
        require(
            $.shareManagerFactory.implementationAt(1) == address($.basicShareManagerImplementation),
            "Factory ShareManager: invalid implementation at 1"
        );

        compareBytecode(
            "Factory Consensus",
            address($.consensusFactory),
            address(
                new TransparentUpgradeableProxy(
                    address($.factoryImplementation),
                    $.proxyAdmin,
                    abi.encodeCall(IFactoryEntity.initialize, (abi.encode($.deployer)))
                )
            )
        );
        require($.consensusFactory.implementations() == 1, "Factory Consensus: invalid implementations length");
        require(
            $.consensusFactory.implementationAt(0) == address($.consensusImplementation),
            "Factory Consensus: invalid implementation at 0"
        );

        compareBytecode(
            "Factory DepositQueue",
            address($.depositQueueFactory),
            address(
                new TransparentUpgradeableProxy(
                    address($.factoryImplementation),
                    $.proxyAdmin,
                    abi.encodeCall(IFactoryEntity.initialize, (abi.encode($.deployer)))
                )
            )
        );

        if (block.chainid == 1) {
            require(
                $.depositQueueFactory.implementations() == 3, "Factory DepositQueue: invalid implementations length"
            );
            require(
                $.depositQueueFactory.implementationAt(0) == address($.depositQueueImplementation),
                "Factory DepositQueue: invalid implementation at 0"
            );
            require(
                $.depositQueueFactory.implementationAt(1) == address($.signatureDepositQueueImplementation),
                "Factory DepositQueue: invalid implementation at 1"
            );
            require(
                $.depositQueueFactory.implementationAt(2) == address($.syncDepositQueueImplementation),
                "Factory DepositQueue: invalid implementation at 2"
            );
        } else {
            require(
                $.depositQueueFactory.implementations() == 2, "Factory DepositQueue: invalid implementations length"
            );
            require(
                $.depositQueueFactory.implementationAt(0) == address($.depositQueueImplementation),
                "Factory DepositQueue: invalid implementation at 0"
            );
            require(
                $.depositQueueFactory.implementationAt(1) == address($.signatureDepositQueueImplementation),
                "Factory DepositQueue: invalid implementation at 1"
            );
        }

        compareBytecode(
            "Factory RedeemQueue",
            address($.redeemQueueFactory),
            address(
                new TransparentUpgradeableProxy(
                    address($.factoryImplementation),
                    $.proxyAdmin,
                    abi.encodeCall(IFactoryEntity.initialize, (abi.encode($.deployer)))
                )
            )
        );
        if (block.chainid == 1) {
            require($.redeemQueueFactory.implementations() == 3, "Factory RedeemQueue: invalid implementations length");
            require(
                $.redeemQueueFactory.isBlacklisted(0) == true, "Factory RedeemQueue: implementation at 0 is blacklisted"
            );
            require(
                $.redeemQueueFactory.implementationAt(1) == address($.signatureRedeemQueueImplementation),
                "Factory RedeemQueue: invalid implementation at 1"
            );
            require(
                $.redeemQueueFactory.implementationAt(2) == address($.redeemQueueImplementation),
                "Factory RedeemQueue: invalid implementation at 1"
            );
        } else {
            require(
                $.redeemQueueFactory.implementationAt(0) == address($.redeemQueueImplementation),
                "Factory RedeemQueue: invalid implementation at 0"
            );
            if (block.chainid != 9745) {
                require(
                    $.redeemQueueFactory.implementations() == 2, "Factory RedeemQueue: invalid implementations length"
                );
                require(
                    $.redeemQueueFactory.implementationAt(1) == address($.signatureRedeemQueueImplementation),
                    "Factory RedeemQueue: invalid implementation at 1"
                );
            }
        }

        compareBytecode(
            "Factory FeeManager",
            address($.feeManagerFactory),
            address(
                new TransparentUpgradeableProxy(
                    address($.factoryImplementation),
                    $.proxyAdmin,
                    abi.encodeCall(IFactoryEntity.initialize, (abi.encode($.deployer)))
                )
            )
        );
        require($.feeManagerFactory.implementations() == 1, "Factory FeeManager: invalid implementations length");
        require(
            $.feeManagerFactory.implementationAt(0) == address($.feeManagerImplementation),
            "Factory FeeManager: invalid implementation at 0"
        );

        compareBytecode(
            "Factory Oracle",
            address($.oracleFactory),
            address(
                new TransparentUpgradeableProxy(
                    address($.factoryImplementation),
                    $.proxyAdmin,
                    abi.encodeCall(IFactoryEntity.initialize, (abi.encode($.deployer)))
                )
            )
        );
        require($.oracleFactory.implementations() == 1, "Factory Oracle: invalid implementations length");
        require(
            $.oracleFactory.implementationAt(0) == address($.oracleImplementation),
            "Factory Oracle: invalid implementation at 0"
        );

        require($.factory.isEntity(address($.depositQueueFactory)), "DepositQueueFactory is not Factory Factoy entity");
        require($.factory.isEntity(address($.redeemQueueFactory)), "RedeemQueueFactory is not Factory Factoy entity");
        require(
            $.factory.isEntity(address($.erc20VerifierFactory)), "ERC20VerifierFactory is not Factory Factoy entity"
        );
        if (address($.symbioticVerifierFactory) != address(0)) {
            require(
                $.factory.isEntity(address($.symbioticVerifierFactory)),
                "SymbioticVerifierFactory is not Factory Factoy entity"
            );
        }

        if (address($.eigenLayerVerifierFactory) != address(0)) {
            require(
                $.factory.isEntity(address($.eigenLayerVerifierFactory)),
                "EigenLayerVerifierFactory is not Factory Factoy entity"
            );
        }
        require($.factory.isEntity(address($.riskManagerFactory)), "RiskManagerFactory is not Factory Factoy entity");
        require($.factory.isEntity(address($.subvaultFactory)), "SubvaultFactory is not Factory Factoy entity");
        require($.factory.isEntity(address($.verifierFactory)), "VerifierFactory is not Factory Factoy entity");
        require($.factory.isEntity(address($.vaultFactory)), "VaultFactory is not Factory Factoy entity");
        require($.factory.isEntity(address($.shareManagerFactory)), "ShareManagerFactory is not Factory Factoy entity");
        require($.factory.isEntity(address($.consensusFactory)), "ConsensusFactory is not Factory Factoy entity");
        require($.factory.isEntity(address($.feeManagerFactory)), "FeeManagerFactory is not Factory Factoy entity");
        require($.factory.isEntity(address($.oracleFactory)), "OracleFactory is not Factory Factoy entity");
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
            (
                address initialOwner,
                address feeRecipient,
                uint24 depositFee,
                uint24 redeemFee,
                uint24 performanceFee,
                uint24 protocolFee
            ) = abi.decode(deployment.initParams.feeManagerParams, (address, address, uint24, uint24, uint24, uint24));
            require(feeManager.depositFeeD6() == depositFee, "FeeManager: invalid deposit fee");
            require(feeManager.redeemFeeD6() == redeemFee, "FeeManager: invalid redeem fee");
            require(feeManager.performanceFeeD6() == performanceFee, "FeeManager: invalid performance fee");
            require(feeManager.protocolFeeD6() == protocolFee, "FeeManager: invalid protocol fee");
            require(
                Ownable(address(feeManager)).owner() == deployment.initParams.vaultAdmin
                    || Ownable(address(feeManager)).owner() == feeRecipient,
                "FeeManager: invalid owner"
            );
            require(
                initialOwner == $.deployer || initialOwner == deployment.initParams.vaultAdmin,
                "FeeManager: invalid initial owner"
            );
            require(feeManager.feeRecipient() == feeRecipient, "FeeManager: inalid initial fee recipient");
            require(
                feeManager.baseAsset(address(vault)) == address(0)
                    || vault.hasAsset(feeManager.baseAsset(address(vault))),
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

    function _checkFactoryEntity(Factory factory, address entity, string memory name, address expectedOwner)
        internal
        view
    {
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
