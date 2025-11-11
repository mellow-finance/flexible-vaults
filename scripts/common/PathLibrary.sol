// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/utils/Strings.sol";

library PathLibrary {
    function getChain() internal view returns (string memory) {
        uint256 id = block.chainid;
        if (id == 1) {
            return "ethereum";
        } else if (id == 42161) {
            return "arbitrum";
        } else if (id == 8453) {
            return "base";
        } else if (id == 9745) {
            return "plasma";
        }
        revert("PathLibrary: unknown chain id");
    }

    function build(address vault, address subvault) internal view returns (string memory) {
        return build(vault, subvault, getChain());
    }

    function build(address vault, address subvault, string memory chain) internal pure returns (string memory) {
        return string.concat(chain, "_", Strings.toHexString(vault), "_", Strings.toHexString(subvault), ".json");
    }
}
