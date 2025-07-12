// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../Imports.sol";

contract MockCustomVerifier is ICustomVerifier {
    error VerificationFailed();

    function verifyCall(address, address, uint256, bytes calldata, bytes calldata verificationData)
        external
        pure
        returns (bool result)
    {
        (result) = abi.decode(verificationData, (bool));
    }

    function test() external {}
}

contract VerifierTest is Test {
    address admin = vm.createWallet("admin").addr;
    address proxyAdmin = vm.createWallet("proxyAdmin").addr;

    address CALL_ROLE_ADDRESS = vm.createWallet("CALL_ROLE").addr;
    address SET_MERKLE_ROOT_ROLE_ADDRESS = vm.createWallet("SET_MERKLE_ROOT_ROLE").addr;
    address ALLOW_CALL_ROLE_ADDRESS = vm.createWallet("ALLOW_CALL_ROLE").addr;
    address DISALLOW_CALL_ROLE_ADDRESS = vm.createWallet("DISALLOW_CALL_ROLE").addr;

    address caller1 = vm.createWallet("caller1").addr;
    address caller2 = vm.createWallet("caller2").addr;
    address target1 = vm.createWallet("target1").addr;
    address target2 = vm.createWallet("target2").addr;
    bytes callData1 = abi.encode(keccak256("random callData1"));
    bytes callData2 = abi.encode(keccak256("random callData2"));
    bytes32[] proof;

    MockACLModule vault;
    bytes32 dummyMerkleRoot = keccak256("dummyMerkleRoot");

    function setUp() external {
        address vaultImplementation = address(new MockACLModule("vault", 1));

        vault = MockACLModule(
            payable(new TransparentUpgradeableProxy(address(vaultImplementation), proxyAdmin, new bytes(0)))
        );

        vault.initialize(abi.encode(admin));

        proof = new bytes32[](1);
        proof[0] = keccak256("proof1");
    }

    function testInitialize() external {
        Verifier verifierImplementation = new Verifier("name", 1);
        Verifier verifier = Verifier(
            address(new TransparentUpgradeableProxy(address(verifierImplementation), proxyAdmin, new bytes(0)))
        );

        bytes memory initParams = abi.encode(address(0), dummyMerkleRoot);

        vm.expectRevert("ZeroValue()");
        verifier.initialize(initParams);

        initParams = abi.encode(admin, dummyMerkleRoot);
        verifier.initialize(initParams);
    }

    function testCreate() external {
        Verifier verifier = createVerifier("Verifier", 1, admin);

        assertTrue(verifier.merkleRoot() == dummyMerkleRoot);

        assertEq(address(verifier.vault()), address(vault));
        assertEq(verifier.merkleRoot(), dummyMerkleRoot);
        assertEq(verifier.allowedCalls(), 0);
    }

    function testSetMerkleRoot() external {
        Verifier verifier = createVerifier("Verifier", 1, admin);

        assertTrue(verifier.merkleRoot() == dummyMerkleRoot);

        vm.startPrank(admin);
        vault.grantRole(verifier.SET_MERKLE_ROOT_ROLE(), SET_MERKLE_ROOT_ROLE_ADDRESS);
        vm.stopPrank();

        bytes32 newMerkleRoot = keccak256("newMerkleRoot");

        vm.prank(SET_MERKLE_ROOT_ROLE_ADDRESS);
        verifier.setMerkleRoot(newMerkleRoot);

        assertTrue(verifier.merkleRoot() == newMerkleRoot);
    }

    function testAllowCalls() external {
        Verifier verifier = createVerifier("Verifier", 1, admin);
        IVerifier.CompactCall[] memory compactCalls = new IVerifier.CompactCall[](1);
        compactCalls[0] = IVerifier.CompactCall({who: caller1, where: target1, selector: bytes4(callData1)});
        IVerifier.CompactCall memory compactCallNotAllowed =
            IVerifier.CompactCall({who: caller2, where: target2, selector: bytes4(callData2)});

        assertFalse(verifier.isAllowedCall(compactCalls[0].who, compactCalls[0].where, callData1));

        vm.expectRevert("Forbidden()");
        verifier.allowCalls(compactCalls);

        vm.prank(ALLOW_CALL_ROLE_ADDRESS);
        verifier.allowCalls(compactCalls);

        assertTrue(verifier.isAllowedCall(compactCalls[0].who, compactCalls[0].where, callData1));

        assertFalse(verifier.isAllowedCall(compactCallNotAllowed.who, compactCallNotAllowed.where, callData2));

        assertEq(verifier.allowedCalls(), 1);

        vm.expectRevert("panic: array out-of-bounds access (0x32)");
        verifier.allowedCallAt(1);

        IVerifier.CompactCall memory compactCall = verifier.allowedCallAt(0);

        assertEq(compactCall.who, caller1);
        assertEq(compactCall.where, target1);
        assertEq(compactCall.selector, bytes4(callData1));

        vm.prank(ALLOW_CALL_ROLE_ADDRESS);
        vm.expectRevert(
            abi.encodeWithSelector(
                IVerifier.CompactCallAlreadyAllowed.selector,
                compactCalls[0].who,
                compactCalls[0].where,
                compactCalls[0].selector
            )
        );
        verifier.allowCalls(compactCalls);
    }

    function testDisallowCalls() external {
        Verifier verifier = createVerifier("Verifier", 1, admin);
        IVerifier.CompactCall[] memory compactCalls = new IVerifier.CompactCall[](1);
        compactCalls[0] = IVerifier.CompactCall({who: caller1, where: target1, selector: bytes4(callData1)});

        vm.expectRevert("Forbidden()");
        verifier.disallowCalls(compactCalls);

        vm.prank(DISALLOW_CALL_ROLE_ADDRESS);
        vm.expectRevert(
            abi.encodeWithSelector(
                IVerifier.CompactCallNotFound.selector,
                compactCalls[0].who,
                compactCalls[0].where,
                compactCalls[0].selector
            )
        );
        verifier.disallowCalls(compactCalls);

        vm.prank(ALLOW_CALL_ROLE_ADDRESS);
        verifier.allowCalls(compactCalls);

        assertEq(verifier.allowedCalls(), 1);
        assertTrue(verifier.isAllowedCall(compactCalls[0].who, compactCalls[0].where, callData1));

        vm.prank(DISALLOW_CALL_ROLE_ADDRESS);
        verifier.disallowCalls(compactCalls);

        assertEq(verifier.allowedCalls(), 0);
        assertFalse(verifier.isAllowedCall(compactCalls[0].who, compactCalls[0].where, callData1));
    }

    function testVerificationCall_Onchain_Compat() external {
        Verifier verifier = createVerifier("Verifier", 1, admin);
        IVerifier.CompactCall[] memory compactCalls = new IVerifier.CompactCall[](1);
        compactCalls[0] = IVerifier.CompactCall({who: CALL_ROLE_ADDRESS, where: target1, selector: bytes4(callData1)});

        IVerifier.VerificationPayload memory verificationPayload = IVerifier.VerificationPayload({
            verificationType: IVerifier.VerificationType.ONCHAIN_COMPACT,
            verificationData: new bytes(0),
            proof: new bytes32[](0)
        });

        assertFalse(verifier.getVerificationResult(caller1, target1, 0, callData1, verificationPayload));

        vm.expectRevert("VerificationFailed()");
        verifier.verifyCall(CALL_ROLE_ADDRESS, caller1, 0, callData1, verificationPayload);

        vm.expectRevert("VerificationFailed()");
        verifier.verifyCall(CALL_ROLE_ADDRESS, target1, 0, callData1, verificationPayload);

        vm.prank(ALLOW_CALL_ROLE_ADDRESS);
        verifier.allowCalls(compactCalls);
        assertEq(verifier.allowedCalls(), 1);
        assertTrue(verifier.isAllowedCall(compactCalls[0].who, compactCalls[0].where, callData1));

        assertTrue(verifier.getVerificationResult(CALL_ROLE_ADDRESS, target1, 0, callData1, verificationPayload));
        verifier.verifyCall(CALL_ROLE_ADDRESS, target1, 0, callData1, verificationPayload);
    }

    function testVerificationCall_Merkle_Extended() external {
        Verifier verifier = createVerifier("Verifier", 1, admin);

        IVerifier.VerificationPayload memory verificationPayload = IVerifier.VerificationPayload({
            verificationType: IVerifier.VerificationType.MERKLE_EXTENDED,
            verificationData: abi.encodePacked(
                verifier.hashCall(
                    IVerifier.ExtendedCall({who: CALL_ROLE_ADDRESS, where: target1, value: 0, data: callData1})
                )
            ),
            proof: proof
        });

        assertFalse(verifier.getVerificationResult(CALL_ROLE_ADDRESS, target1, 0, callData1, verificationPayload));

        setValidMerkleRootForPayloadAndProof(verifier, proof, verificationPayload);

        assertTrue(verifier.getVerificationResult(CALL_ROLE_ADDRESS, target1, 0, callData1, verificationPayload));
        verifier.verifyCall(CALL_ROLE_ADDRESS, target1, 0, callData1, verificationPayload);
    }

    function testVerificationCall_Merkle_Compat() external {
        Verifier verifier = createVerifier("Verifier", 1, admin);

        bytes4 validSelector = bytes4(keccak256("validSelector"));
        bytes memory validCalldata1 = abi.encodeWithSelector(validSelector, keccak256("data1"));
        bytes memory validCalldata2 = abi.encodeWithSelector(validSelector, keccak256("data2"));

        IVerifier.VerificationPayload memory verificationPayload = IVerifier.VerificationPayload({
            verificationType: IVerifier.VerificationType.MERKLE_COMPACT,
            verificationData: abi.encodePacked(
                verifier.hashCall(IVerifier.CompactCall({who: CALL_ROLE_ADDRESS, where: target1, selector: validSelector}))
            ),
            proof: proof
        });

        assertFalse(verifier.getVerificationResult(CALL_ROLE_ADDRESS, target1, 0, validCalldata1, verificationPayload));
        assertFalse(verifier.getVerificationResult(CALL_ROLE_ADDRESS, target1, 0, validCalldata2, verificationPayload));

        setValidMerkleRootForPayloadAndProof(verifier, proof, verificationPayload);

        assertTrue(verifier.getVerificationResult(CALL_ROLE_ADDRESS, target1, 0, validCalldata1, verificationPayload));
        verifier.verifyCall(CALL_ROLE_ADDRESS, target1, 0, validCalldata1, verificationPayload);

        assertTrue(verifier.getVerificationResult(CALL_ROLE_ADDRESS, target1, 0, validCalldata2, verificationPayload));
        verifier.verifyCall(CALL_ROLE_ADDRESS, target1, 0, validCalldata2, verificationPayload);
    }

    function testVerificationCall_Custom_Verifier_Success() external {
        Verifier verifier = createVerifier("Verifier", 1, admin);
        MockCustomVerifier customVerifier = new MockCustomVerifier();

        IVerifier.VerificationPayload memory verificationPayload = IVerifier.VerificationPayload({
            verificationType: IVerifier.VerificationType.CUSTOM_VERIFIER,
            verificationData: abi.encode(customVerifier, true),
            proof: proof
        });

        assertFalse(verifier.getVerificationResult(CALL_ROLE_ADDRESS, target1, 0, callData1, verificationPayload));

        setValidMerkleRootForPayloadAndProof(verifier, proof, verificationPayload);

        assertTrue(verifier.getVerificationResult(CALL_ROLE_ADDRESS, target1, 0, callData1, verificationPayload));
        verifier.verifyCall(CALL_ROLE_ADDRESS, target1, 0, callData1, verificationPayload);
    }

    function testVerificationCall_Custom_Verifier_Fail() external {
        Verifier verifier = createVerifier("Verifier", 1, admin);
        MockCustomVerifier customVerifier = new MockCustomVerifier();

        IVerifier.VerificationPayload memory verificationPayload = IVerifier.VerificationPayload({
            verificationType: IVerifier.VerificationType.CUSTOM_VERIFIER,
            verificationData: abi.encode(customVerifier, false),
            proof: proof
        });

        assertFalse(verifier.getVerificationResult(CALL_ROLE_ADDRESS, target1, 0, callData1, verificationPayload));

        setValidMerkleRootForPayloadAndProof(verifier, proof, verificationPayload);

        assertFalse(verifier.getVerificationResult(CALL_ROLE_ADDRESS, target1, 0, callData1, verificationPayload));
        vm.expectRevert("VerificationFailed()");
        verifier.verifyCall(CALL_ROLE_ADDRESS, target1, 0, callData1, verificationPayload);
    }

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
        vault.grantRole(verifier.DISALLOW_CALL_ROLE(), DISALLOW_CALL_ROLE_ADDRESS);
        vault.grantRole(verifier.SET_MERKLE_ROOT_ROLE(), SET_MERKLE_ROOT_ROLE_ADDRESS);
        vm.stopPrank();
    }

    function setValidMerkleRootForPayloadAndProof(
        Verifier verifier,
        bytes32[] memory proof_,
        IVerifier.VerificationPayload memory verificationPayload
    ) internal {
        bytes32 leaf = keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(verificationPayload.verificationType, keccak256(verificationPayload.verificationData))
                )
            )
        );
        bytes32 root = MerkleProof.processProof(proof_, leaf);

        vm.startPrank(SET_MERKLE_ROOT_ROLE_ADDRESS);
        verifier.setMerkleRoot(root);
    }
}
