// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../test/Imports.sol";
import "forge-std/Script.sol";

contract Deploy is Script {
    string public constant DEPLOYMENT_NAME = "Mellow";
    uint256 public constant DEPLOYMENT_VERSION = 1;

    struct Deployment {
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
        BitmaskVerifier bitmaskVerifier;
        VaultConfigurator vaultConfigurator;
    }

    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);

        vm.startBroadcast(deployerPk);
        Deployment memory deployment = deployBase(deployer);

        console2.log("Factory:", address(deployment.baseFactory));
        console2.log("DepositQueue Factory:", address(deployment.depositQueueFactory));
        console2.log("FeeManager Factory:", address(deployment.feeManagerFactory));
        console2.log("Oracle Factory:", address(deployment.oracleFactory));
        console2.log("RedeemQueue Factory:", address(deployment.redeemQueueFactory));
        console2.log("RiskManager Factory:", address(deployment.riskManagerFactory));
        console2.log("ShareManager Factory:", address(deployment.shareManagerFactory));
        console2.log("Subvault Factory:", address(deployment.subvaultFactory));
        console2.log("Vault Factory:", address(deployment.vaultFactory));
        console2.log("Verifier Factory:", address(deployment.verifierFactory));
        console2.log("BitmaskVerifier:", address(deployment.bitmaskVerifier));
        console2.log("VaultConfigurator:", address(deployment.vaultConfigurator));

        vm.stopBroadcast();
        // revert("ok");
    }

    function deployBase(address deployer) public returns (Deployment memory $) {
        Factory factoryImplementation = new Factory(DEPLOYMENT_NAME, DEPLOYMENT_VERSION);
        $.baseFactory = Factory(
            address(
                new TransparentUpgradeableProxy(
                    address(factoryImplementation),
                    deployer,
                    abi.encodeCall(IFactoryEntity.initialize, (abi.encode(deployer)))
                )
            )
        );

        {
            $.baseFactory.proposeImplementation(address(factoryImplementation));
            $.baseFactory.acceptProposedImplementation(address(factoryImplementation));
        }

        {
            $.depositQueueFactory = Factory($.baseFactory.create(0, deployer, abi.encode(deployer)));
            address depositQueueImplementation = address(new DepositQueue(DEPLOYMENT_NAME, DEPLOYMENT_VERSION));
            $.depositQueueFactory.proposeImplementation(depositQueueImplementation);
            $.depositQueueFactory.acceptProposedImplementation(depositQueueImplementation);
        }

        {
            $.feeManagerFactory = Factory($.baseFactory.create(0, deployer, abi.encode(deployer)));
            address implementation = address(new FeeManager(DEPLOYMENT_NAME, DEPLOYMENT_VERSION));
            $.feeManagerFactory.proposeImplementation(implementation);
            $.feeManagerFactory.acceptProposedImplementation(implementation);
        }

        {
            $.oracleFactory = Factory($.baseFactory.create(0, deployer, abi.encode(deployer)));
            address implementation = address(new Oracle(DEPLOYMENT_NAME, DEPLOYMENT_VERSION));
            $.oracleFactory.proposeImplementation(implementation);
            $.oracleFactory.acceptProposedImplementation(implementation);
        }

        {
            $.redeemQueueFactory = Factory($.baseFactory.create(0, deployer, abi.encode(deployer)));
            address redeemQueueImplementation = address(new RedeemQueue(DEPLOYMENT_NAME, DEPLOYMENT_VERSION));
            $.redeemQueueFactory.proposeImplementation(redeemQueueImplementation);
            $.redeemQueueFactory.acceptProposedImplementation(redeemQueueImplementation);
        }

        {
            $.riskManagerFactory = Factory($.baseFactory.create(0, deployer, abi.encode(deployer)));
            address implementation = address(new RiskManager(DEPLOYMENT_NAME, DEPLOYMENT_VERSION));
            $.riskManagerFactory.proposeImplementation(implementation);
            $.riskManagerFactory.acceptProposedImplementation(implementation);
        }

        {
            $.shareManagerFactory = Factory($.baseFactory.create(0, deployer, abi.encode(deployer)));
            address tokenizedImplementation = address(new TokenizedShareManager(DEPLOYMENT_NAME, DEPLOYMENT_VERSION));
            $.shareManagerFactory.proposeImplementation(tokenizedImplementation);
            $.shareManagerFactory.acceptProposedImplementation(tokenizedImplementation);
        }

        {
            $.subvaultFactory = Factory($.baseFactory.create(0, deployer, abi.encode(deployer)));
            address implementation = address(new Subvault(DEPLOYMENT_NAME, DEPLOYMENT_VERSION));
            $.subvaultFactory.proposeImplementation(implementation);
            $.subvaultFactory.acceptProposedImplementation(implementation);
        }

        {
            $.verifierFactory = Factory($.baseFactory.create(0, deployer, abi.encode(deployer)));
            address implementation = address(new Verifier(DEPLOYMENT_NAME, DEPLOYMENT_VERSION));
            $.verifierFactory.proposeImplementation(implementation);
            $.verifierFactory.acceptProposedImplementation(implementation);
        }

        {
            $.vaultFactory = Factory($.baseFactory.create(0, deployer, abi.encode(deployer)));
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
        }

        $.bitmaskVerifier = new BitmaskVerifier();

        $.vaultConfigurator = new VaultConfigurator(
            address($.shareManagerFactory),
            address($.feeManagerFactory),
            address($.riskManagerFactory),
            address($.oracleFactory),
            address($.vaultFactory)
        );
    }
}
