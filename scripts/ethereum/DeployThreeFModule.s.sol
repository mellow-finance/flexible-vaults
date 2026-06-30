// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import "scripts/common/interfaces/Imports.sol";

import "@openzeppelin/contracts/utils/Create2.sol";

import "./Constants.sol";

contract Deploy is Script {
    string public constant DEPLOYMENT_NAME = Constants.DEPLOYMENT_NAME;
    uint256 public constant DEPLOYMENT_VERSION = Constants.DEPLOYMENT_VERSION;

    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);
        ProtocolDeployment memory deployment = Constants.protocolDeployment();

        vm.startBroadcast(deployerPk);

        deployThreeFModuleFactory(
            deployment.factoryImplementation,
            deployer,
            deployment.proxyAdmin,
            Constants.USDC,
            5, // implementation: 6 leading zero nibbles, then "3f"
            3 // factory: 3 leading 0x3f bytes (0x3f3f3f...)
        );

        vm.stopBroadcast();
        //revert("ok");
    }

    /// @notice Standalone deploy of a ThreeFModule factory + implementation, both at vanity CREATE2 addresses.
    /// @dev Both contracts are deployed through Foundry's deterministic CREATE2 factory (CREATE2_FACTORY),
    ///      so salts are mined against that deployer. The asset is baked into the implementation at
    ///      construction, so one implementation is registered per asset. The factory is deployed directly as
    ///      a TransparentUpgradeableProxy of the shared Factory implementation (NOT via Factory.create,
    ///      whose salt is not caller-controlled) so its address can be vanity-mined too.
    /// @param factoryImplementation Shared Factory logic contract the new factory proxy points to.
    /// @param deployer              Initial Factory owner (the broadcasting account) that registers the impl.
    /// @param proxyAdmin            Final Factory owner and proxy admin of the factory + every entity it creates.
    /// @param asset                 ERC-20 asset baked into the ThreeFModule implementation.
    /// @param zeroNibbles           Leading zero hex digits required before "3f" in the implementation address.
    /// @param factory3fBytes        Number of leading 0x3f bytes required in the factory address (0x3f3f3f...).
    function deployThreeFModuleFactory(
        Factory factoryImplementation,
        address deployer,
        address proxyAdmin,
        address asset,
        uint256 zeroNibbles,
        uint256 factory3fBytes
    ) internal returns (Factory factory, address implementation) {
        // 1) ThreeFModule implementation: vanity address = `zeroNibbles` leading zero nibbles, then "3f".
        bytes memory implInitCode =
            abi.encodePacked(type(ThreeFModule).creationCode, abi.encode(DEPLOYMENT_NAME, DEPLOYMENT_VERSION, asset));
        (bytes32 implSalt, address implPredicted) =
            _findVanitySalt(keccak256(implInitCode), CREATE2_FACTORY, 0x3f, zeroNibbles + 2);
        console.log("ThreeFModule implementation (predicted): %s", implPredicted);
        console.log("ThreeFModule implementation salt:");
        console.logBytes32(implSalt);
        implementation = Create2.deploy(0, implSalt, implInitCode);
        require(implementation == implPredicted, "ThreeFModule: impl address mismatch");
        console.log("ThreeFModule implementation: %s", implementation);

        // 2) Factory proxy: vanity address = leading 0x3f3f3f... (`factory3fBytes` copies of the 0x3f byte).
        bytes memory factoryInitCode = abi.encodePacked(
            type(TransparentUpgradeableProxy).creationCode,
            abi.encode(
                address(factoryImplementation),
                proxyAdmin,
                abi.encodeCall(IFactoryEntity.initialize, (abi.encode(deployer)))
            )
        );
        uint256 factoryPrefix; // 0x3f repeated `factory3fBytes` times, e.g. 0x3f3f3f
        for (uint256 i = 0; i < factory3fBytes; i++) {
            factoryPrefix = (factoryPrefix << 8) | 0x3f;
        }
        (bytes32 factorySalt, address factoryPredicted) =
            _findVanitySalt(keccak256(factoryInitCode), CREATE2_FACTORY, factoryPrefix, factory3fBytes * 2);
        console.log("ThreeFModule factory (predicted): %s", factoryPredicted);
        console.log("ThreeFModule factory salt:");
        console.logBytes32(factorySalt);
        factory = Factory(Create2.deploy(0, factorySalt, factoryInitCode));
        require(address(factory) == factoryPredicted, "ThreeFModule: factory address mismatch");
        console.log("ThreeFModule factory: %s", address(factory));

        // 3) Register the implementation and hand the factory to governance.
        factory.proposeImplementation(implementation);
        factory.acceptProposedImplementation(implementation);
        factory.transferOwnership(proxyAdmin);
        console.log("ThreeFModule proxy admin: %s", proxyAdmin);
    }

    /// @dev Brute-forces a CREATE2 salt so the address deployed by `deployer` begins with `prefix`,
    ///      occupying its leading `prefixNibbles` hex digits. The CREATE2 hash
    ///      keccak256(0xff ++ deployer ++ salt ++ initCodeHash) is computed in assembly with the constant
    ///      prefix laid out once; each iteration only rewrites the salt word and re-hashes.
    ///      Cost grows ~16^prefixNibbles, so keep prefixes short. Reverts if no match within the bound.
    function _findVanitySalt(bytes32 initCodeHash, address deployer, uint256 prefix, uint256 prefixNibbles)
        internal
        pure
        returns (bytes32 salt, address addr)
    {
        uint256 prefixShift = 160 - prefixNibbles * 4;
        uint256 found;
        assembly ("memory-safe") {
            // Scratch at the free memory pointer (not persisted):
            //   [ptr+11]     = 0xff
            //   [ptr+12,+32) = deployer (20 bytes, right-aligned by mstore)
            //   [ptr+32,+64) = salt (rewritten each iteration)
            //   [ptr+64,+96) = initCodeHash
            let ptr := mload(0x40)
            mstore(ptr, deployer)
            mstore8(add(ptr, 11), 0xff)
            mstore(add(ptr, 0x40), initCodeHash)
            let hashStart := add(ptr, 11)
            for { let i := 0 } lt(i, 1000000000) { i := add(i, 1) } {
                mstore(add(ptr, 0x20), i)
                let a := and(keccak256(hashStart, 85), 0xffffffffffffffffffffffffffffffffffffffff)
                if eq(shr(prefixShift, a), prefix) {
                    salt := i
                    addr := a
                    found := 1
                    break
                }
            }
        }
        require(found == 1, "ThreeFModule: vanity salt not found");
    }
}
