// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../Imports.sol";

abstract contract BaseIntegrationTest is Test {
    string public constant DEPLOYMENT_NAME = "BaseIntegrationTest";
    uint256 public constant DEPLOYMENT_VERSION = 1;

    struct Deployment {
        address deployer;
        address vaultProxyAdmin;
        Vm.Wallet vaultAdminWallet;
        address vaultAdmin;
        address user;
        address protocolTreasury;
        Factory baseFactory;
        Factory depositQueueFactory;
        Factory feeManagerFactory;
        Factory oracleFactory;
        Factory redeemQueueFactory;
        Factory riskManagerFactory;
        Factory shareManagerFactory;
        Factory subvaultFactory;
        Factory vaultFactory;
        Factory verifierFactory;
        VaultConfigurator vaultConfigurator;
    }

    function deployBase() public returns (Deployment memory $) {
        $.deployer = vm.createWallet("BaseIntegrationTest:Deployment:deployer").addr;
        $.vaultProxyAdmin = vm.createWallet("BaseIntegrationTest:Deployment:vaultProxyAdmin").addr;
        $.vaultAdminWallet = vm.createWallet("BaseIntegrationTest:Deployment:vaultAdminWallet");
        $.vaultAdmin = $.vaultAdminWallet.addr;
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
            $.depositQueueFactory = Factory($.baseFactory.create(0, $.vaultProxyAdmin, abi.encode($.deployer)));
            address depositQueueImplementation = address(new DepositQueue(DEPLOYMENT_NAME, DEPLOYMENT_VERSION));
            $.depositQueueFactory.proposeImplementation(depositQueueImplementation);
            $.depositQueueFactory.acceptProposedImplementation(depositQueueImplementation);
            address signatureDepositQueueImplementation =
                address(new SignatureDepositQueue(DEPLOYMENT_NAME, DEPLOYMENT_VERSION));
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
                address(new SignatureRedeemQueue(DEPLOYMENT_NAME, DEPLOYMENT_VERSION));
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

        $.vaultConfigurator = new VaultConfigurator(
            address($.shareManagerFactory),
            address($.feeManagerFactory),
            address($.riskManagerFactory),
            address($.oracleFactory),
            address($.vaultFactory)
        );

        vm.stopPrank();
    }

    function test() external {}
}
