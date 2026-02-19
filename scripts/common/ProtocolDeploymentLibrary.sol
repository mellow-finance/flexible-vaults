// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {console} from "forge-std/console.sol";

import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {Factory, IFactoryEntity} from "../../src/factories/Factory.sol";

import {BasicRedeemHook} from "../../src/hooks/BasicRedeemHook.sol";

import {LidoDepositHook} from "../../src/hooks/LidoDepositHook.sol";
import {RedirectingDepositHook} from "../../src/hooks/RedirectingDepositHook.sol";

import {Oracle} from "../../src/oracles/Oracle.sol";
import {OracleHelper} from "../../src/oracles/OracleHelper.sol";

import {BitmaskVerifier} from "../../src/permissions/BitmaskVerifier.sol";
import {ERC20Verifier} from "../../src/permissions/protocols/ERC20Verifier.sol";

import {EigenLayerVerifier} from "../../src/permissions/protocols/EigenLayerVerifier.sol";
import {SymbioticVerifier} from "../../src/permissions/protocols/SymbioticVerifier.sol";

import {Consensus} from "../../src/permissions/Consensus.sol";
import {Verifier} from "../../src/permissions/Verifier.sol";

import {DepositQueue} from "../../src/queues/DepositQueue.sol";
import {SignatureDepositQueue} from "../../src/queues/SignatureDepositQueue.sol";
import {SyncDepositQueue} from "../../src/queues/SyncDepositQueue.sol";

import {RedeemQueue} from "../../src/queues/RedeemQueue.sol";
import {SignatureRedeemQueue} from "../../src/queues/SignatureRedeemQueue.sol";

import {BasicShareManager} from "../../src/managers/BasicShareManager.sol";
import {BurnableTokenizedShareManager} from "../../src/managers/BurnableTokenizedShareManager.sol";

import {FeeManager} from "../../src/managers/FeeManager.sol";
import {RiskManager} from "../../src/managers/RiskManager.sol";
import {TokenizedShareManager} from "../../src/managers/TokenizedShareManager.sol";

import {Subvault} from "../../src/vaults/Subvault.sol";
import {Vault} from "../../src/vaults/Vault.sol";
import {VaultConfigurator} from "../../src/vaults/VaultConfigurator.sol";

import {SwapModule} from "../../src/utils/SwapModule.sol";

import {MellowAccountV1} from "../../src/accounts/MellowAccountV1.sol";

struct ProtocolDeployment {
    string deploymentName;
    uint256 deploymentVersion;
    address cowswapSettlement;
    address cowswapVaultRelayer;
    address eigenLayerDelegationManager;
    address eigenLayerStrategyManager;
    address eigenLayerRewardsCoordinator;
    address symbioticVaultFactory;
    address symbioticFarmFactory;
    address wsteth;
    address weth;
    address proxyAdmin;
    address deployer;
    Factory factoryImplementation;
    Factory factory;
    Factory erc20VerifierFactory;
    Factory symbioticVerifierFactory;
    Factory eigenLayerVerifierFactory;
    Factory riskManagerFactory;
    Factory subvaultFactory;
    Factory verifierFactory;
    Factory vaultFactory;
    Factory shareManagerFactory;
    Factory consensusFactory;
    Factory depositQueueFactory;
    Factory redeemQueueFactory;
    Factory feeManagerFactory;
    Factory oracleFactory;
    Factory swapModuleFactory;
    Factory accountFactory;
    Consensus consensusImplementation;
    DepositQueue depositQueueImplementation;
    SignatureDepositQueue signatureDepositQueueImplementation;
    SyncDepositQueue syncDepositQueueImplementation;
    RedeemQueue redeemQueueImplementation;
    SignatureRedeemQueue signatureRedeemQueueImplementation;
    FeeManager feeManagerImplementation;
    Oracle oracleImplementation;
    RiskManager riskManagerImplementation;
    TokenizedShareManager tokenizedShareManagerImplementation;
    BurnableTokenizedShareManager burnableTokenizedShareManagerImplementation;
    BasicShareManager basicShareManagerImplementation;
    Subvault subvaultImplementation;
    Verifier verifierImplementation;
    Vault vaultImplementation;
    BitmaskVerifier bitmaskVerifier;
    ERC20Verifier erc20VerifierImplementation;
    SymbioticVerifier symbioticVerifierImplementation;
    EigenLayerVerifier eigenLayerVerifierImplementation;
    SwapModule swapModuleImplementation;
    VaultConfigurator vaultConfigurator;
    BasicRedeemHook basicRedeemHook;
    RedirectingDepositHook redirectingDepositHook;
    LidoDepositHook lidoDepositHook;
    OracleHelper oracleHelper;
    MellowAccountV1 mellowAccountV1Implementation;
}

