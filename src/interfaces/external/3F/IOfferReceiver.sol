// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

/// @notice Bridge Facilitator Offer structure for lending assets to the protocol.
/// @param maker The address of the bridge facilitator providing the funds
/// @param amount The principal amount to lend (in asset terms)
/// @param expectedReturn The absolute return expected (principal + expectedReturn will be repaid)
/// @param nonce Sequential number for offer management and cancellation (must be > stored nonce)
/// @param expiration Unix timestamp after which the offer becomes invalid
/// @param useCallback Whether to call the maker's onRequestConsumed callback before pulling funds
struct Offer {
    address maker;
    uint256 amount;
    uint256 expectedReturn;
    uint256 nonce;
    uint256 expiration;
    bool useCallback;
}

/// @title IOfferReceiver
/// @author 3F Protocol
/// @notice Interface for validating and consuming cryptographically signed bridge facilitator offers.
interface IOfferReceiver {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Emitted when a maker's nonce is updated.
    /// @param maker The address whose nonce was updated
    /// @param newNonce The new nonce value
    event NonceUpdated(address indexed maker, uint256 newNonce);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      NONCE MANAGEMENT                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Returns the current nonce for a given maker address.
    /// @param owner The maker address to query the nonce for
    /// @return result The current nonce value stored for the maker
    function nonce(address owner) external view returns (uint256 result);

    /// @notice Allows a maker to manually update their nonce to cancel pending offers.
    /// @param newNonce The new nonce value to set (must be strictly > current nonce)
    function setNonce(uint256 newNonce) external;
}
