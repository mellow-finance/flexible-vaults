// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./CustomVerifier.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";

contract BitmaskVerifier is CustomVerifier {
    struct VerificationData {
        bytes32 hash;
        bytes bitmask;
    }

    function verifyCall(
        address who,
        address where,
        uint256 value,
        bytes calldata callData,
        bytes calldata verificationData
    ) public pure override returns (bool) {
        VerificationData memory data = abi.decode(verificationData, (VerificationData));
        bytes memory fullData = abi.encode(who, where, value, callData);
        if (fullData.length != data.bitmask.length) {
            return false;
        }
        bytes32 hash;
        for (uint256 i = 0; i < fullData.length; i++) {
            if (data.bitmask[i] == 0) {
                continue;
            }
            hash = keccak256(abi.encodePacked(hash, (fullData[i] & data.bitmask[i])));
        }
        if (hash != data.hash) {
            return false;
        }
        return true;
    }
}
