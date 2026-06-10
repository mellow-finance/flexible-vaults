// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IHasAsset} from "./IHasAsset.sol";

/// @title IRequestInteractions
/// @author 3F Protocol
/// @notice Interface for interactions with request contracts - pulling funds and repaying.
interface IRequestInteractions is IHasAsset {
    /// @notice Returns whether the request has been repaid.
    /// @return repaid True if the request has been marked as repaid
    function isRepaid() external view returns (bool repaid);

    /// @notice Transfers underlying assets from the contract to the puller.
    /// @param amount The amount of underlying assets to transfer
    /// @param data Additional data to be passed to the puller callback
    function pullFunds(uint256 amount, bytes calldata data) external;

    /// @notice Repays the request by transferring the underlying assets back to the contract.
    /// @param amount The amount of underlying assets to transfer
    function repay(uint256 amount) external;
}
