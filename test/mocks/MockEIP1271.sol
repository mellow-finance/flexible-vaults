// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/interfaces/IERC1271.sol";

contract EIP1271Mock is IERC1271 {
    address private immutable _admin;
    mapping(bytes32 => bool) private validSignatures;

    constructor(address admin_) {
        _admin = admin_;
    }

    function admin() external view returns (address) {
        return _admin;
    }

    function sign(bytes32 txHash) external {
        require(msg.sender == _admin, "admin");
        validSignatures[txHash] = true;
    }

    function isValidSignature(bytes32 txHash, bytes memory) external view override returns (bytes4) {
        if (validSignatures[txHash]) {
            return IERC1271.isValidSignature.selector;
        }
        return bytes4(0);
    }

    function test() external {}
}
