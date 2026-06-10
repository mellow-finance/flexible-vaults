// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {Offer} from "./IOfferReceiver.sol";

/// @title IRequestCallback
/// @author 3F Protocol
/// @notice Interface for contracts that want to receive callbacks when their requests are being consumed.
interface IRequestCallback {
    /// @notice Called when a request is being consumed by an offer, before tokens are pulled.
    /// @param offer The offer struct containing all details of the fulfilled offer
    /// @param signature The EIP-712 signature that authorized the offer
    /// @param principal The amount of principal tokens (PT) that will be pulled after the callback
    /// @param yield The amount of yield tokens (YT) that will be pulled after the callback
    function onRequestConsumed(Offer calldata offer, bytes calldata signature, uint256 principal, uint256 yield)
        external;
}
