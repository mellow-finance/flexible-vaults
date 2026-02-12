// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/utils/Create2.sol";

import "forge-std/Script.sol";
import "src/DeployVaultFactory.sol";
import "src/DeployVaultFactoryRegistry.sol";
import "src/OracleSubmitterFactory.sol";

contract Deploy is Script {
    uint256 startSalt = 0;

    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);

        vm.startBroadcast(deployerPk);

        address vaultConfigurator = 0x9B626C849eaBe8486DDFeb439c97d327447e5996;
        address verifierFactory = 0x10B98695aBeeC98FADaeE5155819434670936206;
        address oracleSubmitterFactory =
            _deployWithOptimalSalt("OracleSubmitterFactory", type(OracleSubmitterFactory).creationCode, "");

        address registry =
            _deployWithOptimalSalt("DeployVaultFactoryRegistry", type(DeployVaultFactoryRegistry).creationCode, "");

        _deployWithOptimalSalt(
            "DeployVaultFactory",
            type(DeployVaultFactory).creationCode,
            abi.encode(vaultConfigurator, verifierFactory, oracleSubmitterFactory, registry)
        );
        vm.stopBroadcast();
        revert("ok");
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
