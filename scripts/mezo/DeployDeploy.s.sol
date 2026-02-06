// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/utils/Create2.sol";

import "forge-std/Script.sol";
import "src/DeployVaultFactory.sol";
import "src/DeployVaultFactoryRegistry.sol";

contract Deploy is Script {
    uint256 startSalt = 0;

    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);

        vm.startBroadcast(deployerPk);

        address vaultConfigurator = 0x00000000f731118c52AeA768c1ac22CEcA7e3b8D;
        address verifierFactory = 0xbc1468D587DaEE3023E2b41Cc642643AF3221178;
        address oracleSubmitterFactory = 0x00000007AA9Bd15F538a2d1D68A2aCFE8D09BFd0;

        address registry =
            _deployWithOptimalSalt("DeployVaultFactoryRegistry", type(DeployVaultFactoryRegistry).creationCode, "");

        _deployWithOptimalSalt(
            "DeployVaultFactory",
            type(DeployVaultFactory).creationCode,
            abi.encode(vaultConfigurator, verifierFactory, oracleSubmitterFactory, registry)
        );
        vm.stopBroadcast();
        // revert("ok");
    }

    function _deployWithOptimalSalt(string memory title, bytes memory creationCode, bytes memory constructorParams)
        internal
        returns (address a)
    {
        (bytes32 salt, address addr) = _findOptSalt(startSalt, creationCode, constructorParams);
        startSalt = uint256(salt) + 1;
        a = Create2.deploy(0, salt, abi.encodePacked(creationCode, constructorParams));
        require(a == addr, "mismatched address");
        console2.log("salt %s | %s: %s;", uint256(salt), title, a);
    }

    function _findOptSalt(uint256 startSalt_, bytes memory creationCode, bytes memory constructorParams)
        internal
        pure
        returns (bytes32 salt, address addr)
    {
        bytes32 bytecodeHash = keccak256(abi.encodePacked(creationCode, constructorParams));
        address create2Deployer = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
        salt = bytes32(startSalt_);

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
