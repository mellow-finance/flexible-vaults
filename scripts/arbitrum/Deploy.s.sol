// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../test/Imports.sol";

import "./Constants.sol";
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
        Factory erc20VerifierFactory;
        address bitmaskVerifier;
        address erc20Verifier;
        address vaultConfigurator;
        address basicRedeemHook;
        address redirectingDepositHook;
        address oracleHelper;
    }

    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);

        vm.startBroadcast(deployerPk);

        address proxyAdmin = 0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0;
        //deployBase(deployer, proxyAdmin);
        deploySwapModule(deployer, proxyAdmin);
        vm.stopBroadcast();

        // revert("ok");
    }

    uint256 saltIterator = 0;
    uint256[21] salts = [
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
        5058654958,
        5272721088,
        5014513337,
        5102682030,
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

    function deploySwapModule(address deployer, address proxyAdmin) public {
        Factory swapModuleFactory =
            Factory(IFactory(Constants.protocolDeployment().factory).create(0, proxyAdmin, abi.encode(deployer)));
        console2.log("SwapModule factory: %s", address(swapModuleFactory));

        bytes memory creationCode = type(SwapModule).creationCode;
        bytes memory constructorParams = abi.encode(
            DEPLOYMENT_NAME,
            DEPLOYMENT_VERSION,
            Constants.COWSWAP_SETTLEMENT,
            Constants.COWSWAP_VAULT_RELAYER,
            Constants.WETH
        );

        (bytes32 salt, address addr) = _findOptSalt(0, creationCode, constructorParams);
        address implementation = Create2.deploy(0, salt, abi.encodePacked(creationCode, constructorParams));

        require(implementation == addr, "Deployment address mismatch");

        console2.log("SwapModule implementation: %s", implementation);

        swapModuleFactory.proposeImplementation(implementation);
        swapModuleFactory.acceptProposedImplementation(implementation);

        swapModuleFactory.transferOwnership(proxyAdmin);
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
            $.erc20VerifierFactory = Factory($.baseFactory.create(0, proxyAdmin, abi.encode(deployer)));
            console2.log("ERC20Verifier factory: %s", address($.erc20VerifierFactory));
            address implementation = _deployWithOptimalSalt(
                "ERC20Verifier", type(ERC20Verifier).creationCode, abi.encode(DEPLOYMENT_NAME, DEPLOYMENT_VERSION)
            );

            $.erc20VerifierFactory.proposeImplementation(implementation);
            $.erc20VerifierFactory.acceptProposedImplementation(implementation);
            $.erc20VerifierFactory.transferOwnership(proxyAdmin);
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

        $.oracleHelper = _deployWithOptimalSalt("OracleHelper", type(OracleHelper).creationCode, new bytes(0));
    }

    function _findOptSalt(uint256 startSalt, bytes memory creationCode, bytes memory constructorParams)
        internal
        pure
        returns (bytes32 salt, address addr)
    {
        bytes32 bytecodeHash = keccak256(abi.encodePacked(creationCode, constructorParams));
        address create2Deployer = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
        salt = bytes32(startSalt);

        uint256 thershold = 1 << (160 - 28);
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(add(ptr, 0x40), bytecodeHash)
            mstore(ptr, create2Deployer)
            let start := add(ptr, 0x0b)
            mstore8(start, 0xff)

            ptr := add(ptr, 0x20)

            for {} 1 { salt := add(salt, 1) } {
                mstore(ptr, salt)
                addr := and(keccak256(start, 85), 0xffffffffffffffffffffffffffffffffffffffff)
                if lt(addr, thershold) { break }
            }
        }
    }
}