library ProtocolDeploymentLibrary {
    struct DeploymentParams {
        address cowswapSettlement;
        address cowswapVaultRelayer;
        address weth;
        uint256 minLeadingZeros;
        bytes32[] salt;
    }

    string public constant DEPLOYMENT_NAME = "Mellow";
    uint256 public constant DEPLOYMENT_VERSION = 1;

    address public constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    struct Deployment {
        address deployer;
        address proxyAdmin;
        // Factories
        address baseFactory;
        address consensusFactory;
        address depositQueueFactory;
        address redeemQueueFactory;
        address oracleFactory;
        address feeManagerFactory;
        address riskManagerFactory;
        address shareManagerFactory;
        address subvaultFactory;
        address vaultFactory;
        address verifierFactory;
        address erc20VerifierFactory;
        address accountFactory;
        address swapModuleFactory;
        // Singletons
        address oracleHelper;
        address bitmaskVerifier;
        address vaultConfigurator;
        address basicRedeemHook;
        address redirectingDepositHook;
    }

    function _deploy(
        DeploymentParams memory params,
        uint256 index,
        string memory title,
        bytes memory creationCode,
        bytes memory constructorParams
    ) private returns (uint256, address) {
        bytes32 salt = params.salt[index];

        bytes memory bytecode = abi.encodePacked(creationCode, constructorParams);
        address expectedAddress = Create2.computeAddress(salt, keccak256(bytecode), CREATE2_DEPLOYER);

        uint256 requiredMask = type(uint160).max >> (4 * params.minLeadingZeros);
        if ((uint160(expectedAddress) | requiredMask) != requiredMask) {
            revert(string.concat("Not enough leading zeros for ", title));
        }

        address a = Create2.deploy(0, salt, bytecode);
        if (a != expectedAddress) {
            revert(string.concat("Invalid expected address for ", title));
        }

        console.log("%s: %s;", title, a);
        return (index + 1, a);
    }

    function convert(Deployment memory $, DeploymentParams memory params)
        internal
        view
        returns (ProtocolDeployment memory d)
    {
        d.deploymentName = DEPLOYMENT_NAME;
        d.deploymentVersion = DEPLOYMENT_VERSION;
        d.eigenLayerDelegationManager = address(0);
        d.eigenLayerStrategyManager = address(0);
        d.eigenLayerRewardsCoordinator = address(0);
        d.cowswapSettlement = params.cowswapSettlement;
        d.cowswapVaultRelayer = params.cowswapVaultRelayer;
        d.symbioticVaultFactory = address(0);
        d.symbioticFarmFactory = address(0);
        d.wsteth = address(0);
        d.weth = params.weth;
        d.proxyAdmin = $.proxyAdmin;
        d.deployer = $.deployer;

        d.factoryImplementation = Factory(Factory($.baseFactory).implementationAt(0));
        d.factory = Factory($.baseFactory);
        d.erc20VerifierFactory = Factory($.erc20VerifierFactory);
        d.symbioticVerifierFactory = Factory(address(0));
        d.eigenLayerVerifierFactory = Factory(address(0));
        d.riskManagerFactory = Factory($.riskManagerFactory);
        d.subvaultFactory = Factory($.subvaultFactory);
        d.verifierFactory = Factory($.verifierFactory);
        d.vaultFactory = Factory($.vaultFactory);
        d.shareManagerFactory = Factory($.shareManagerFactory);
        d.consensusFactory = Factory($.consensusFactory);
        d.depositQueueFactory = Factory($.depositQueueFactory);
        d.redeemQueueFactory = Factory($.redeemQueueFactory);
        d.feeManagerFactory = Factory($.feeManagerFactory);
        d.oracleFactory = Factory($.oracleFactory);
        d.swapModuleFactory = Factory($.swapModuleFactory);
        d.accountFactory = Factory($.accountFactory);

        d.consensusImplementation = Consensus(d.consensusFactory.implementationAt(0));
        d.depositQueueImplementation = DepositQueue(payable(d.depositQueueFactory.implementationAt(0)));
        d.signatureDepositQueueImplementation =
            SignatureDepositQueue(payable(d.depositQueueFactory.implementationAt(1)));
        d.syncDepositQueueImplementation = SyncDepositQueue(payable(d.depositQueueFactory.implementationAt(2)));

        d.redeemQueueImplementation = RedeemQueue(payable(d.redeemQueueFactory.implementationAt(0)));
        d.signatureRedeemQueueImplementation = SignatureRedeemQueue(payable(d.redeemQueueFactory.implementationAt(1)));

        d.feeManagerImplementation = FeeManager(d.feeManagerFactory.implementationAt(0));
        d.oracleImplementation = Oracle(d.oracleFactory.implementationAt(0));
        d.riskManagerImplementation = RiskManager(d.riskManagerFactory.implementationAt(0));

        d.tokenizedShareManagerImplementation = TokenizedShareManager(d.shareManagerFactory.implementationAt(0));
        d.basicShareManagerImplementation = BasicShareManager(d.shareManagerFactory.implementationAt(1));
        d.burnableTokenizedShareManagerImplementation =
            BurnableTokenizedShareManager(d.shareManagerFactory.implementationAt(2));

        d.subvaultImplementation = Subvault(payable(d.subvaultFactory.implementationAt(0)));
        d.verifierImplementation = Verifier(d.verifierFactory.implementationAt(0));
        d.vaultImplementation = Vault(payable(d.vaultFactory.implementationAt(0)));

        d.bitmaskVerifier = BitmaskVerifier($.bitmaskVerifier);
        d.erc20VerifierImplementation = ERC20Verifier(d.erc20VerifierFactory.implementationAt(0));

        d.swapModuleImplementation = SwapModule(payable(d.swapModuleFactory.implementationAt(0)));

        d.vaultConfigurator = VaultConfigurator($.vaultConfigurator);

        d.basicRedeemHook = BasicRedeemHook($.basicRedeemHook);
        d.redirectingDepositHook = RedirectingDepositHook($.redirectingDepositHook);
        d.oracleHelper = OracleHelper($.oracleHelper);
        d.mellowAccountV1Implementation = MellowAccountV1(d.accountFactory.implementationAt(0));

        return d;
    }

    function _deployProposeAndAccept(
        address factory,
        DeploymentParams memory params,
        uint256 index,
        string memory title,
        bytes memory creationCode,
        bytes memory constructorParams
    ) private returns (uint256) {
        (uint256 newIndex, address implementation) = _deploy(params, index, title, creationCode, constructorParams);
        Factory(factory).proposeImplementation(implementation);
        Factory(factory).acceptProposedImplementation(implementation);
        return newIndex;
    }

    function _transferOwnership(address factory, address proxyAdmin) private {
        if (Factory(factory).owner() != proxyAdmin) {
            Factory(factory).transferOwnership(proxyAdmin);
        }
    }

    function deploy(address deployer, address proxyAdmin, DeploymentParams memory params)
        internal
        returns (ProtocolDeployment memory)
    {
        Deployment memory $;
        (uint256 index, address implementation) =
            _deploy(params, 0, "Factory", type(Factory).creationCode, abi.encode(DEPLOYMENT_NAME, DEPLOYMENT_VERSION));

        (index, $.baseFactory) = _deploy(
            params,
            index,
            "FactoryFactory",
            type(TransparentUpgradeableProxy).creationCode,
            abi.encode(implementation, proxyAdmin, abi.encodeCall(IFactoryEntity.initialize, (abi.encode(deployer))))
        );
        Factory($.baseFactory).proposeImplementation(implementation);
        Factory($.baseFactory).acceptProposedImplementation(implementation);

        {
            $.consensusFactory = Factory($.baseFactory).create(0, proxyAdmin, abi.encode(deployer));
            $.depositQueueFactory = Factory($.baseFactory).create(0, proxyAdmin, abi.encode(deployer));
            $.redeemQueueFactory = Factory($.baseFactory).create(0, proxyAdmin, abi.encode(deployer));
            $.oracleFactory = Factory($.baseFactory).create(0, proxyAdmin, abi.encode(deployer));
            $.feeManagerFactory = Factory($.baseFactory).create(0, proxyAdmin, abi.encode(deployer));
            $.riskManagerFactory = Factory($.baseFactory).create(0, proxyAdmin, abi.encode(deployer));
            $.shareManagerFactory = Factory($.baseFactory).create(0, proxyAdmin, abi.encode(deployer));
            $.subvaultFactory = Factory($.baseFactory).create(0, proxyAdmin, abi.encode(deployer));
            $.vaultFactory = Factory($.baseFactory).create(0, proxyAdmin, abi.encode(deployer));
            $.verifierFactory = Factory($.baseFactory).create(0, proxyAdmin, abi.encode(deployer));
            $.erc20VerifierFactory = Factory($.baseFactory).create(0, proxyAdmin, abi.encode(deployer));
            $.accountFactory = Factory($.baseFactory).create(0, proxyAdmin, abi.encode(deployer));
            $.swapModuleFactory = Factory($.baseFactory).create(0, proxyAdmin, abi.encode(deployer));

            console.log("ConsensusFactory", $.consensusFactory);
            console.log("DepositQueueFactory", $.depositQueueFactory);
            console.log("RedeemQueueFactory", $.redeemQueueFactory);
            console.log("OracleFactory", $.oracleFactory);
            console.log("FeeManagerFactory", $.feeManagerFactory);
            console.log("RiskManagerFactory", $.riskManagerFactory);
            console.log("ShareManagerFactory", $.shareManagerFactory);
            console.log("SubvaultFactory", $.subvaultFactory);
            console.log("VaultFactory", $.vaultFactory);
            console.log("VerifierFactory", $.verifierFactory);
            console.log("ERC20VerifierFactory", $.erc20VerifierFactory);
            console.log("AccountFactory", $.accountFactory);
            console.log("SwapModuleFactory", $.swapModuleFactory);
        }

        index = _deployProposeAndAccept(
            $.consensusFactory,
            params,
            index,
            "Consensus",
            type(Consensus).creationCode,
            abi.encode(DEPLOYMENT_NAME, DEPLOYMENT_VERSION)
        );

        index = _deployProposeAndAccept(
            $.depositQueueFactory,
            params,
            index,
            "DepositQueue",
            type(DepositQueue).creationCode,
            abi.encode(DEPLOYMENT_NAME, DEPLOYMENT_VERSION)
        );

        index = _deployProposeAndAccept(
            $.depositQueueFactory,
            params,
            index,
            "SignatureDepositQueue",
            type(SignatureDepositQueue).creationCode,
            abi.encode(DEPLOYMENT_NAME, DEPLOYMENT_VERSION, $.consensusFactory)
        );
        index = _deployProposeAndAccept(
            $.depositQueueFactory,
            params,
            index,
            "SyncDepositQueue",
            type(SyncDepositQueue).creationCode,
            abi.encode(DEPLOYMENT_NAME, DEPLOYMENT_VERSION)
        );

        index = _deployProposeAndAccept(
            $.feeManagerFactory,
            params,
            index,
            "FeeManager",
            type(FeeManager).creationCode,
            abi.encode(DEPLOYMENT_NAME, DEPLOYMENT_VERSION)
        );

        index = _deployProposeAndAccept(
            $.oracleFactory,
            params,
            index,
            "Oracle",
            type(Oracle).creationCode,
            abi.encode(DEPLOYMENT_NAME, DEPLOYMENT_VERSION)
        );
        index = _deployProposeAndAccept(
            $.redeemQueueFactory,
            params,
            index,
            "RedeemQueue",
            type(RedeemQueue).creationCode,
            abi.encode(DEPLOYMENT_NAME, DEPLOYMENT_VERSION)
        );

        index = _deployProposeAndAccept(
            $.redeemQueueFactory,
            params,
            index,
            "SignatureRedeemQueue",
            type(SignatureRedeemQueue).creationCode,
            abi.encode(DEPLOYMENT_NAME, DEPLOYMENT_VERSION, $.consensusFactory)
        );

        index = _deployProposeAndAccept(
            $.riskManagerFactory,
            params,
            index,
            "RiskManager",
            type(RiskManager).creationCode,
            abi.encode(DEPLOYMENT_NAME, DEPLOYMENT_VERSION)
        );

        index = _deployProposeAndAccept(
            $.shareManagerFactory,
            params,
            index,
            "TokenizedShareManager",
            type(TokenizedShareManager).creationCode,
            abi.encode(DEPLOYMENT_NAME, DEPLOYMENT_VERSION)
        );
        index = _deployProposeAndAccept(
            $.shareManagerFactory,
            params,
            index,
            "BasicShareManager",
            type(BasicShareManager).creationCode,
            abi.encode(DEPLOYMENT_NAME, DEPLOYMENT_VERSION)
        );
        index = _deployProposeAndAccept(
            $.shareManagerFactory,
            params,
            index,
            "BurnableTokenizedShareManager",
            type(BurnableTokenizedShareManager).creationCode,
            abi.encode(DEPLOYMENT_NAME, DEPLOYMENT_VERSION)
        );

        index = _deployProposeAndAccept(
            $.subvaultFactory,
            params,
            index,
            "Subvault",
            type(Subvault).creationCode,
            abi.encode(DEPLOYMENT_NAME, DEPLOYMENT_VERSION)
        );
        index = _deployProposeAndAccept(
            $.verifierFactory,
            params,
            index,
            "Verifier",
            type(Verifier).creationCode,
            abi.encode(DEPLOYMENT_NAME, DEPLOYMENT_VERSION)
        );
        index = _deployProposeAndAccept(
            $.erc20VerifierFactory,
            params,
            index,
            "ERC20Verifier",
            type(ERC20Verifier).creationCode,
            abi.encode(DEPLOYMENT_NAME, DEPLOYMENT_VERSION)
        );

        index = _deployProposeAndAccept(
            $.accountFactory, params, index, "MellowAccountV1", type(MellowAccountV1).creationCode, abi.encode()
        );

        index = _deployProposeAndAccept(
            $.swapModuleFactory,
            params,
            index,
            "SwapModule",
            type(SwapModule).creationCode,
            abi.encode(
                DEPLOYMENT_NAME, DEPLOYMENT_VERSION, params.cowswapSettlement, params.cowswapVaultRelayer, params.weth
            )
        );

        index = _deployProposeAndAccept(
            $.vaultFactory,
            params,
            index,
            "Vault",
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

        (index, $.bitmaskVerifier) =
            _deploy(params, index, "BitmaskVerifier", type(BitmaskVerifier).creationCode, new bytes(0));

        (index, $.vaultConfigurator) = _deploy(
            params,
            index,
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

        (index, $.basicRedeemHook) =
            _deploy(params, index, "BasicRedeemHook", type(BasicRedeemHook).creationCode, new bytes(0));

        (index, $.redirectingDepositHook) =
            _deploy(params, index, "RedirectingDepositHook", type(RedirectingDepositHook).creationCode, new bytes(0));

        (index, $.oracleHelper) = _deploy(params, index, "OracleHelper", type(OracleHelper).creationCode, new bytes(0));

        if (index != params.salt.length) {
            revert("Invalid params.salt length");
        }

        {
            _transferOwnership($.baseFactory, proxyAdmin);
            _transferOwnership($.consensusFactory, proxyAdmin);
            _transferOwnership($.depositQueueFactory, proxyAdmin);
            _transferOwnership($.redeemQueueFactory, proxyAdmin);
            _transferOwnership($.oracleFactory, proxyAdmin);
            _transferOwnership($.feeManagerFactory, proxyAdmin);
            _transferOwnership($.riskManagerFactory, proxyAdmin);
            _transferOwnership($.subvaultFactory, proxyAdmin);
            _transferOwnership($.vaultFactory, proxyAdmin);
            _transferOwnership($.verifierFactory, proxyAdmin);
            _transferOwnership($.erc20VerifierFactory, proxyAdmin);
            _transferOwnership($.accountFactory, proxyAdmin);
            _transferOwnership($.swapModuleFactory, proxyAdmin);
        }

        $.deployer = deployer;
        $.proxyAdmin = proxyAdmin;
        return convert($, params);
    }
}
