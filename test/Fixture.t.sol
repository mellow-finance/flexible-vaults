// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./Imports.sol";

abstract contract FixtureTest is Test {
    struct Deployment {
        Vault vault;
        address vaultAdmin;
        address vaultProxyAdmin;
        ShareManager shareManager;
        FeeManager feeManager;
        RiskManager riskManager;
        Oracle oracle;
        Consensus consensus;
        Factory riskManagerFactory;
        Factory subvaultFactory;
        Factory depositQueueFactory;
        Factory redeemQueueFactory;
        Factory verifierFactory;
        Factory factoryImplementation;
        Vault vaultImplementation;
        ShareManager shareManagerImplementation;
        FeeManager feeManagerImplementation;
        Oracle oracleImplementation;
        Consensus consensusImplementation;
        address[] assets;
        Verifier verifier;
    }

    function test() external {}

    function createShareManager(Deployment memory deployment)
        internal
        virtual
        returns (ShareManager shareManager, ShareManager shareManagerImplementation)
    {
        shareManagerImplementation = new TokenizedShareManager("Mellow", 1);
        shareManager = TokenizedShareManager(
            address(
                new TransparentUpgradeableProxy(
                    address(shareManagerImplementation), deployment.vaultProxyAdmin, new bytes(0)
                )
            )
        );
        vm.startPrank(deployment.vaultAdmin);
        {
            shareManager.initialize(abi.encode(bytes32(0), string("VaultERC20Name"), string("VaultERC20Symbol")));
            shareManager.setVault(address(deployment.vault));
        }
        vm.stopPrank();
    }

    function createConsensus(Deployment memory deployment, address[] memory signers)
        internal
        virtual
        returns (Consensus consensus, Consensus consensusImplementation)
    {
        consensusImplementation = new Consensus("Consensus", 1);
        consensus = Consensus(
            SignatureDepositQueue(deployment.depositQueueFactory.implementationAt(1)).consensusFactory().create(
                0, deployment.vaultProxyAdmin, abi.encode(deployment.vaultAdmin)
            )
        );
        vm.startPrank(deployment.vaultAdmin);
        for (uint256 i = 0; i < signers.length; i++) {
            consensus.addSigner(signers[i], 1, IConsensus.SignatureType.EIP712);
        }
        vm.stopPrank();
    }

    function defaultSecurityParams() internal pure virtual returns (IOracle.SecurityParams memory securityParams) {
        return IOracle.SecurityParams({
            maxAbsoluteDeviation: 0.05 ether,
            suspiciousAbsoluteDeviation: 0.01 ether,
            maxRelativeDeviationD18: 0.05 ether,
            suspiciousRelativeDeviationD18: 0.01 ether,
            timeout: 12 hours,
            depositInterval: 1 hours,
            redeemInterval: 1 hours
        });
    }

    function defaultFeeManagerParams(Deployment memory deployment) internal pure virtual returns (bytes memory) {
        return abi.encode(
            deployment.vaultAdmin, // owner
            deployment.vaultAdmin, // feeRecipient
            0, // depositFeeD6
            1e4, // redeemFeeD6
            0, // performanceFeeD6
            1e4 // protocolFeeD6
        );
    }

    function addDepositQueue(Deployment memory deployment, address owner, address asset) internal returns (address) {
        vm.startPrank(deployment.vaultAdmin);
        deployment.vault.setQueueLimit(deployment.vault.queueLimit() + 1);
        deployment.vault.createQueue(0, true, owner, asset, new bytes(0));
        vm.stopPrank();

        uint256 index = deployment.vault.getQueueCount(asset);
        return deployment.vault.queueAt(asset, index - 1);
    }

    function addSignatureDepositQueue(Deployment memory deployment, address owner, address asset, address consensus)
        internal
        returns (address)
    {
        vm.startPrank(deployment.vaultAdmin);
        deployment.vault.setQueueLimit(deployment.vault.queueLimit() + 1);
        deployment.vault.createQueue(1, true, owner, asset, abi.encode(address(consensus), "MockSignatureQueue", "0"));
        vm.stopPrank();

        uint256 index = deployment.vault.getQueueCount(asset);
        return deployment.vault.queueAt(asset, index - 1);
    }

    function addRedeemQueue(Deployment memory deployment, address owner, address asset) internal returns (address) {
        vm.startPrank(deployment.vaultAdmin);
        deployment.vault.setQueueLimit(deployment.vault.queueLimit() + 1);
        deployment.vault.createQueue(2, false, owner, asset, new bytes(0));
        vm.stopPrank();

        uint256 index = deployment.vault.getQueueCount(asset);
        return deployment.vault.queueAt(asset, index - 1);
    }

    function addSignatureRedeemQueue(Deployment memory deployment, address owner, address asset, address consensus)
        internal
        returns (address)
    {
        vm.startPrank(deployment.vaultAdmin);
        deployment.vault.setQueueLimit(deployment.vault.queueLimit() + 1);
        deployment.vault.createQueue(1, false, owner, asset, abi.encode(address(consensus), "MockSignatureQueue", "0"));
        vm.stopPrank();

        uint256 index = deployment.vault.getQueueCount(asset);
        return deployment.vault.queueAt(asset, index - 1);
    }

    function createVault(address vaultAdmin, address vaultProxyAdmin, address[] memory assets)
        internal
        returns (Deployment memory deployment)
    {
        deployment.vaultAdmin = vaultAdmin;
        deployment.vaultProxyAdmin = vaultProxyAdmin;
        deployment.assets = assets;

        deployment.factoryImplementation = new Factory("Mellow", 1);

        deployment.verifierFactory = Factory(
            address(
                new TransparentUpgradeableProxy(
                    address(deployment.factoryImplementation), deployment.vaultProxyAdmin, new bytes(0)
                )
            )
        );
        deployment.verifierFactory.initialize(abi.encode(deployment.vaultAdmin));

        deployment.subvaultFactory = Factory(
            address(
                new TransparentUpgradeableProxy(
                    address(deployment.factoryImplementation), deployment.vaultProxyAdmin, new bytes(0)
                )
            )
        );
        deployment.subvaultFactory.initialize(abi.encode(deployment.vaultAdmin));

        deployment.depositQueueFactory = Factory(
            address(
                new TransparentUpgradeableProxy(
                    address(deployment.factoryImplementation), deployment.vaultProxyAdmin, new bytes(0)
                )
            )
        );
        deployment.depositQueueFactory.initialize(abi.encode(deployment.vaultAdmin));

        deployment.redeemQueueFactory = Factory(
            address(
                new TransparentUpgradeableProxy(
                    address(deployment.factoryImplementation), deployment.vaultProxyAdmin, new bytes(0)
                )
            )
        );
        deployment.redeemQueueFactory.initialize(abi.encode(deployment.vaultAdmin));

        deployment.riskManagerFactory = Factory(
            address(
                new TransparentUpgradeableProxy(
                    address(deployment.factoryImplementation), deployment.vaultProxyAdmin, new bytes(0)
                )
            )
        );
        deployment.riskManagerFactory.initialize(abi.encode(deployment.vaultAdmin));

        vm.startPrank(deployment.vaultAdmin);
        {
            address depositQueueImplementation = address(new DepositQueue("Mellow", 1));
            deployment.depositQueueFactory.proposeImplementation(depositQueueImplementation);
            deployment.depositQueueFactory.acceptProposedImplementation(depositQueueImplementation);

            Factory consensusFactory = Factory(
                address(
                    new TransparentUpgradeableProxy(
                        address(new Factory("Mellow", 1)),
                        address(0xdead),
                        abi.encodeCall(IFactoryEntity.initialize, (abi.encode(deployment.vaultAdmin)))
                    )
                )
            );
            {
                address implementation = address(new Consensus("Mellow", 1));
                consensusFactory.proposeImplementation(implementation);
                consensusFactory.acceptProposedImplementation(implementation);
                consensusFactory.transferOwnership(deployment.vaultProxyAdmin);
            }
            address signatureDepositQueueImplementation =
                address(new SignatureDepositQueue("Mellow", 1, address(consensusFactory)));
            deployment.depositQueueFactory.proposeImplementation(signatureDepositQueueImplementation);
            deployment.depositQueueFactory.acceptProposedImplementation(signatureDepositQueueImplementation);

            address redeemQueueImplementation = address(new RedeemQueue("Mellow", 1));
            deployment.redeemQueueFactory.proposeImplementation(redeemQueueImplementation);
            deployment.redeemQueueFactory.acceptProposedImplementation(redeemQueueImplementation);
            address signatureRedeemQueueImplementation =
                address(new SignatureRedeemQueue("Mellow", 1, address(consensusFactory)));
            deployment.redeemQueueFactory.proposeImplementation(signatureRedeemQueueImplementation);
            deployment.redeemQueueFactory.acceptProposedImplementation(signatureRedeemQueueImplementation);

            address verifierImplementation = address(new Verifier("Mellow", 1));
            deployment.verifierFactory.proposeImplementation(verifierImplementation);
            deployment.verifierFactory.acceptProposedImplementation(verifierImplementation);

            address subvaultImplementation = address(new Subvault("Mellow", 1));
            deployment.subvaultFactory.proposeImplementation(subvaultImplementation);
            deployment.subvaultFactory.acceptProposedImplementation(subvaultImplementation);

            address riskManagerImplementation = address(new RiskManager("Mellow", 1));
            deployment.riskManagerFactory.proposeImplementation(riskManagerImplementation);
            deployment.riskManagerFactory.acceptProposedImplementation(riskManagerImplementation);
        }

        vm.stopPrank();
        deployment.vaultImplementation = new Vault(
            "Mellow",
            1,
            address(deployment.depositQueueFactory),
            address(deployment.redeemQueueFactory),
            address(deployment.subvaultFactory),
            address(deployment.verifierFactory)
        );

        deployment.vault = Vault(
            payable(
                new TransparentUpgradeableProxy(
                    address(deployment.vaultImplementation), deployment.vaultProxyAdmin, new bytes(0)
                )
            )
        );

        (deployment.shareManager, deployment.shareManagerImplementation) = createShareManager(deployment);

        deployment.feeManagerImplementation = new FeeManager("Mellow", 1);

        deployment.feeManager = FeeManager(
            address(
                new TransparentUpgradeableProxy(
                    address(deployment.feeManagerImplementation), deployment.vaultProxyAdmin, new bytes(0)
                )
            )
        );
        deployment.feeManager.initialize(defaultFeeManagerParams(deployment));

        deployment.oracleImplementation = new Oracle("Mellow", 1);

        deployment.oracle = Oracle(
            address(
                new TransparentUpgradeableProxy(
                    address(deployment.oracleImplementation), deployment.vaultProxyAdmin, new bytes(0)
                )
            )
        );

        {
            bytes memory oracleInitParams = abi.encode(defaultSecurityParams(), assets);
            deployment.oracle.initialize(oracleInitParams);
            deployment.oracle.setVault(address(deployment.vault));
        }

        deployment.riskManager = RiskManager(
            deployment.riskManagerFactory.create(0, deployment.vaultProxyAdmin, abi.encode(int256(100 ether)))
        );
        deployment.riskManager.setVault(address(deployment.vault));
        address depositHook = address(new RedirectingDepositHook());
        address redeemHook = address(new BasicRedeemHook());

        deployment.vault.initialize(
            abi.encode(
                deployment.vaultAdmin,
                address(deployment.shareManager),
                address(deployment.feeManager),
                address(deployment.riskManager),
                address(deployment.oracle),
                depositHook,
                redeemHook,
                0,
                new Vault.RoleHolder[](0)
            )
        );

        deployment.verifier = Verifier(
            deployment.verifierFactory.create(
                0, deployment.vaultProxyAdmin, abi.encode(address(deployment.vault), bytes32(0))
            )
        );
        vm.startPrank(deployment.vaultAdmin);
        grantRoles(deployment);
        vm.stopPrank();
    }

    function grantRoles(Deployment memory deployment) internal {
        bytes32[26] memory roles = [
            deployment.vault.SET_HOOK_ROLE(),
            deployment.vault.CREATE_QUEUE_ROLE(),
            deployment.vault.SET_QUEUE_LIMIT_ROLE(),
            deployment.vault.CREATE_SUBVAULT_ROLE(),
            deployment.vault.DISCONNECT_SUBVAULT_ROLE(),
            deployment.vault.RECONNECT_SUBVAULT_ROLE(),
            deployment.vault.PULL_LIQUIDITY_ROLE(),
            deployment.vault.PUSH_LIQUIDITY_ROLE(),
            deployment.oracle.SUBMIT_REPORTS_ROLE(),
            deployment.oracle.ACCEPT_REPORT_ROLE(),
            deployment.oracle.SET_SECURITY_PARAMS_ROLE(),
            deployment.oracle.ADD_SUPPORTED_ASSETS_ROLE(),
            deployment.oracle.REMOVE_SUPPORTED_ASSETS_ROLE(),
            deployment.verifier.SET_MERKLE_ROOT_ROLE(),
            deployment.verifier.CALLER_ROLE(),
            deployment.verifier.ALLOW_CALL_ROLE(),
            deployment.verifier.DISALLOW_CALL_ROLE(),
            deployment.shareManager.SET_FLAGS_ROLE(),
            deployment.shareManager.SET_ACCOUNT_INFO_ROLE(),
            deployment.riskManager.SET_VAULT_LIMIT_ROLE(),
            deployment.riskManager.SET_SUBVAULT_LIMIT_ROLE(),
            deployment.riskManager.MODIFY_PENDING_ASSETS_ROLE(),
            deployment.riskManager.MODIFY_VAULT_BALANCE_ROLE(),
            deployment.riskManager.MODIFY_SUBVAULT_BALANCE_ROLE(),
            deployment.riskManager.ALLOW_SUBVAULT_ASSETS_ROLE(),
            deployment.riskManager.DISALLOW_SUBVAULT_ASSETS_ROLE()
        ];
        vm.startPrank(deployment.vaultAdmin);
        for (uint256 i = 0; i < roles.length; i++) {
            deployment.vault.grantRole(roles[i], deployment.vaultAdmin);
        }
    }
}
