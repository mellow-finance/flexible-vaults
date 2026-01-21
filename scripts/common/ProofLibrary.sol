// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {JsonLibrary} from "./JsonLibrary.sol";
import {VmSafe} from "forge-std/Vm.sol";

import "../../src/permissions/BitmaskVerifier.sol";
import "../../src/permissions/Verifier.sol";

library ProofLibrary {
    function _this() private pure returns (VmSafe) {
        return VmSafe(address(uint160(uint256(keccak256("hevm cheat code")))));
    }

    function storeProofs(
        string memory title,
        bytes32 root,
        IVerifier.VerificationPayload[] memory leaves,
        string[] memory descriptions
    ) internal {
        _this().writeJson(
            JsonLibrary.toJson(title, root, leaves, descriptions),
            string(abi.encodePacked("./scripts/jsons/", title, ".json"))
        );
    }

    function makeBitmask(bool who, bool where, bool value, bool selector, bytes memory callData)
        internal
        pure
        returns (bytes memory bitmask)
    {
        // set first 32 bits based on selector boolean value
        bytes32 orMask = bytes32(bytes4(type(uint32).max));
        bytes32 andMask = bytes32(type(uint256).max) ^ orMask;
        assembly {
            let ptr := add(callData, 0x20)
            let word := mload(ptr)
            if gt(selector, 0) { word := or(word, orMask) }
            if iszero(selector) { word := and(word, andMask) }
            mstore(ptr, word)
        }
        return abi.encodePacked(
            who ? type(uint256).max : uint256(0),
            where ? type(uint256).max : uint256(0),
            value ? type(uint256).max : uint256(0),
            callData
        );
    }

    function makeVerificationPayload(
        BitmaskVerifier bitmaskVerifier,
        address who,
        address where,
        uint256 value,
        bytes memory data,
        bytes memory bitmask
    ) internal pure returns (IVerifier.VerificationPayload memory payload) {
        if (data.length + 0x60 != bitmask.length) {
            revert("Length mismatch");
        }
        bytes32 hash_ = bitmaskVerifier.calculateHash(bitmask, who, where, value, data);
        payload.verificationType = IVerifier.VerificationType.CUSTOM_VERIFIER;
        payload.verificationData =
            abi.encodePacked(bytes32(uint256(uint160(address(bitmaskVerifier)))), abi.encode(hash_, bitmask));
    }

    function makeVerificationPayloadCompact(address who, address where, bytes4 selector)
        internal
        pure
        returns (IVerifier.VerificationPayload memory payload)
    {
        payload.verificationType = IVerifier.VerificationType.MERKLE_COMPACT;
        payload.verificationData = abi.encodePacked(keccak256(abi.encode(who, where, selector)));
    }

    function generateMerkleProofs(IVerifier.VerificationPayload[] memory leaves)
        internal
        pure
        returns (bytes32 root, IVerifier.VerificationPayload[] memory)
    {
        uint256 n = leaves.length;
        if (n == 0) {
            return (bytes32(0), leaves);
        }
        bytes32[] memory tree = new bytes32[](n * 2 - 1);
        bytes32[] memory cache = new bytes32[](n);
        bytes32[] memory sortedHashes = new bytes32[](n);

        for (uint256 i = 0; i < n; i++) {
            bytes32 leaf = keccak256(
                bytes.concat(keccak256(abi.encode(leaves[i].verificationType, keccak256(leaves[i].verificationData))))
            );
            cache[i] = leaf;
            sortedHashes[i] = leaf;
        }
        Arrays.sort(sortedHashes);
        for (uint256 i = 0; i < n; i++) {
            tree[tree.length - 1 - i] = sortedHashes[i];
        }
        for (uint256 i = n; i < 2 * n - 1; i++) {
            uint256 v = tree.length - 1 - i;
            uint256 l = v * 2 + 1;
            uint256 r = v * 2 + 2;
            tree[v] = Hashes.commutativeKeccak256(tree[l], tree[r]);
        }
        root = tree[0];
        for (uint256 i = 0; i < n; i++) {
            uint256 index;
            for (uint256 j = 0; j < n; j++) {
                if (cache[i] == sortedHashes[j]) {
                    index = j;
                    break;
                }
            }
            bytes32[] memory proof = new bytes32[](30);
            uint256 iterator = 0;
            uint256 treeIndex = tree.length - 1 - index;
            while (treeIndex > 0) {
                uint256 siblingIndex = treeIndex;
                if ((treeIndex % 2) == 0) {
                    siblingIndex -= 1;
                } else {
                    siblingIndex += 1;
                }
                proof[iterator++] = tree[siblingIndex];
                treeIndex = (treeIndex - 1) >> 1;
            }
            assembly {
                mstore(proof, iterator)
            }
            leaves[i].proof = proof;
            require(MerkleProof.verify(proof, root, cache[i]), "Invalid proof or tree");
        }
        return (root, leaves);
    }
}
