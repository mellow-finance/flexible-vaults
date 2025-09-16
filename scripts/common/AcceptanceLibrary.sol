// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {VmSafe} from "forge-std/Vm.sol";

import "./interfaces/Imports.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

library AcceptanceLibrary {
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
        bytes memory aBytecode = removeMetadata(a.code);
        bytes memory bBytecode = removeMetadata(b.code);
        if (keccak256(aBytecode) != keccak256(bBytecode)) {
            revert(string.concat(title, ": invalid bytecode"));
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

        compareBytecode(
            "LidoDepositHook",
            address($.lidoDepositHook),
            address(new LidoDepositHook($.wsteth, $.weth, address($.redirectingDepositHook)))
        );

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
        require(
            $.symbioticVerifierFactory.implementations() == 1,
            "Factory SymbioticVerifier: invalid implementations length"
        );
        require(
            $.symbioticVerifierFactory.implementationAt(0) == address($.symbioticVerifierImplementation),
            "Factory SymbioticVerifier: invalid implementation at 0"
        );

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
        require(
            $.eigenLayerVerifierFactory.implementations() == 1,
            "Factory EigenLayerVerifier: invalid implementations length"
        );
        require(
            $.eigenLayerVerifierFactory.implementationAt(0) == address($.eigenLayerVerifierImplementation),
            "Factory EigenLayerVerifier: invalid implementation at 0"
        );

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
        require($.depositQueueFactory.implementations() == 2, "Factory DepositQueue: invalid implementations length");
        require(
            $.depositQueueFactory.implementationAt(0) == address($.depositQueueImplementation),
            "Factory DepositQueue: invalid implementation at 0"
        );
        require(
            $.depositQueueFactory.implementationAt(1) == address($.signatureDepositQueueImplementation),
            "Factory DepositQueue: invalid implementation at 1"
        );

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
        require($.redeemQueueFactory.implementations() == 2, "Factory RedeemQueue: invalid implementations length");
        require(
            $.redeemQueueFactory.implementationAt(0) == address($.redeemQueueImplementation),
            "Factory RedeemQueue: invalid implementation at 0"
        );
        require(
            $.redeemQueueFactory.implementationAt(1) == address($.signatureRedeemQueueImplementation),
            "Factory RedeemQueue: invalid implementation at 1"
        );

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
        require(
            $.factory.isEntity(address($.symbioticVerifierFactory)),
            "SymbioticVerifierFactory is not Factory Factoy entity"
        );
        require(
            $.factory.isEntity(address($.eigenLayerVerifierFactory)),
            "EigenLayerVerifierFactory is not Factory Factoy entity"
        );
        require($.factory.isEntity(address($.riskManagerFactory)), "RiskManagerFactory is not Factory Factoy entity");
        require($.factory.isEntity(address($.subvaultFactory)), "SubvaultFactory is not Factory Factoy entity");
        require($.factory.isEntity(address($.verifierFactory)), "VerifierFactory is not Factory Factoy entity");
        require($.factory.isEntity(address($.vaultFactory)), "VaultFactory is not Factory Factoy entity");
        require($.factory.isEntity(address($.shareManagerFactory)), "ShareManagerFactory is not Factory Factoy entity");
        require($.factory.isEntity(address($.consensusFactory)), "ConsensusFactory is not Factory Factoy entity");
        require($.factory.isEntity(address($.feeManagerFactory)), "FeeManagerFactory is not Factory Factoy entity");
        require($.factory.isEntity(address($.oracleFactory)), "OracleFactory is not Factory Factoy entity");
    }

    function runVaultDeploymentChecks(ProtocolDeployment memory $, VaultDeployment memory deployment) internal view {
        require(address($.vaultConfigurator) != address(0), "VaultConfigurator: address zero");
        require(
            $.vaultConfigurator.vaultFactory().isEntity(address(deployment.vault)), "Vault: not a VaultFactory entity"
        );
        (address implementation, address owner) = getProxyInfo(address(deployment.vault));
        require(owner == deployment.initParams.proxyAdmin, "Vault: invalid proxyAdmin");
        require($.vaultFactory.implementationAt(0) == implementation, "Vault: invalid implementation");
        require(deployment.vault.subvaults() == deployment.calls.length, "Vault: invalid subvault count");

        for (uint256 i = 0; i < deployment.calls.length; i++) {
            Subvault subvault = Subvault(payable(deployment.vault.subvaultAt(i)));
            IVerifier verifier = subvault.verifier();
            for (uint256 j = 0; j < deployment.calls[i].payloads.length; j++) {
                Call[] memory calls = deployment.calls[i].calls[j];
                _verifyCalls(verifier, calls, deployment.calls[i].payloads[j]);
            }
        }

        // TODO
        // 1. permissions (OZ ACL)
        // 2. getters
        // 3. slots
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
                "Verifier: invalid verification result"
            );
        }
    }
}
