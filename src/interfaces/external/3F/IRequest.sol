// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {Offer} from "./IOfferReceiver.sol";
import {IRequestInteractions} from "./IRequestInteractions.sol";

/// @title IRequest
/// @author 3F Protocol
/// @notice Interface for the Request contract that manages funding requests with dual-token (PT/YT) issuance.
interface IRequest is IRequestInteractions {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Emitted when the contract is marked as repaid, enabling withdrawals.
    /// @param amount The total amount of underlying assets available for redemption
    event Repaid(uint256 amount);

    /// @notice Emitted when funds are pulled from the contract.
    /// @param puller The address that pulled the funds
    /// @param amount The amount of underlying assets pulled
    event FundsPulled(address indexed puller, uint256 amount);

    /// @notice Emitted when minting authorization is granted to an address.
    /// @param to The address receiving minting authorization
    /// @param ptAmount The amount of PT tokens authorized to mint
    /// @param ytAmount The amount of YT tokens authorized to mint
    event AuthorizedMinting(address indexed to, uint256 ptAmount, uint256 ytAmount);

    /// @notice Emitted when the mint-to-repaid delay is updated.
    /// @param mintToRepaidDelay The new delay duration (seconds).
    event MintToRepaidDelaySet(uint40 mintToRepaidDelay);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           ADMIN                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Marks the request as repaid, enabling withdrawals and redemptions.
    /// @param minBalance The minimum asset balance the contract must hold; reverts if below.
    /// @param maxBalance The maximum asset balance the contract must hold; reverts if above.
    ///                   Pass type(uint256).max to skip the upper bound check.
    function setRepaid(uint256 minBalance, uint256 maxBalance) external;

    /// @notice Syncs the repaid status after the repayment deadline has passed.
    /// @return repaid Whether the request is now marked as repaid
    function syncRepaidStatus() external returns (bool repaid);

    /// @notice Returns the timestamp of the last mint() or consume() call.
    /// @return The last mint timestamp (0 if no minting has occurred).
    function lastMintTimestamp() external view returns (uint40);

    /// @notice Returns the mint-to-repaid delay duration.
    /// @return The minimum delay (seconds) between the last mint/consume and setRepaid(uint256).
    function mintToRepaidDelay() external view returns (uint40);

    /// @notice Returns the earliest timestamp at which setRepaid(uint256) can be called.
    /// @return The timestamp at which setRepaid(uint256) becomes available (0 if no minting has occurred).
    function repaidAvailableAt() external view returns (uint40);

    /// @notice Sets the mint-to-repaid delay duration.
    /// @param mintToRepaidDelay_ The new delay (seconds).
    function setMintToRepaidDelay(uint40 mintToRepaidDelay_) external;

    /// @notice Authorizes an address to mint a specific amount of PT and YT tokens.
    /// @param to The address to authorize for minting
    /// @param ptAmount The amount of PT tokens the address can mint
    /// @param ytAmount The amount of YT tokens the address can mint
    function authorizeMinting(address to, uint128 ptAmount, uint128 ytAmount) external;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          MINTING                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Returns the mint authorization for a given address.
    /// @param account The address to query mint authorization for
    /// @return ptAmount The amount of PT tokens the address is authorized to mint
    /// @return ytAmount The amount of YT tokens the address is authorized to mint
    function mintAuthorization(address account) external view returns (uint128 ptAmount, uint128 ytAmount);

    /// @notice Mints PT and YT tokens to the caller using their authorized amounts.
    /// @param maxPt The maximum PT amount the caller accepts (reverts if authorized PT > maxPt).
    ///             Pass type(uint128).max to skip the PT cap check.
    /// @param minYt The minimum YT amount the caller expects (reverts if authorized YT < minYt).
    function mint(uint128 maxPt, uint128 minYt) external;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     OFFER CONSUMPTION                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Consumes a signed offer by minting PT/YT tokens to the offer maker.
    /// @param offer The signed offer struct containing maker, amount, expectedReturn, and other details
    /// @param signature The EIP-712 signature authorizing the offer
    /// @param ptAmount The amount of PT tokens to mint (must be <= offer.amount)
    /// @return ytAmount The amount of YT tokens minted to the offer maker
    function consume(Offer calldata offer, bytes calldata signature, uint256 ptAmount)
        external
        returns (uint256 ytAmount);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        REDEMPTION                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Returns whether the request allows withdrawals.
    /// @return True if withdrawals are currently permitted (repaid and any timelock elapsed).
    function canWithdraw() external view returns (bool);

    /// @notice Returns the PT and YT balances credited to an account inside this Request.
    /// @param account The address to query.
    /// @return pt The principal token balance.
    /// @return yt The yield token balance.
    function balancesOf(address account) external view returns (uint128 pt, uint128 yt);

    /// @notice Converts PT and YT share amounts to the equivalent underlying asset amounts.
    /// @param ptShares Amount of PT shares to convert.
    /// @param ytShares Amount of YT shares to convert.
    /// @return pAssets Underlying asset value of the PT shares.
    /// @return yAssets Underlying asset value of the YT shares.
    function convertToAssets(uint256 ptShares, uint256 ytShares)
        external
        view
        returns (uint256 pAssets, uint256 yAssets);

    /// @notice Returns the base name used for PT/YT tokens and EIP-712 domain construction.
    function name() external view returns (string memory);

    /// @notice Redeems all PT and YT balances of owner and sends the underlying assets to receiver.
    /// @param owner    The address whose PT/YT balances are burned.
    /// @param receiver The address that receives the underlying assets.
    /// @return ptShares PT shares burned.
    /// @return ytShares YT shares burned.
    /// @return pAssets  Principal assets sent to receiver.
    /// @return yAssets  Yield assets sent to receiver.
    function burnAll(address owner, address receiver)
        external
        returns (uint256 ptShares, uint256 ytShares, uint256 pAssets, uint256 yAssets);
}
