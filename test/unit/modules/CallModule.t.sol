// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../Imports.sol";

contract MockCallModule is CallModule {
    constructor(string memory name_, uint256 version_) VerifierModule(name_, version_) {}

    function initialize(bytes calldata initParams) external initializer {
        (address verifier_) = abi.decode(initParams, (address));
        __VerifierModule_init(verifier_);
    }

    function test() external {}
}

contract CallModuleTest is Test {
    address admin = vm.createWallet("admin").addr;
    address proxyAdmin = vm.createWallet("proxyAdmin").addr;
    address CALL_ROLE_ADDRESS = vm.createWallet("CALL_ROLE").addr;
    address ALLOW_CALL_ROLE_ADDRESS = vm.createWallet("ALLOW_CALL_ROLE").addr;
    address target = vm.createWallet("target").addr;
    MockACLModule vault;
    bytes32 dummyMerkleRoot = keccak256("dummyMerkleRoot");

    function setUp() external {
        address vaultImplementation = address(new MockACLModule("vault", 1));

        vault = MockACLModule(
            payable(new TransparentUpgradeableProxy(address(vaultImplementation), proxyAdmin, new bytes(0)))
        );

        vault.initialize(abi.encode(admin));
    }

    function testCreate() external {
        Verifier verifier = createVerifier("Verifier", 1, admin);
        MockCallModule module = createCallModule(address(verifier));
        require(address(module) != address(0), "Module creation failed");
    }

    function testVerificationCall() external {
        Verifier verifier = createVerifier("Verifier", 1, admin);
        MockCallModule module = createCallModule(address(verifier));
        IVerifier.CompactCall[] memory compactCalls = new IVerifier.CompactCall[](1);

        bytes memory callData = abi.encode(bytes4(keccak256("mockFunction()")));

        compactCalls[0] =
            IVerifier.CompactCall({who: CALL_ROLE_ADDRESS, where: address(this), selector: bytes4(callData)});

        IVerifier.VerificationPayload memory verificationPayload = IVerifier.VerificationPayload({
            verificationType: IVerifier.VerificationType.ONCHAIN_COMPACT,
            verificationData: new bytes(0),
            proof: new bytes32[](0)
        });

        vm.prank(ALLOW_CALL_ROLE_ADDRESS);
        verifier.allowCalls(compactCalls);

        assertTrue(verifier.getVerificationResult(CALL_ROLE_ADDRESS, address(this), 0, callData, verificationPayload));
        vm.prank(CALL_ROLE_ADDRESS);
        module.call(address(this), 0, callData, verificationPayload);
    }

    function createCallModule(address admin_) internal returns (MockCallModule module) {
        MockCallModule moduleImplementation = new MockCallModule("CallModule", 1);
        module = MockCallModule(
            payable(new TransparentUpgradeableProxy(address(moduleImplementation), proxyAdmin, new bytes(0)))
        );
        module.initialize(abi.encode(admin_));
    }

    function mockFunction() public {}

    function createVerifier(string memory name, uint256 version, address admin_) internal returns (Verifier verifier) {
        Verifier verifierImplementation = new Verifier(name, version);
        verifier = Verifier(
            address(new TransparentUpgradeableProxy(address(verifierImplementation), proxyAdmin, new bytes(0)))
        );

        bytes memory initParams = abi.encode(vault, dummyMerkleRoot);
        verifier.initialize(initParams);

        vm.startPrank(admin_);
        vault.grantRole(verifier.CALLER_ROLE(), CALL_ROLE_ADDRESS);
        vault.grantRole(verifier.ALLOW_CALL_ROLE(), ALLOW_CALL_ROLE_ADDRESS);
        vm.stopPrank();
    }
}
