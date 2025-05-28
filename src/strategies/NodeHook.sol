// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/tokens/IWETH.sol";
import "../interfaces/tokens/IWSTETH.sol";

import "../modules/NodeModule.sol";
import "./DepositHook.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract NodeHook is DepositHook {
    function hook(address asset, uint256 assets)
        external
        override
        onlyDelegateCall
        returns (address, uint256)
    {
        // NodeModule nodeModule = NodeModule(payable(this));
        /*
            delegate provided stake into childs according to the limits?
            or at least some order
            idk
        */
    }
}
