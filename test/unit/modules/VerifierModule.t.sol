// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../Imports.sol";

contract MockVerifierModule is VerifierModule {
    constructor(string memory name_, uint256 version_) VerifierModule(name_, version_) {}

    function initialize(bytes calldata initParams) external initializer {
        (address verifier_) = abi.decode(initParams, (address));
        __VerifierModule_init(verifier_);
    }

    function test() external {}
}

contract VerifierModuleTest is Test {
    address admin = vm.createWallet("admin").addr;
    address proxyAdmin = vm.createWallet("proxyAdmin").addr;

    function testVerifierModule() external {
        address verifier = vm.createWallet("verifier").addr;
        MockVerifierModule module;

        module = createVerifierModule("Test", 1);
        vm.expectRevert("ZeroAddress()");
        module.initialize(abi.encode(address(0)));

        module.initialize(abi.encode(verifier));
        assertEq(address(module.verifier()), verifier, "Verifier should match");
    }

    function createVerifierModule(string memory name, uint256 version) internal returns (MockVerifierModule module) {
        MockVerifierModule moduleImplementation = new MockVerifierModule(name, version);
        module = MockVerifierModule(
            payable(new TransparentUpgradeableProxy(address(moduleImplementation), proxyAdmin, new bytes(0)))
        );
    }
}
