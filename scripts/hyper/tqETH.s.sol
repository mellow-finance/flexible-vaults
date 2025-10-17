// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../test/Imports.sol";
import "forge-std/Script.sol";

import "../common/ArraysLibrary.sol";
import "../common/Permissions.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";

contract Deploy is Script {
    address public immutable proxyAdminOwner = 0x73514c05D354E254a3ed03668C70A305845ef786;
    address public immutable lazyVaultAdmin = 0x21B6c92301cD31f60bA3de1D85c1517a0b700C83;
    // EOA agent
    address public immutable curator = 0xb764428a29EAEbe8e2301F5924746F818b331F5A;
    address public immutable activeVaultAdmin = 0x4987F07eCeCE90E7FA82402d66AAA57c08fEb7cB;

    // constants
    IFactory public constant subvaultFactory = IFactory(0x71deDd5787aCC3a6f35A88393dd2691b82F14b69);
    IFactory public constant verifierFactory = IFactory(0x206f922aE23Dc359E01eF9b041A8F7d15E9DfD70);

    address public constant SEPOLIA_SUBVAULT_1 = 0xFcE16317364EC44620F05528Ce170eDc1c6AD5fD;
    address public constant USDC = 0x2B3370eE501B4a559b57D449569354196457D8Ab;
    address public constant HL_CORE = 0x2222222222222222222222222222222222222222;
    address public constant HL_CORE_WRITER = 0x3333333333333333333333333333333333333333;

    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);

        vm.startBroadcast(deployerPk);

        TimelockController vault;

        {
            address[] memory proposers = ArraysLibrary.makeAddressArray(abi.encode(curator, lazyVaultAdmin, deployer));
            address[] memory executors = ArraysLibrary.makeAddressArray(abi.encode(curator, lazyVaultAdmin));
            vault = new TimelockController(0, proposers, executors, deployer);

            vault.grantRole(Permissions.DEFAULT_ADMIN_ROLE, lazyVaultAdmin);
            vault.grantRole(Permissions.SET_MERKLE_ROOT_ROLE, address(vault));
        }

        address subvault0 =
            subvaultFactory.create(0, proxyAdminOwner, abi.encode(_createVerifier(address(vault)), address(vault)));
        IVerifier verifier = Subvault(payable(subvault0)).verifier();

        vault.schedule(
            address(verifier),
            0,
            abi.encodeCall(IVerifier.setMerkleRoot, (bytes32(0))),
            bytes32(0),
            bytes32(0),
            0
        );

        vault.renounceRole(vault.PROPOSER_ROLE(), deployer);
        vault.renounceRole(vault.CANCELLER_ROLE(), deployer);
        vault.renounceRole(Permissions.DEFAULT_ADMIN_ROLE, deployer);

        vm.stopBroadcast();

        console2.log("Vault (TimelockController): %s", address(vault));
        console2.log("Subvault0: %s", subvault0);
        console2.log("Verifier: %s", address(verifier));

        revert("Done");
    }

    function _createVerifier(address vault) internal returns (address verifier) {
        verifier = verifierFactory.create(0, proxyAdminOwner, abi.encode(vault, bytes32(0)));
        /*
            Allowed calls:
            1. usdc.approve(HLBridge, any)
            2. HLBridge.bridge(params)
            3. HLCore.deposit(usdc, sepoliaSubvault1) = transfer to 0x22..22
            4. CoreWriter.sendRawAction([version:1byte][actionId:3bytes][abi.encode(params)]) version 0x01, Only actions 1,6,7,10,11 supported
        */
    }
}
