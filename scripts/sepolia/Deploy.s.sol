// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../test/Imports.sol";
import "forge-std/Script.sol";

import "@openzeppelin/contracts/utils/Create2.sol";

contract Deploy is Script {
    string public constant DEPLOYMENT_NAME = "Mellow";
    uint256 public constant DEPLOYMENT_VERSION = 1;

    address public constant WETH = 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9;
    address public constant WSTETH = 0xB82381A3fBD3FaFA77B3a7bE693342618240067b;
    address public constant PROXY_ADMIN = 0x12B6692F7240aCbC354cD48Dfc275EfdfB293b24;

    address public constant EIGEN_LAYER_DELEGATION_MANAGER = 0xD4A7E1Bd8015057293f0D0A557088c286942e84b;
    address public constant EIGEN_LAYER_STRATEGY_MANAGER = 0x2E3D6c0744b10eb0A4e6F679F71554a39Ec47a5D;
    address public constant EIGEN_LAYER_REWARDS_COORDINATOR = 0x5ae8152fb88c26ff9ca5C014c94fca3c68029349;

    address public constant SYMBIOTIC_VAULT_FACTORY = 0x407A039D94948484D356eFB765b3c74382A050B4;
    address public constant SYMBIOTIC_FARM_FACTORY = 0xE6381EDA7444672da17Cd859e442aFFcE7e170F0;

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
        Factory eigenLayerVerifierFactory;
        Factory erc20VerifierFactory;
        Factory symbioticVerifierFactory;
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

        deployBase(deployer, PROXY_ADMIN);
        vm.stopBroadcast();
    }

    uint256 saltIterator = 0;
    uint256[24] salts = [
        5114582977,
        5515340580,
        5113806307,
        5047574954,
        5116594781,
        5128862644,
        5173681114,
        5113158103,
        5034343171,
        5008460874,
        5045079882,
        5041025932,
        5065060024,
        5432668441,
        6013650345,
        5030787156,
        5179393410,
        5058654958,
        5269244144,
        5272721088,
        5014513337,
        5102682030,
        5118264457,
        5258974968
    ];

    function _deployWithOptimalSalt(string memory title, bytes memory creationCode, bytes memory constructorParams)
        internal
        returns (address a)
    {
        bytes32 salt = bytes32(salts[saltIterator++]);
        a = Create2.deploy(0, salt, abi.encodePacked(creationCode, constructorParams));
        console2.log("%s: %s;", title, a);
    }

    function deployBase(address deployer, address proxyAdmin) public returns (Deployment memory $) {
        {
            Factory implementation = Factory(
                _deployWithOptimalSalt(
                    "Factory implementation",
                    type(Factory).creationCode,
                    abi.encode(DEPLOYMENT_NAME, DEPLOYMENT_VERSION)
                )
            );

            $.baseFactory = Factory(
                _deployWithOptimalSalt(
                    "Factory factory",
                    type(TransparentUpgradeableProxy).creationCode,
                    abi.encode(
                        implementation, proxyAdmin, abi.encodeCall(IFactoryEntity.initialize, (abi.encode(deployer)))
                    )
                )
            );
            $.baseFactory.proposeImplementation(address(implementation));
            $.baseFactory.acceptProposedImplementation(address(implementation));
            $.baseFactory.transferOwnership(proxyAdmin);
        }

        {
            $.consensusFactory = Factory($.baseFactory.create(0, proxyAdmin, abi.encode(deployer)));
            console2.log("Consensus factory: %s", address($.consensusFactory));
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
            $.depositQueueFactory = Factory($.baseFactory.create(0, proxyAdmin, abi.encode(deployer)));
            console2.log("DepositQueue factory: %s", address($.depositQueueFactory));
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
            $.feeManagerFactory = Factory($.baseFactory.create(0, proxyAdmin, abi.encode(deployer)));
            console2.log("FeeManager factory: %s", address($.feeManagerFactory));
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
            $.oracleFactory = Factory($.baseFactory.create(0, proxyAdmin, abi.encode(deployer)));
            console2.log("Oracle factory: %s", address($.oracleFactory));
            address implementation = _deployWithOptimalSalt(
                "Oracle implementation", type(Oracle).creationCode, abi.encode(DEPLOYMENT_NAME, DEPLOYMENT_VERSION)
            );
            $.oracleFactory.proposeImplementation(implementation);
            $.oracleFactory.acceptProposedImplementation(implementation);
            $.oracleFactory.transferOwnership(proxyAdmin);
        }

        {
            $.redeemQueueFactory = Factory($.baseFactory.create(0, proxyAdmin, abi.encode(deployer)));
            console2.log("RedeemQueue factory: %s", address($.redeemQueueFactory));
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
            $.riskManagerFactory = Factory($.baseFactory.create(0, proxyAdmin, abi.encode(deployer)));
            console2.log("RiskManager factory: %s", address($.riskManagerFactory));
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
            $.shareManagerFactory = Factory($.baseFactory.create(0, proxyAdmin, abi.encode(deployer)));
            console2.log("ShareManager factory: %s", address($.shareManagerFactory));
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
            $.subvaultFactory = Factory($.baseFactory.create(0, proxyAdmin, abi.encode(deployer)));
            console2.log("Subvault factory: %s", address($.subvaultFactory));
            address implementation = _deployWithOptimalSalt(
                "Subvault implementation", type(Subvault).creationCode, abi.encode(DEPLOYMENT_NAME, DEPLOYMENT_VERSION)
            );
            $.subvaultFactory.proposeImplementation(implementation);
            $.subvaultFactory.acceptProposedImplementation(implementation);
            $.subvaultFactory.transferOwnership(proxyAdmin);
        }

        {
            $.verifierFactory = Factory($.baseFactory.create(0, proxyAdmin, abi.encode(deployer)));
            console2.log("Verifier factory: %s", address($.verifierFactory));
            address implementation = _deployWithOptimalSalt(
                "Verifier implementation", type(Verifier).creationCode, abi.encode(DEPLOYMENT_NAME, DEPLOYMENT_VERSION)
            );
            $.verifierFactory.proposeImplementation(implementation);
            $.verifierFactory.acceptProposedImplementation(implementation);
            $.verifierFactory.transferOwnership(proxyAdmin);
        }

        {
            $.vaultFactory = Factory($.baseFactory.create(0, proxyAdmin, abi.encode(deployer)));
            console2.log("Vault factory: %s", address($.vaultFactory));
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

        {
            $.eigenLayerVerifierFactory = Factory($.baseFactory.create(0, proxyAdmin, abi.encode(deployer)));
            console2.log("EigenLayerVerifier factory: %s", address($.eigenLayerVerifierFactory));
            address implementation = _deployWithOptimalSalt(
                "EigenLayerVerifier",
                type(EigenLayerVerifier).creationCode,
                abi.encode(
                    EIGEN_LAYER_DELEGATION_MANAGER,
                    EIGEN_LAYER_STRATEGY_MANAGER,
                    EIGEN_LAYER_REWARDS_COORDINATOR,
                    DEPLOYMENT_NAME,
                    DEPLOYMENT_VERSION
                )
            );

            $.eigenLayerVerifierFactory.proposeImplementation(implementation);
            $.eigenLayerVerifierFactory.acceptProposedImplementation(implementation);
            $.eigenLayerVerifierFactory.transferOwnership(proxyAdmin);
        }

        {
            $.erc20VerifierFactory = Factory($.baseFactory.create(0, proxyAdmin, abi.encode(deployer)));
            console2.log("ERC20Verifier factory: %s", address($.erc20VerifierFactory));
            address implementation = _deployWithOptimalSalt(
                "ERC20Verifier", type(ERC20Verifier).creationCode, abi.encode(DEPLOYMENT_NAME, DEPLOYMENT_VERSION)
            );

            $.erc20VerifierFactory.proposeImplementation(implementation);
            $.erc20VerifierFactory.acceptProposedImplementation(implementation);
            $.erc20VerifierFactory.transferOwnership(proxyAdmin);
        }

        {
            $.symbioticVerifierFactory = Factory($.baseFactory.create(0, proxyAdmin, abi.encode(deployer)));
            console2.log("SymbioticVerifier factory: %s", address($.symbioticVerifierFactory));
            address implementation = _deployWithOptimalSalt(
                "SymbioticVerifier",
                type(SymbioticVerifier).creationCode,
                abi.encode(
                    SYMBIOTIC_VAULT_FACTORY,
                    SYMBIOTIC_FARM_FACTORY,
                    DEPLOYMENT_NAME,
                    DEPLOYMENT_VERSION
                )
            );
            $.symbioticVerifierFactory.proposeImplementation(implementation);
            $.symbioticVerifierFactory.acceptProposedImplementation(implementation);
            $.symbioticVerifierFactory.transferOwnership(proxyAdmin);
        }

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
                WSTETH,
                WETH,
                $.redirectingDepositHook
            )
        );

        $.oracleHelper = _deployWithOptimalSalt("OracleHelper", type(OracleHelper).creationCode, new bytes(0));
    }
}
