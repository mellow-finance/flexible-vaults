// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

library SlotLibrary {
    function getSlot(
        string memory contractName,
        string memory deploymentName,
        uint256 deploymentVersion
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            "mellow.flexible-vaults.storage.",
                            contractName,
                            deploymentName,
                            deploymentVersion
                        )
                    )
                ) - 1
            )
        ) & ~bytes32(uint256(0xff));
    }
}
