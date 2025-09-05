// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../test/Imports.sol";
import "forge-std/Script.sol";

import "@openzeppelin/contracts/utils/Create2.sol";

contract Deploy is Script {
    string public constant DEPLOYMENT_NAME = "Mellow";
    uint256 public constant DEPLOYMENT_VERSION = 1;

    struct Deployment {
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
        address bitmaskVerifier;
        address eigenLayerVerifier;
        address erc20Verifier;
        address symbioticVerifier;
        address vaultConfigurator;
        address basicRedeemHook;
        address redirectingDepositHook;
        address lidoDipositHook;
        address oracleHelper;
    }

    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);

        vm.startBroadcast(deployerPk);

        address proxyAdmin = 0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0;
        Deployment memory deployment = deployBase(deployer, proxyAdmin);

        console2.log("Factory: %s;", address(deployment.baseFactory));
        console2.log("Consensus Factory: %s;", address(deployment.consensusFactory));
        console2.log("DepositQueue Factory: %s;", address(deployment.depositQueueFactory));
        console2.log("FeeManager Factory: %s;", address(deployment.feeManagerFactory));
        console2.log("Oracle Factory: %s;", address(deployment.oracleFactory));
        console2.log("RedeemQueue Factory: %s;", address(deployment.redeemQueueFactory));
        console2.log("RiskManager Factory: %s;", address(deployment.riskManagerFactory));
        console2.log("ShareManager Factory: %s;", address(deployment.shareManagerFactory));
        console2.log("Subvault Factory: %s;", address(deployment.subvaultFactory));
        console2.log("Vault Factory: %s;", address(deployment.vaultFactory));
        console2.log("Verifier Factory: %s;", address(deployment.verifierFactory));
        console2.log("BitmaskVerifier: %s;", address(deployment.bitmaskVerifier));
        console2.log("EigenLayerVerifier: %s;", address(deployment.eigenLayerVerifier));
        console2.log("ERC20Verifier: %s;", address(deployment.erc20Verifier));
        console2.log("SymbioticVerifier: %s;", address(deployment.symbioticVerifier));
        console2.log("VaultConfigurator: %s;", address(deployment.vaultConfigurator));
        console2.log("BasicRedeemHook: %s;", address(deployment.basicRedeemHook));
        console2.log("RedirectingDepositHook: %s;", address(deployment.redirectingDepositHook));
        console2.log("LidoDipositHook: %s;", address(deployment.lidoDipositHook));
        console2.log("OracleHelper: %s;", address(deployment.oracleHelper));

        vm.stopBroadcast();
        // revert("ok");
    }

    uint256[24] salts = [
        161420072,
        206168175,
        1134198651,
        25303717,
        105346364,
        18404464,
        620838836,
        12743547,
        677653447,
        1105234833,
        17073315,
        727066582,
        6949341,
        537661517,
        566243638,
        1898672671,
        20875874,
        212203443,
        4395719,
        399337235,
        304033180,
        28998053,
        66374472,
        76224809
    ];
    uint256 saltIterator = 0;

    function _deployWithOptimalSalt(string memory title, bytes memory creationCode, bytes memory constructorParams)
        internal
        returns (address a)
    {
        a = Create2.deploy(0, bytes32(salts[saltIterator++]), abi.encodePacked(creationCode, constructorParams));
        console2.log("%s: %s;", title, a);
    }

    function deployBase(address deployer, address proxyAdmin) public returns (Deployment memory $) {
        Factory factoryImplementation = Factory(
            _deployWithOptimalSalt(
                "Factory implementation", type(Factory).creationCode, abi.encode(DEPLOYMENT_NAME, DEPLOYMENT_VERSION)
            )
        );

        $.baseFactory = Factory(
            _deployWithOptimalSalt(
                "Factory",
                type(TransparentUpgradeableProxy).creationCode,
                abi.encode(
                    factoryImplementation, deployer, abi.encodeCall(IFactoryEntity.initialize, (abi.encode(deployer)))
                )
            )
        );

        {
            $.baseFactory.proposeImplementation(address(factoryImplementation));
            $.baseFactory.acceptProposedImplementation(address(factoryImplementation));
            $.baseFactory.transferOwnership(proxyAdmin);
        }

        {
            $.consensusFactory = Factory($.baseFactory.create(0, deployer, abi.encode(deployer)));
            {
                address implementation = _deployWithOptimalSalt(
                    "Consensus implementation",
                    type(Consensus).creationCode,
                    abi.encode(DEPLOYMENT_NAME, DEPLOYMENT_VERSION)
                );
                $.consensusFactory.proposeImplementation(implementation);
                $.consensusFactory.acceptProposedImplementation(implementation);
            }
            $.consensusFactory.transferOwnership(proxyAdmin);
        }

        {
            $.depositQueueFactory = Factory($.baseFactory.create(0, deployer, abi.encode(deployer)));
            {
                address implementation = _deployWithOptimalSalt(
                    "DepositQueue implementation",
                    type(DepositQueue).creationCode,
                    abi.encode(DEPLOYMENT_NAME, DEPLOYMENT_VERSION)
                );
                $.depositQueueFactory.proposeImplementation(implementation);
                $.depositQueueFactory.acceptProposedImplementation(implementation);
            }
            {
                address implementation = _deployWithOptimalSalt(
                    "SignatureDepositQueue implementation",
                    type(SignatureDepositQueue).creationCode,
                    abi.encode(DEPLOYMENT_NAME, DEPLOYMENT_VERSION, $.consensusFactory)
                );
                $.depositQueueFactory.proposeImplementation(implementation);
                $.depositQueueFactory.acceptProposedImplementation(implementation);
            }
            $.depositQueueFactory.transferOwnership(proxyAdmin);
        }

        {
            $.feeManagerFactory = Factory($.baseFactory.create(0, deployer, abi.encode(deployer)));
            address implementation = _deployWithOptimalSalt(
                "FeeManager implementation",
                type(FeeManager).creationCode,
                abi.encode(DEPLOYMENT_NAME, DEPLOYMENT_VERSION)
            );
            $.feeManagerFactory.proposeImplementation(implementation);
            $.feeManagerFactory.acceptProposedImplementation(implementation);
            $.feeManagerFactory.transferOwnership(proxyAdmin);
        }

        {
            $.oracleFactory = Factory($.baseFactory.create(0, deployer, abi.encode(deployer)));
            address implementation = _deployWithOptimalSalt(
                "Oracle implementation", type(Oracle).creationCode, abi.encode(DEPLOYMENT_NAME, DEPLOYMENT_VERSION)
            );
            $.oracleFactory.proposeImplementation(implementation);
            $.oracleFactory.acceptProposedImplementation(implementation);
            $.oracleFactory.transferOwnership(proxyAdmin);
        }

        {
            $.redeemQueueFactory = Factory($.baseFactory.create(0, deployer, abi.encode(deployer)));
            {
                address implementation = _deployWithOptimalSalt(
                    "RedeemQueue implementation",
                    type(RedeemQueue).creationCode,
                    abi.encode(DEPLOYMENT_NAME, DEPLOYMENT_VERSION)
                );
                $.redeemQueueFactory.proposeImplementation(implementation);
                $.redeemQueueFactory.acceptProposedImplementation(implementation);
            }
            {
                address implementation = _deployWithOptimalSalt(
                    "SignatureRedeemQueue implementation",
                    type(SignatureRedeemQueue).creationCode,
                    abi.encode(DEPLOYMENT_NAME, DEPLOYMENT_VERSION, $.consensusFactory)
                );
                $.redeemQueueFactory.proposeImplementation(implementation);
                $.redeemQueueFactory.acceptProposedImplementation(implementation);
            }
            $.redeemQueueFactory.transferOwnership(proxyAdmin);
        }

        {
            $.riskManagerFactory = Factory($.baseFactory.create(0, deployer, abi.encode(deployer)));
            address implementation = _deployWithOptimalSalt(
                "RiskManager implementation",
                type(RiskManager).creationCode,
                abi.encode(DEPLOYMENT_NAME, DEPLOYMENT_VERSION)
            );
            $.riskManagerFactory.proposeImplementation(implementation);
            $.riskManagerFactory.acceptProposedImplementation(implementation);
            $.riskManagerFactory.transferOwnership(proxyAdmin);
        }

        {
            $.shareManagerFactory = Factory($.baseFactory.create(0, deployer, abi.encode(deployer)));
            {
                address implementation = _deployWithOptimalSalt(
                    "TokenizedShareManager implementation",
                    type(TokenizedShareManager).creationCode,
                    abi.encode(DEPLOYMENT_NAME, DEPLOYMENT_VERSION)
                );
                $.shareManagerFactory.proposeImplementation(implementation);
                $.shareManagerFactory.acceptProposedImplementation(implementation);
            }
            {
                address implementation = _deployWithOptimalSalt(
                    "BasicShareManager implementation",
                    type(BasicShareManager).creationCode,
                    abi.encode(DEPLOYMENT_NAME, DEPLOYMENT_VERSION)
                );
                $.shareManagerFactory.proposeImplementation(implementation);
                $.shareManagerFactory.acceptProposedImplementation(implementation);
            }
            $.shareManagerFactory.transferOwnership(proxyAdmin);
        }

        {
            $.subvaultFactory = Factory($.baseFactory.create(0, deployer, abi.encode(deployer)));
            address implementation = _deployWithOptimalSalt(
                "Subvault implementation", type(Subvault).creationCode, abi.encode(DEPLOYMENT_NAME, DEPLOYMENT_VERSION)
            );
            $.subvaultFactory.proposeImplementation(implementation);
            $.subvaultFactory.acceptProposedImplementation(implementation);
            $.subvaultFactory.transferOwnership(proxyAdmin);
        }

        {
            $.verifierFactory = Factory($.baseFactory.create(0, deployer, abi.encode(deployer)));
            address implementation = _deployWithOptimalSalt(
                "Verifier implementation", type(Verifier).creationCode, abi.encode(DEPLOYMENT_NAME, DEPLOYMENT_VERSION)
            );
            $.verifierFactory.proposeImplementation(implementation);
            $.verifierFactory.acceptProposedImplementation(implementation);
            $.verifierFactory.transferOwnership(proxyAdmin);
        }

        {
            $.vaultFactory = Factory($.baseFactory.create(0, deployer, abi.encode(deployer)));
            address implementation = _deployWithOptimalSalt(
                "Vault implementation",
                type(Vault).creationCode,
                abi.encode(
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
            $.vaultFactory.transferOwnership(proxyAdmin);
        }

        $.bitmaskVerifier = _deployWithOptimalSalt("BitmaskVerifier", type(BitmaskVerifier).creationCode, new bytes(0));

        $.eigenLayerVerifier = _deployWithOptimalSalt(
            "EigenLayerVerifier",
            type(EigenLayerVerifier).creationCode,
            abi.encode(
                0x39053D51B77DC0d36036Fc1fCc8Cb819df8Ef37A,
                0x858646372CC42E1A627fcE94aa7A7033e7CF075A,
                0x7750d328b314EfFa365A0402CcfD489B80B0adda,
                DEPLOYMENT_NAME,
                DEPLOYMENT_VERSION
            )
        );

        $.erc20Verifier = _deployWithOptimalSalt(
            "ERC20Verifier", type(ERC20Verifier).creationCode, abi.encode(DEPLOYMENT_NAME, DEPLOYMENT_VERSION)
        );

        $.symbioticVerifier = _deployWithOptimalSalt(
            "SymbioticVerifier",
            type(SymbioticVerifier).creationCode,
            abi.encode(
                0xAEb6bdd95c502390db8f52c8909F703E9Af6a346,
                0xFEB871581C2ab2e1EEe6f7dDC7e6246cFa087A23,
                DEPLOYMENT_NAME,
                DEPLOYMENT_VERSION
            )
        );

        $.vaultConfigurator = _deployWithOptimalSalt(
            "VaultConfigurator",
            type(VaultConfigurator).creationCode,
            abi.encode(
                address($.shareManagerFactory),
                address($.feeManagerFactory),
                address($.riskManagerFactory),
                address($.oracleFactory),
                address($.vaultFactory)
            )
        );

        $.basicRedeemHook = _deployWithOptimalSalt("BasicRedeeHook", type(BasicRedeemHook).creationCode, new bytes(0));

        $.redirectingDepositHook =
            _deployWithOptimalSalt("RedirectingDepositHook", type(RedirectingDepositHook).creationCode, new bytes(0));

        $.lidoDipositHook = _deployWithOptimalSalt(
            "LidoDepositHook",
            type(LidoDepositHook).creationCode,
            abi.encode(
                0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0,
                0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
                $.redirectingDepositHook
            )
        );

        $.oracleHelper = _deployWithOptimalSalt("OracleHelper", type(OracleHelper).creationCode, new bytes(0));
    }
}
