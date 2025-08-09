// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../Fixture.t.sol";
import "../../Imports.sol";

contract ConsensusTest is FixtureTest {
    address admin = vm.createWallet("admin").addr;
    address proxyAdmin = vm.createWallet("proxyAdmin").addr;
    address internal signer1 = vm.createWallet("signer1").addr;
    address internal signer2 = vm.createWallet("signer2").addr;
    bytes32 internal dummyHash = keccak256("order");

    function _createConsensus() internal returns (Consensus consensus) {
        Consensus consensusImplementation = new Consensus("Consensus", 1);
        consensus = Consensus(
            address(new TransparentUpgradeableProxy(address(consensusImplementation), proxyAdmin, new bytes(0)))
        );
        consensus.initialize(abi.encode(admin));
    }

    function _sign(bytes32 hash, uint256 pk) internal pure returns (bytes memory sig) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, hash);
        return abi.encodePacked(r, s, v);
    }

    function testInitializeOwner() public {
        Consensus consensus = _createConsensus();
        assertEq(consensus.owner(), admin);
    }

    function testAddSignerAndThreshold() public {
        Consensus consensus = _createConsensus();

        vm.prank(admin);
        consensus.addSigner(signer1, 1, IConsensus.SignatureType.EIP712);

        assertEq(consensus.signers(), 1);
        assertEq(consensus.threshold(), 1);
        assertTrue(consensus.isSigner(signer1));
    }

    function testAddSignerZeroAddress() public {
        Consensus consensus = _createConsensus();

        vm.prank(admin);

        vm.expectRevert(IConsensus.ZeroAddress.selector);
        consensus.addSigner(address(0), 1, IConsensus.SignatureType.EIP712);
    }

    function testAddSignerInvalidType() public {
        Consensus consensus = _createConsensus();
        bool success;

        vm.startPrank(admin);
        (success,) = address(consensus).call(abi.encodeWithSelector(consensus.addSigner.selector, signer1, 1, 2));
        assert(!success);
        (success,) = address(consensus).call(abi.encodeWithSelector(consensus.addSigner.selector, signer1, 1, 1));
        assert(success);
        assert(consensus.isSigner(signer1));
    }

    function testAddSignerTwiceFails() public {
        Consensus consensus = _createConsensus();

        vm.startPrank(admin);
        consensus.addSigner(signer1, 1, IConsensus.SignatureType.EIP712);

        vm.expectRevert(abi.encodeWithSelector(IConsensus.SignerAlreadyExists.selector, signer1));
        consensus.addSigner(signer1, 1, IConsensus.SignatureType.EIP712);
    }

    function testRemoveSigner() public {
        Consensus consensus = _createConsensus();

        vm.startPrank(admin);
        consensus.addSigner(signer1, 1, IConsensus.SignatureType.EIP712);
        consensus.addSigner(signer2, 1, IConsensus.SignatureType.EIP1271);
        assertEq(consensus.signers(), 2);
        assert(consensus.isSigner(signer1));
        assert(consensus.isSigner(signer2));

        consensus.removeSigner(signer1, 1);
        assertFalse(consensus.isSigner(signer1));
        assert(consensus.isSigner(signer2));
        assertEq(consensus.signers(), 1);

        vm.expectRevert(abi.encodeWithSelector(IConsensus.SignerNotFound.selector, address(0)));
        consensus.removeSigner(address(0), 1);
    }

    function testRemoveNonexistentSigner() public {
        Consensus consensus = _createConsensus();

        vm.startPrank(admin);
        consensus.addSigner(signer2, 1, IConsensus.SignatureType.EIP1271);

        vm.expectRevert(abi.encodeWithSelector(IConsensus.SignerNotFound.selector, signer1));
        consensus.removeSigner(signer1, 0);
    }

    function testSetThresholdInvalid() public {
        Consensus consensus = _createConsensus();

        vm.startPrank(admin);

        vm.expectRevert(abi.encodeWithSelector(IConsensus.InvalidThreshold.selector, 2));
        consensus.addSigner(signer1, 2, IConsensus.SignatureType.EIP712);

        consensus.addSigner(signer1, 1, IConsensus.SignatureType.EIP712);

        vm.expectRevert(abi.encodeWithSelector(IConsensus.InvalidThreshold.selector, 0));
        consensus.removeSigner(signer1, 0);

        vm.expectRevert(abi.encodeWithSelector(IConsensus.InvalidThreshold.selector, 0));
        consensus.setThreshold(0);

        vm.expectRevert(abi.encodeWithSelector(IConsensus.InvalidThreshold.selector, 2));
        consensus.setThreshold(2);

        vm.expectRevert(abi.encodeWithSelector(IConsensus.InvalidThreshold.selector, 0));
        consensus.addSigner(signer2, 0, IConsensus.SignatureType.EIP1271);

        consensus.addSigner(signer2, 2, IConsensus.SignatureType.EIP1271);

        vm.expectRevert(abi.encodeWithSelector(IConsensus.InvalidThreshold.selector, 2));
        consensus.removeSigner(signer1, 2);

        consensus.removeSigner(signer1, 1);

        // check set of valid Threshold
        consensus.setThreshold(1);
    }

    function testSignerAtAndLength() public {
        Consensus consensus = _createConsensus();

        vm.prank(admin);
        consensus.addSigner(signer1, 1, IConsensus.SignatureType.EIP712);

        (address s, uint256 t) = consensus.signerAt(0);
        assertEq(s, signer1);
        assertEq(uint8(t), uint8(IConsensus.SignatureType.EIP712));
    }

    function testSignerAtOutOfBounds() public {
        Consensus consensus = _createConsensus();

        vm.startPrank(admin);
        vm.expectRevert("panic: array out-of-bounds access (0x32)");
        consensus.signerAt(0);

        consensus.addSigner(signer1, 1, IConsensus.SignatureType.EIP712);

        vm.expectRevert("panic: array out-of-bounds access (0x32)");
        consensus.signerAt(1);
    }

    function testCheckEmptySignatures() public {
        Consensus consensus = _createConsensus();

        uint256 pk = uint256(keccak256("private key 2"));
        address signer = vm.addr(pk);

        vm.prank(admin);
        consensus.addSigner(signer, 1, IConsensus.SignatureType.EIP712);

        bytes memory badSig = _sign(keccak256("wrong"), pk);
        IConsensus.Signature[] memory signatures = new IConsensus.Signature[](1);
        signatures[0] = IConsensus.Signature({signer: signer, signature: badSig});

        assert(!consensus.checkSignatures(dummyHash, signatures));
    }

    function testCheckInvalidSigner() public {
        Consensus consensus = _createConsensus();

        uint256 pk = uint256(keccak256("private key 2"));
        address signer = vm.addr(pk);

        vm.prank(admin);
        consensus.addSigner(signer, 1, IConsensus.SignatureType.EIP712);

        bytes memory sig = _sign(keccak256("wrong"), pk);
        IConsensus.Signature[] memory signatures = new IConsensus.Signature[](1);
        signatures[0] = IConsensus.Signature({signer: signer2, signature: sig});

        assert(!consensus.checkSignatures(dummyHash, signatures));
    }

    function testCheckSignatures_EIP712_Valid() public {
        Consensus consensus = _createConsensus();

        uint256 pk = uint256(keccak256("private key 1"));
        address signer = vm.addr(pk);

        vm.prank(admin);
        consensus.addSigner(signer, 1, IConsensus.SignatureType.EIP712);

        bytes memory sig = _sign(dummyHash, pk);
        IConsensus.Signature[] memory signatures = new IConsensus.Signature[](1);
        signatures[0] = IConsensus.Signature({signer: signer, signature: sig});

        assertTrue(consensus.checkSignatures(dummyHash, signatures));

        consensus.requireValidSignatures(dummyHash, signatures);
    }

    function testCheckSignatures_EIP712_MultipleValid(uint128 pk1, uint128 pk2) public {
        vm.assume(pk1 > 0 && pk2 > 0 && pk1 != pk2);

        address signerA = vm.addr(pk1);
        address signerB = vm.addr(pk2);
        vm.assume(signerA < signerB);

        Consensus consensus = _createConsensus();

        vm.startPrank(admin);
        consensus.addSigner(signerA, 1, IConsensus.SignatureType.EIP712);
        consensus.addSigner(signerB, 2, IConsensus.SignatureType.EIP712);
        vm.stopPrank();

        bytes memory sigA = _sign(dummyHash, pk1);
        bytes memory sigB = _sign(dummyHash, pk2);

        IConsensus.Signature[] memory signatures = new IConsensus.Signature[](2);
        signatures[0] = IConsensus.Signature({signer: signerA, signature: sigA});
        signatures[1] = IConsensus.Signature({signer: signerB, signature: sigB});

        assertTrue(consensus.checkSignatures(dummyHash, signatures));
        consensus.requireValidSignatures(dummyHash, signatures);
    }

    function testCheckSignatures_EIP712_Invalid() public {
        Consensus consensus = _createConsensus();

        uint256 pk = uint256(keccak256("private key 2"));
        address signer = vm.addr(pk);

        vm.prank(admin);
        consensus.addSigner(signer, 1, IConsensus.SignatureType.EIP712);

        bytes memory badSig = _sign(keccak256("wrong"), pk);
        IConsensus.Signature[] memory signatures = new IConsensus.Signature[](1);
        signatures[0] = IConsensus.Signature({signer: signer, signature: badSig});

        assertFalse(consensus.checkSignatures(dummyHash, signatures));

        vm.expectRevert(abi.encodeWithSelector(IConsensus.InvalidSignatures.selector, dummyHash, signatures));
        consensus.requireValidSignatures(dummyHash, signatures);
    }

    function testCheckSignatures_EIP712_Invalid_DuplicateSignatures(uint128 pk1, uint128 pk2) public {
        vm.assume(pk1 > 0 && pk2 > 0 && pk1 != pk2);

        Consensus consensus = _createConsensus();

        address signerA = vm.addr(pk1);
        address signerB = vm.addr(pk2);

        vm.startPrank(admin);
        consensus.addSigner(signerA, 1, IConsensus.SignatureType.EIP712);
        consensus.addSigner(signerB, 2, IConsensus.SignatureType.EIP712);
        vm.stopPrank();

        bytes memory sigA = _sign(dummyHash, pk1);

        IConsensus.Signature[] memory signatures = new IConsensus.Signature[](2);

        // Same signature two times
        signatures[0] = IConsensus.Signature({signer: signerA, signature: sigA});
        signatures[1] = IConsensus.Signature({signer: signerA, signature: sigA});

        assertFalse(consensus.checkSignatures(dummyHash, signatures));

        vm.expectRevert(abi.encodeWithSelector(IConsensus.InvalidSignatures.selector, dummyHash, signatures));
        consensus.requireValidSignatures(dummyHash, signatures);
    }

    function testCheckSignatures_EIP712_Invalid_WrongOrder(uint128 pk1, uint128 pk2) public {
        vm.assume(pk1 > 0 && pk2 > 0 && pk1 != pk2);

        address signerA = vm.addr(pk1);
        address signerB = vm.addr(pk2);
        vm.assume(signerA < signerB);

        Consensus consensus = _createConsensus();

        vm.startPrank(admin);
        consensus.addSigner(signerA, 1, IConsensus.SignatureType.EIP712);
        consensus.addSigner(signerB, 2, IConsensus.SignatureType.EIP712);
        vm.stopPrank();

        bytes memory sigA = _sign(dummyHash, pk1);
        bytes memory sigB = _sign(dummyHash, pk2);

        IConsensus.Signature[] memory signatures = new IConsensus.Signature[](2);

        // Wrong order, signerA should be first (signerA < signerB)
        signatures[0] = IConsensus.Signature({signer: signerB, signature: sigB});
        signatures[1] = IConsensus.Signature({signer: signerA, signature: sigA});

        assertFalse(consensus.checkSignatures(dummyHash, signatures));

        vm.expectRevert(abi.encodeWithSelector(IConsensus.InvalidSignatures.selector, dummyHash, signatures));
        consensus.requireValidSignatures(dummyHash, signatures);
    }

    function testCheckSignatures_EIP712_NotEnoughSignatures() public {
        Consensus consensus = _createConsensus();

        uint256 pk1 = uint256(keccak256("private key 1"));
        uint256 pk2 = uint256(keccak256("private key 2"));
        address signerA = vm.addr(pk1);
        address signerB = vm.addr(pk2);

        // Add two signers and set the threshold to 2
        vm.startPrank(admin);
        consensus.addSigner(signerA, 1, IConsensus.SignatureType.EIP712);
        consensus.addSigner(signerB, 2, IConsensus.SignatureType.EIP712); // threshold is now 2
        vm.stopPrank();

        // Provide only one valid signature (below the threshold)
        bytes memory sig1 = _sign(dummyHash, pk1);
        IConsensus.Signature[] memory signatures = new IConsensus.Signature[](1);
        signatures[0] = IConsensus.Signature({signer: signerA, signature: sig1});

        assertFalse(consensus.checkSignatures(dummyHash, signatures));

        vm.expectRevert(abi.encodeWithSelector(IConsensus.InvalidSignatures.selector, dummyHash, signatures));
        consensus.requireValidSignatures(dummyHash, signatures);
    }

    function testCheckSignatures_EIP1271_Valid() public {
        Consensus consensus = _createConsensus();

        address adminEIP1271 = vm.createWallet("adminEIP1271").addr;
        EIP1271Mock mock = new EIP1271Mock(adminEIP1271);

        vm.prank(admin);
        consensus.addSigner(address(mock), 1, IConsensus.SignatureType.EIP1271);

        IConsensus.Signature[] memory signatures = new IConsensus.Signature[](1);
        signatures[0] = IConsensus.Signature({signer: address(mock), signature: "0x1234"});

        bytes32 txHash = keccak256(abi.encode(signatures[0]));

        vm.prank(adminEIP1271);
        mock.sign(txHash);

        assertTrue(consensus.checkSignatures(txHash, signatures));
        consensus.requireValidSignatures(txHash, signatures);
    }

    function testCheckSignatures_EIP1271_Invalid() public {
        Consensus consensus = _createConsensus();

        address adminEIP1271 = vm.createWallet("adminEIP1271").addr;
        EIP1271Mock mock = new EIP1271Mock(adminEIP1271);

        vm.prank(admin);
        consensus.addSigner(address(mock), 1, IConsensus.SignatureType.EIP1271);

        IConsensus.Signature[] memory signatures = new IConsensus.Signature[](1);
        signatures[0] = IConsensus.Signature({signer: address(mock), signature: "0x1234"});

        bytes32 txHash = keccak256(abi.encode(signatures[0]));

        assertFalse(consensus.checkSignatures(txHash, signatures));

        vm.expectRevert(abi.encodeWithSelector(IConsensus.InvalidSignatures.selector, txHash, signatures));
        consensus.requireValidSignatures(txHash, signatures);
    }

    function testCheckSignatures_EIP1271_MultipleValid(uint128 pk1, uint128 pk2) public {
        vm.assume(pk1 > 0 && pk2 > 0 && pk1 != pk2);

        Consensus consensus = _createConsensus();

        // Create separate admin wallets for each EIP-1271 signer
        address adminA = vm.addr(pk1);
        address adminB = vm.addr(pk2);

        // Deploy mock EIP-1271 contracts controlled by the different admins
        EIP1271Mock mockA = new EIP1271Mock(adminA);
        EIP1271Mock mockB = new EIP1271Mock(adminB);

        // Register both signers and set threshold to two
        vm.startPrank(admin);
        consensus.addSigner(address(mockA), 1, IConsensus.SignatureType.EIP1271);
        consensus.addSigner(address(mockB), 2, IConsensus.SignatureType.EIP1271);
        vm.stopPrank();

        // Determine ascending order of the signer addresses as required
        address firstSigner = address(mockA) < address(mockB) ? address(mockA) : address(mockB);
        address secondSigner = address(mockA) < address(mockB) ? address(mockB) : address(mockA);

        IConsensus.Signature[] memory signatures = new IConsensus.Signature[](2);
        signatures[0] = IConsensus.Signature({signer: firstSigner, signature: "0x1234"});
        signatures[1] = IConsensus.Signature({signer: secondSigner, signature: "0x1234"});

        bytes32 txHash = keccak256(abi.encode(signatures[0], signatures[1]));

        // Both admins approve the txHash
        vm.prank(adminA);
        mockA.sign(txHash);
        vm.prank(adminB);
        mockB.sign(txHash);

        assertTrue(consensus.checkSignatures(txHash, signatures));
        consensus.requireValidSignatures(txHash, signatures);
    }

    function testCheckSignatures_EIP1271_Invalid_DuplicateSignatures(uint128 pk1, uint128 pk2) public {
        vm.assume(pk1 > 0 && pk2 > 0 && pk1 != pk2);

        Consensus consensus = _createConsensus();

        address adminA = vm.addr(pk1);
        address adminB = vm.addr(pk2);

        EIP1271Mock mockA = new EIP1271Mock(adminA);
        EIP1271Mock mockB = new EIP1271Mock(adminB);

        vm.startPrank(admin);
        consensus.addSigner(address(mockA), 1, IConsensus.SignatureType.EIP1271);
        consensus.addSigner(address(mockB), 2, IConsensus.SignatureType.EIP1271);
        vm.stopPrank();

        IConsensus.Signature[] memory signatures = new IConsensus.Signature[](2);
        signatures[0] = IConsensus.Signature({signer: address(mockA), signature: "0x1234"});
        signatures[1] = IConsensus.Signature({signer: address(mockA), signature: "0x1234"}); // duplicate signer

        bytes32 txHash = keccak256(abi.encode(signatures[0]));

        vm.prank(adminA);
        mockA.sign(txHash);

        vm.prank(adminB);
        mockB.sign(txHash);

        assertFalse(consensus.checkSignatures(txHash, signatures));

        vm.expectRevert(abi.encodeWithSelector(IConsensus.InvalidSignatures.selector, txHash, signatures));
        consensus.requireValidSignatures(txHash, signatures);
    }

    function testCheckSignatures_EIP1271_Invalid_WrongOrder(uint128 pk1, uint128 pk2) public {
        vm.assume(pk1 > 0 && pk2 > 0 && pk1 != pk2);

        Consensus consensus = _createConsensus();

        address adminA = vm.addr(pk1);
        address adminB = vm.addr(pk2);

        EIP1271Mock mockA = new EIP1271Mock(adminA);
        EIP1271Mock mockB = new EIP1271Mock(adminB);

        vm.startPrank(admin);
        consensus.addSigner(address(mockA), 1, IConsensus.SignatureType.EIP1271);
        consensus.addSigner(address(mockB), 2, IConsensus.SignatureType.EIP1271);
        vm.stopPrank();

        // Determine correct ascending order of addresses
        address signerA = address(mockA);
        address signerB = address(mockB);

        // Prepare signatures array in DESCENDING order to make it invalid
        IConsensus.Signature[] memory signatures = new IConsensus.Signature[](2);
        if (signerA < signerB) {
            signatures[0] = IConsensus.Signature({signer: signerB, signature: "0x1234"});
            signatures[1] = IConsensus.Signature({signer: signerA, signature: "0x1234"});
        } else {
            signatures[0] = IConsensus.Signature({signer: signerA, signature: "0x1234"});
            signatures[1] = IConsensus.Signature({signer: signerB, signature: "0x1234"});
        }

        bytes32 txHash = keccak256(abi.encode(signatures[0], signatures[1]));

        vm.prank(adminA);
        mockA.sign(txHash);
        vm.prank(adminB);
        mockB.sign(txHash);

        assertFalse(consensus.checkSignatures(txHash, signatures));

        vm.expectRevert(abi.encodeWithSelector(IConsensus.InvalidSignatures.selector, txHash, signatures));
        consensus.requireValidSignatures(txHash, signatures);
    }

    function testFuzzSignaturesValid(bool[] calldata isEIP1271) public {
        uint256 signerCount = isEIP1271.length;
        vm.assume(signerCount > 0 && signerCount < 100);

        uint256[] memory signerPks;
        address[] memory signers;
        IConsensus.SignatureType[] memory signatureTypes = new IConsensus.SignatureType[](signerCount);
        for (uint256 i = 0; i < signerCount; i++) {
            if (isEIP1271[i]) {
                signatureTypes[i] = IConsensus.SignatureType.EIP1271;
            } else {
                signatureTypes[i] = IConsensus.SignatureType.EIP712;
            }
        }

        uint256 threshold = 2 * signerCount / 3 + 1;
        if (threshold > signerCount) {
            threshold = signerCount;
        }

        (signerPks, signers, signatureTypes) = generateSortedSigners(signatureTypes);

        Consensus consensus = _createConsensus();

        vm.startPrank(admin);
        for (uint256 i = 0; i < signers.length; i++) {
            consensus.addSigner(signers[i], 1, signatureTypes[i]);
        }
        consensus.setThreshold(threshold);
        vm.stopPrank();

        IConsensus.Signature[] memory signatures = new IConsensus.Signature[](signerCount);

        bytes32 txHash = keccak256(abi.encode(signers, signerCount, threshold, signatures));
        for (uint256 index = 0; index < signers.length; index++) {
            if (signatureTypes[index] == IConsensus.SignatureType.EIP1271) {
                signatures[index] = signEIP_1271(txHash, signers[index]);
            } else {
                signatures[index] = signEIP_712(txHash, signerPks[index]);
            }
        }
        assertTrue(consensus.checkSignatures(txHash, signatures));
    }

    function testFuzzCheckSignaturesInvalidOrder(bool[] calldata isEIP1271, uint8 first, uint8 second) public {
        uint256 signerCount = isEIP1271.length;
        vm.assume(
            signerCount > 0 && signerCount < 256 && first < signerCount && second < signerCount && first != second
        );

        uint256[] memory signerPks;
        address[] memory signers;
        IConsensus.SignatureType[] memory signatureTypes = new IConsensus.SignatureType[](signerCount);
        for (uint256 i = 0; i < signerCount; i++) {
            if (isEIP1271[i]) {
                signatureTypes[i] = IConsensus.SignatureType.EIP1271;
            } else {
                signatureTypes[i] = IConsensus.SignatureType.EIP712;
            }
        }

        uint256 threshold = 2 * signerCount / 3 + 1;
        if (threshold > signerCount) {
            threshold = signerCount;
        }

        (signerPks, signers, signatureTypes) = generateSortedSigners(signatureTypes);

        Consensus consensus = _createConsensus();

        vm.startPrank(admin);
        for (uint256 i = 0; i < signers.length; i++) {
            consensus.addSigner(signers[i], 1, signatureTypes[i]);
        }
        consensus.setThreshold(threshold);
        vm.stopPrank();

        IConsensus.Signature[] memory signatures = new IConsensus.Signature[](signerCount);

        bytes32 txHash = keccak256(abi.encode(signers, signerCount, threshold, signatures));
        for (uint256 index = 0; index < signers.length; index++) {
            if (signatureTypes[index] == IConsensus.SignatureType.EIP1271) {
                signatures[index] = signEIP_1271(txHash, signers[index]);
            } else {
                signatures[index] = signEIP_712(txHash, signerPks[index]);
            }
        }
        // Swap two signatures to create an invalid order
        (signatures[first], signatures[second]) = (signatures[second], signatures[first]);
        assertFalse(consensus.checkSignatures(txHash, signatures));
    }

    function testFuzzCheckSignaturesDuplicates(bool[] calldata isEIP1271, uint8 dupIndex) public {
        uint256 signerCount = isEIP1271.length;
        vm.assume(signerCount > 1 && signerCount < 256 && dupIndex < signerCount);

        uint256[] memory signerPks;
        address[] memory signers;
        IConsensus.SignatureType[] memory signatureTypes = new IConsensus.SignatureType[](signerCount);
        for (uint256 i = 0; i < signerCount; i++) {
            if (isEIP1271[i]) {
                signatureTypes[i] = IConsensus.SignatureType.EIP1271;
            } else {
                signatureTypes[i] = IConsensus.SignatureType.EIP712;
            }
        }

        uint256 threshold = 2 * signerCount / 3 + 1;
        if (threshold > signerCount) {
            threshold = signerCount;
        }

        (signerPks, signers, signatureTypes) = generateSortedSigners(signatureTypes);

        Consensus consensus = _createConsensus();

        vm.startPrank(admin);
        for (uint256 i = 0; i < signers.length; i++) {
            consensus.addSigner(signers[i], 1, signatureTypes[i]);
        }
        consensus.setThreshold(threshold);
        vm.stopPrank();

        IConsensus.Signature[] memory signatures = new IConsensus.Signature[](signerCount);

        bytes32 txHash = keccak256(abi.encode(signers, signerCount, threshold, signatures));
        for (uint256 index = 0; index < signers.length; index++) {
            if (signatureTypes[index] == IConsensus.SignatureType.EIP1271) {
                signatures[index] = signEIP_1271(txHash, signers[index]);
            } else {
                signatures[index] = signEIP_712(txHash, signerPks[index]);
            }
        }
        // Duplicate one signature
        signatures[dupIndex] = dupIndex == 0 ? signatures[dupIndex + 1] : signatures[dupIndex - 1];

        assertFalse(consensus.checkSignatures(txHash, signatures));
    }

    function testFuzzCheckSignaturesInvalidSignature(bool[] calldata isEIP1271, uint8 indexInvalid) public {
        uint256 signerCount = isEIP1271.length;
        vm.assume(signerCount > 1 && signerCount < 256 && indexInvalid < signerCount);

        uint256[] memory signerPks;
        address[] memory signers;
        IConsensus.SignatureType[] memory signatureTypes = new IConsensus.SignatureType[](signerCount);
        for (uint256 i = 0; i < signerCount; i++) {
            if (isEIP1271[i]) {
                signatureTypes[i] = IConsensus.SignatureType.EIP1271;
            } else {
                signatureTypes[i] = IConsensus.SignatureType.EIP712;
            }
        }

        uint256 threshold = 2 * signerCount / 3 + 1;
        if (threshold > signerCount) {
            threshold = signerCount;
        }

        (signerPks, signers, signatureTypes) = generateSortedSigners(signatureTypes);

        Consensus consensus = _createConsensus();

        vm.startPrank(admin);
        for (uint256 i = 0; i < signers.length; i++) {
            consensus.addSigner(signers[i], 1, signatureTypes[i]);
        }
        consensus.setThreshold(threshold);
        vm.stopPrank();

        IConsensus.Signature[] memory signatures = new IConsensus.Signature[](signerCount);
        uint256 invalidSignerPk = uint256(keccak256(abi.encodePacked("invalid signer", indexInvalid)));

        bytes32 txHash = keccak256(abi.encode(signers, signerCount, threshold, signatures));
        for (uint256 index = 0; index < signers.length; index++) {
            if (index != indexInvalid) {
                if (signatureTypes[index] == IConsensus.SignatureType.EIP1271) {
                    signatures[index] = signEIP_1271(txHash, signers[index]);
                } else {
                    signatures[index] = signEIP_712(txHash, signerPks[index]);
                }
            } else {
                if (signatureTypes[index] == IConsensus.SignatureType.EIP1271) {
                    signatures[index] = IConsensus.Signature({signer: signers[index], signature: bytes("signature")});
                } else {
                    signatures[index] = signEIP_712(txHash, signerPks[index]);
                    IConsensus.Signature memory invalidSignature = signEIP_712(txHash, invalidSignerPk);
                    signatures[index].signature = invalidSignature.signature; // Just replace the signature
                }
            }
        }

        assertFalse(consensus.checkSignatures(txHash, signatures));
    }
}
