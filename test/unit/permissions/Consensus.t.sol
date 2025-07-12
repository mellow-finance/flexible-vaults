// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../Imports.sol";

contract EIP1271Mock is IERC1271 {
    bytes4 internal _response;
    address private _admin;
    mapping(bytes32 => bool) private validSignatures;

    constructor(address admin, bytes4 response) {
        _admin = admin;
        _response = response;
    }

    function sign(bytes32 txHash) external {
        require(msg.sender == _admin, "admin");
        validSignatures[txHash] = true;
    }

    function isValidSignature(bytes32 txHash, bytes memory) external view override returns (bytes4) {
        if (validSignatures[txHash]) {
            return _response;
        }
        return bytes4(0);
    }

    function test() external {}
}

contract ConsensusTest is Test {
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

    function testCheckSignatures_EIP1271_Valid() public {
        Consensus consensus = _createConsensus();

        address adminEIP1271 = vm.createWallet("adminEIP1271").addr;
        EIP1271Mock mock = new EIP1271Mock(adminEIP1271, IERC1271.isValidSignature.selector);

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
        EIP1271Mock mock = new EIP1271Mock(adminEIP1271, IERC1271.isValidSignature.selector);

        vm.prank(admin);
        consensus.addSigner(address(mock), 1, IConsensus.SignatureType.EIP1271);

        IConsensus.Signature[] memory signatures = new IConsensus.Signature[](1);
        signatures[0] = IConsensus.Signature({signer: address(mock), signature: "0x1234"});

        bytes32 txHash = keccak256(abi.encode(signatures[0]));

        assertFalse(consensus.checkSignatures(txHash, signatures));

        vm.expectRevert(abi.encodeWithSelector(IConsensus.InvalidSignatures.selector, txHash, signatures));
        consensus.requireValidSignatures(txHash, signatures);
    }
}
