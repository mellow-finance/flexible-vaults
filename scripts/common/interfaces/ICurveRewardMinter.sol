// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface ICurveRewardMinter {
    /// @notice Mint everything which belongs to `msg.sender` and send to them
    function mint(address gauge) external;
}
