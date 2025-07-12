// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../Imports.sol";

abstract contract BaseIntegrationTest is Test {
    string public constant DEPLOYMENT_NAME = "BaseIntegrationTest";
    uint256 public constant DEPLOYMENT_VERSION = 1;

    address public constant SYMBIOTIC_VAULT_FACTORY = 0xAEb6bdd95c502390db8f52c8909F703E9Af6a346;
    address public constant SYMBIOTIC_FARM_FACTORY = 0xFEB871581C2ab2e1EEe6f7dDC7e6246cFa087A23;

    address public constant EIGEN_LAYER_DELEGATION_MANAGER = 0x39053D51B77DC0d36036Fc1fCc8Cb819df8Ef37A;
    address public constant EIGEN_LAYER_STRATEGY_MANAGER = 0x858646372CC42E1A627fcE94aa7A7033e7CF075A;
    address public constant EIGEN_LAYER_REWARDS_COORDINATOR = 0x7750d328b314EfFa365A0402CcfD489B80B0adda;

    struct Deployment {
        address deployer;
        address vaultProxyAdmin;
        Vm.Wallet vaultAdminWallet;
        address vaultAdmin;
        address curator;
        address user;
        address protocolTreasury;
        Factory baseFactory;
        Factory consensusFactory;
        Factory depositQueueFactory;
        Factory feeManagerFactory;
        Factory oracleFactory;
        Factory redeemQueueFactory;
        Factory riskManagerFactory;
        Factory shareManagerFactory;
        Factory subvaultFactory;
        Factory vaultFactory;
        Factory verifierFactory;
        Factory protocolVerifierFactory;
        VaultConfigurator vaultConfigurator;
    }

    function deployBase() public returns (Deployment memory $) {
        $.deployer = vm.createWallet("BaseIntegrationTest:Deployment:deployer").addr;
        $.vaultProxyAdmin = vm.createWallet("BaseIntegrationTest:Deployment:vaultProxyAdmin").addr;
        $.vaultAdminWallet = vm.createWallet("BaseIntegrationTest:Deployment:vaultAdminWallet");
        $.vaultAdmin = $.vaultAdminWallet.addr;
        $.curator = vm.createWallet("BaseIntegrationTest:Deployment:curator").addr;
        $.user = vm.createWallet("BaseIntegrationTest:Deployment:user").addr;
        $.protocolTreasury = vm.createWallet("BaseIntegrationTest:Deployment:protocolTreasury").addr;
        Factory factoryImplementation = new Factory(DEPLOYMENT_NAME, DEPLOYMENT_VERSION);
        $.baseFactory = Factory(
            address(
                new TransparentUpgradeableProxy(
                    address(factoryImplementation),
                    $.vaultProxyAdmin,
                    abi.encodeCall(IFactoryEntity.initialize, (abi.encode($.deployer)))
                )
            )
        );

        vm.startPrank($.deployer);
        {
            $.baseFactory.proposeImplementation(address(factoryImplementation));
            $.baseFactory.acceptProposedImplementation(address(factoryImplementation));
            $.baseFactory.transferOwnership($.vaultProxyAdmin);
        }

        {
            $.consensusFactory = Factory($.baseFactory.create(0, $.vaultProxyAdmin, abi.encode($.deployer)));
            address implementation = address(new Consensus(DEPLOYMENT_NAME, DEPLOYMENT_VERSION));
            $.consensusFactory.proposeImplementation(implementation);
            $.consensusFactory.acceptProposedImplementation(implementation);
            $.consensusFactory.transferOwnership($.vaultProxyAdmin);
        }

        {
            $.depositQueueFactory = Factory($.baseFactory.create(0, $.vaultProxyAdmin, abi.encode($.deployer)));
            address depositQueueImplementation = address(new DepositQueue(DEPLOYMENT_NAME, DEPLOYMENT_VERSION));
            $.depositQueueFactory.proposeImplementation(depositQueueImplementation);
            $.depositQueueFactory.acceptProposedImplementation(depositQueueImplementation);
            address signatureDepositQueueImplementation =
                address(new SignatureDepositQueue(DEPLOYMENT_NAME, DEPLOYMENT_VERSION, address($.consensusFactory)));
            $.depositQueueFactory.proposeImplementation(signatureDepositQueueImplementation);
            $.depositQueueFactory.acceptProposedImplementation(signatureDepositQueueImplementation);
            $.depositQueueFactory.transferOwnership($.vaultProxyAdmin);
        }

        {
            $.feeManagerFactory = Factory($.baseFactory.create(0, $.vaultProxyAdmin, abi.encode($.deployer)));
            address implementation = address(new FeeManager(DEPLOYMENT_NAME, DEPLOYMENT_VERSION));
            $.feeManagerFactory.proposeImplementation(implementation);
            $.feeManagerFactory.acceptProposedImplementation(implementation);
            $.feeManagerFactory.transferOwnership($.vaultProxyAdmin);
        }

        {
            $.oracleFactory = Factory($.baseFactory.create(0, $.vaultProxyAdmin, abi.encode($.deployer)));
            address implementation = address(new Oracle(DEPLOYMENT_NAME, DEPLOYMENT_VERSION));
            $.oracleFactory.proposeImplementation(implementation);
            $.oracleFactory.acceptProposedImplementation(implementation);
            $.oracleFactory.transferOwnership($.vaultProxyAdmin);
        }

        {
            $.redeemQueueFactory = Factory($.baseFactory.create(0, $.vaultProxyAdmin, abi.encode($.deployer)));
            address redeemQueueImplementation = address(new RedeemQueue(DEPLOYMENT_NAME, DEPLOYMENT_VERSION));
            $.redeemQueueFactory.proposeImplementation(redeemQueueImplementation);
            $.redeemQueueFactory.acceptProposedImplementation(redeemQueueImplementation);
            address signatureRedeemQueueImplementation =
                address(new SignatureRedeemQueue(DEPLOYMENT_NAME, DEPLOYMENT_VERSION, address($.consensusFactory)));
            $.redeemQueueFactory.proposeImplementation(signatureRedeemQueueImplementation);
            $.redeemQueueFactory.acceptProposedImplementation(signatureRedeemQueueImplementation);
            $.redeemQueueFactory.transferOwnership($.vaultProxyAdmin);
        }

        {
            $.riskManagerFactory = Factory($.baseFactory.create(0, $.vaultProxyAdmin, abi.encode($.deployer)));
            address implementation = address(new RiskManager(DEPLOYMENT_NAME, DEPLOYMENT_VERSION));
            $.riskManagerFactory.proposeImplementation(implementation);
            $.riskManagerFactory.acceptProposedImplementation(implementation);
            $.riskManagerFactory.transferOwnership($.vaultProxyAdmin);
        }

        {
            $.shareManagerFactory = Factory($.baseFactory.create(0, $.vaultProxyAdmin, abi.encode($.deployer)));

            address tokenizedImplementation = address(new TokenizedShareManager(DEPLOYMENT_NAME, DEPLOYMENT_VERSION));
            $.shareManagerFactory.proposeImplementation(tokenizedImplementation);
            $.shareManagerFactory.acceptProposedImplementation(tokenizedImplementation);

            address basicImplementation = address(new BasicShareManager(DEPLOYMENT_NAME, DEPLOYMENT_VERSION));
            $.shareManagerFactory.proposeImplementation(basicImplementation);
            $.shareManagerFactory.acceptProposedImplementation(basicImplementation);

            $.shareManagerFactory.transferOwnership($.vaultProxyAdmin);
        }

        {
            $.subvaultFactory = Factory($.baseFactory.create(0, $.vaultProxyAdmin, abi.encode($.deployer)));
            address implementation = address(new Subvault(DEPLOYMENT_NAME, DEPLOYMENT_VERSION));
            $.subvaultFactory.proposeImplementation(implementation);
            $.subvaultFactory.acceptProposedImplementation(implementation);
            $.subvaultFactory.transferOwnership($.vaultProxyAdmin);
        }

        {
            $.verifierFactory = Factory($.baseFactory.create(0, $.vaultProxyAdmin, abi.encode($.deployer)));
            address implementation = address(new Verifier(DEPLOYMENT_NAME, DEPLOYMENT_VERSION));
            $.verifierFactory.proposeImplementation(implementation);
            $.verifierFactory.acceptProposedImplementation(implementation);
            $.verifierFactory.transferOwnership($.vaultProxyAdmin);
        }

        {
            $.vaultFactory = Factory($.baseFactory.create(0, $.vaultProxyAdmin, abi.encode($.deployer)));
            address implementation = address(
                new Vault(
                    DEPLOYMENT_NAME,
                    DEPLOYMENT_VERSION,
                    address($.depositQueueFactory),
                    address($.redeemQueueFactory),
                    address($.subvaultFactory),
                    address($.verifierFactory)
                )
            );
            $.vaultFactory.proposeImplementation(implementation);
            $.vaultFactory.acceptProposedImplementation(implementation);
            $.vaultFactory.transferOwnership($.vaultProxyAdmin);
        }

        {
            $.protocolVerifierFactory = Factory($.baseFactory.create(0, $.vaultProxyAdmin, abi.encode($.deployer)));
            address symbioticVerifierImplementation = address(
                new SymbioticVerifier(
                    SYMBIOTIC_VAULT_FACTORY, SYMBIOTIC_FARM_FACTORY, DEPLOYMENT_NAME, DEPLOYMENT_VERSION
                )
            );
            $.protocolVerifierFactory.proposeImplementation(symbioticVerifierImplementation);
            $.protocolVerifierFactory.acceptProposedImplementation(symbioticVerifierImplementation);

            address erc20VerifierImplementation = address(new ERC20Verifier(DEPLOYMENT_NAME, DEPLOYMENT_VERSION));
            $.protocolVerifierFactory.proposeImplementation(erc20VerifierImplementation);
            $.protocolVerifierFactory.acceptProposedImplementation(erc20VerifierImplementation);

            address eigenLayerVerifierImplementation = address(
                new EigenLayerVerifier(
                    EIGEN_LAYER_DELEGATION_MANAGER,
                    EIGEN_LAYER_STRATEGY_MANAGER,
                    EIGEN_LAYER_REWARDS_COORDINATOR,
                    DEPLOYMENT_NAME,
                    DEPLOYMENT_VERSION
                )
            );
            $.protocolVerifierFactory.proposeImplementation(eigenLayerVerifierImplementation);
            $.protocolVerifierFactory.acceptProposedImplementation(eigenLayerVerifierImplementation);

            $.protocolVerifierFactory.transferOwnership($.vaultProxyAdmin);
        }

        $.vaultConfigurator = new VaultConfigurator(
            address($.shareManagerFactory),
            address($.feeManagerFactory),
            address($.riskManagerFactory),
            address($.oracleFactory),
            address($.vaultFactory)
        );

        vm.stopPrank();
    }

    function generateMerkleProofs(IVerifier.VerificationPayload[] memory leaves)
        public
        pure
        returns (bytes32 root, IVerifier.VerificationPayload[] memory)
    {
        uint256 n = leaves.length;
        bytes32[] memory tree = new bytes32[](n * 2 - 1);
        bytes32[] memory cache = new bytes32[](n);
        bytes32[] memory sortedHashes = new bytes32[](n);

        for (uint256 i = 0; i < n; i++) {
            bytes32 leaf = keccak256(
                bytes.concat(keccak256(abi.encode(leaves[i].verificationType, keccak256(leaves[i].verificationData))))
            );
            cache[i] = leaf;
            sortedHashes[i] = leaf;
        }
        Arrays.sort(sortedHashes);
        for (uint256 i = 0; i < n; i++) {
            tree[tree.length - 1 - i] = sortedHashes[i];
        }
        for (uint256 i = n; i < 2 * n - 1; i++) {
            uint256 v = tree.length - 1 - i;
            uint256 l = v * 2 + 1;
            uint256 r = v * 2 + 2;
            tree[v] = Hashes.commutativeKeccak256(tree[l], tree[r]);
        }
        root = tree[0];
        for (uint256 i = 0; i < n; i++) {
            uint256 index;
            for (uint256 j = 0; j < n; j++) {
                if (cache[i] == sortedHashes[j]) {
                    index = j;
                    break;
                }
            }
            bytes32[] memory proof = new bytes32[](30);
            uint256 iterator = 0;
            uint256 treeIndex = tree.length - 1 - index;
            while (treeIndex > 0) {
                uint256 siblingIndex = treeIndex;
                if ((treeIndex % 2) == 0) {
                    siblingIndex -= 1;
                } else {
                    siblingIndex += 1;
                }
                proof[iterator++] = tree[siblingIndex];
                treeIndex = (treeIndex - 1) >> 1;
            }
            assembly {
                mstore(proof, iterator)
            }
            leaves[i].proof = proof;
            require(MerkleProof.verify(proof, root, cache[i]), "Invalid proof or tree");
        }
        return (root, leaves);
    }

    function test() private pure {}
}
