// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {Offer} from "../../../scripts/common/interfaces/3F/IOfferReceiver.sol";
import {IRequestCallback} from "../../../scripts/common/interfaces/3F/IRequestCallback.sol";

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../factories/IFactoryEntity.sol";

/// @title IThreeFModule
/// @notice Interface for the 3F liquidity module. A Subvault delegates all 3F auction
///         Request interactions to this module: push flow (authorization-based mint),
///         pull flow (standing ERC-1271 offer consumed by the 3F consumer), and exit
///         (burnAll after repayment). The underlying asset is fixed at deployment and
///         all safety checks are enforced here.
interface IThreeFModule is IFactoryEntity, IRequestCallback {
    // Structs

    /// @dev Per-offer authorization stored when authorizeOffer() is called.
    ///      Keyed by the EIP-712 offer hash. Decremented on each partial fill; deleted when zero.
    /// @param maxPt Remaining PT the module will lend for this offer.
    ///              Must be > 0; used as an existence sentinel (0 means no authorization).
    struct OfferAuthorization {
        uint256 maxPt;
    }

    /// @dev EIP-7201 namespaced storage layout for the module.
    /// @param subvault          Address of the Subvault that owns this module.
    /// @param whitelist         Address of the RequestWhitelist registry. Fixed after initialization.
    /// @param requestFactory    Address of the 3F RequestFactory. Fixed after initialization.
    ///                          Used to verify a request was deployed by the known factory via isRequest().
    /// @param activeRequests    Set of Request addresses where this module currently holds a
    ///                          PT/YT position. Added on push/pull, removed on burn.
    /// @param allowedRequests   Internal per-request allow list maintained by ALLOW_REQUEST_ROLE.
    /// @param authorizedOffers  Standing pull-flow authorizations keyed by EIP-712 offer hash.
    ///                          Set in authorizeOffer(), cleared in onRequestConsumed().
    struct ThreeFModuleStorage {
        address subvault;
        address whitelist;
        address requestFactory;
        EnumerableSet.AddressSet activeRequests;
        mapping(address => bool) allowedRequests;
        mapping(bytes32 => OfferAuthorization) authorizedOffers;
    }

    // Errors

    error ZeroValue();
    error NotSubvault();
    error RequestNotAllowed();
    error RequestNotWhitelisted();
    error AssetMismatch();
    error InsufficientPtAuthorization();
    error InsufficientYtAuthorization();
    error InvalidMaker();
    error CallbackRequired();
    error OfferExpired();
    error StaleNonce();
    error OfferNotAuthorized();
    error ExceedsPtAuthorization();
    error InsufficientYt();
    error NotRepaid();
    error WithdrawalNotAllowed();
    error InsufficientOutput();
    error RequestNotActive();
    error ZeroMinAssetOut();
    error InsufficientBalance();

    // Roles

    /// @notice Role authorised to call push().
    function PUSH_ROLE() external view returns (bytes32);

    /// @notice Role authorised to call pull().
    function PULL_ROLE() external view returns (bytes32);

    /// @notice Role authorised to call burn().
    function BURN_ROLE() external view returns (bytes32);

    /// @notice Role authorised to call allowRequest() and disallowRequest().
    function ALLOW_REQUEST_ROLE() external view returns (bytes32);

    // Immutables

    /// @notice ERC-20 asset this module accepts. Fixed at deployment.
    function asset() external view returns (address);

    // View functions

    /// @notice Returns the Subvault address that owns this module.
    function subvault() external view returns (address);

    /// @notice Returns the RequestWhitelist registry address.
    function whitelist() external view returns (address);

    /// @notice Returns the 3F RequestFactory address.
    function requestFactory() external view returns (address);

    /// @notice Returns true if the request is present in the internal allow list.
    /// @dev Does not check 3F contracts.
    /// @param request Address to validate.
    function isRequestAllowed(address request) external view returns (bool);

    /// @notice Returns true if the request is deployed by the known factory and is whitelisted by 3F.
    /// @dev Equivalent to: requestFactory.isRequest(request) &&
    ///      whitelist.isWhitelisted(request) == WhitelistStatus.Whitelisted.
    /// @param request Address to validate.
    function isRequestWhitelisted(address request) external view returns (bool);

    /// @notice Returns the PT and YT internal balances credited to this module inside a Request.
    /// @dev Wraps request.balancesOf(address(this)).
    /// @param request Address of the 3F Request contract.
    /// @return pt PT balance held by this module inside the Request.
    /// @return yt YT balance held by this module inside the Request.
    function balancesOf(address request) external view returns (uint128 pt, uint128 yt);

    /// @notice Returns the push-flow mint authorization granted to this module by a Request.
    /// @dev Wraps request.mintAuthorization(address(this)).
    /// @param request Address of the 3F Request contract.
    /// @return ptAmount Maximum PT the module is authorized to mint.
    /// @return ytAmount Minimum YT the Request guarantees in return.
    function mintAuthorization(address request) external view returns (uint128 ptAmount, uint128 ytAmount);

    /// @notice Estimates the underlying asset payout for this module's current PT/YT position.
    /// @param request Address of the 3F Request contract.
    /// @return pAssets Expected principal assets on redemption.
    /// @return yAssets Expected yield assets on redemption.
    function convertToAssets(address request) external view returns (uint256 pAssets, uint256 yAssets);

    /// @notice Returns the number of Request contracts where this module currently holds a position.
    function activeRequestsCount() external view returns (uint256);

    /// @notice Returns the Request address at a given index in the active requests list.
    /// @param index Zero-based index into the active requests array.
    function activeRequestAt(uint256 index) external view returns (address);

    /// @notice Returns the total value of all PT/YT positions held by this module, denominated in asset.
    /// @param offset Zero-based start index in the active requests array.
    /// @param limit  Maximum number of requests to include in this call.
    /// @return totalAssets Sum of pAssets + yAssets across the requested slice.
    function balance(uint256 offset, uint256 limit) external view returns (uint256 totalAssets);

    /// @notice Returns the next valid offer nonce for pull-flow offers targeting this module on a Request.
    /// @dev Wraps IOfferReceiver(request).nonce(address(this)) + 1.
    /// @param request Address of the 3F Request contract.
    function nextNonce(address request) external view returns (uint256);

    /// @notice ERC-1271 validation called by the Request during consume().
    /// @dev Returns the magic value only when authorizedOffers[hash].maxPt > 0,
    ///      i.e., the curator has pre-authorized this exact offer via authorizeOffer().
    /// @param hash      EIP-712 offer digest produced by the Request contract.
    /// @param signature Ignored; pass empty bytes.
    /// @return magicValue 0x1626ba7e on success, 0xffffffff otherwise.
    function isValidSignature(bytes32 hash, bytes calldata signature) external view returns (bytes4 magicValue);

    // Mutable functions

    /// @notice Adds a request to the internal allow list.
    /// @dev Only callable by ALLOW_REQUEST_ROLE. Emits RequestAllowed.
    /// @param request Address of the 3F Request contract to allow.
    function allowRequest(address request) external;

    /// @notice Removes a request from the internal allow list.
    /// @dev Only callable by ALLOW_REQUEST_ROLE. Emits RequestDisallowed.
    /// @param request Address of the 3F Request contract to disallow.
    function disallowRequest(address request) external;

    /// @notice Transfers asset from the Subvault into this module.
    /// @dev Only callable by the Subvault.
    /// @param value Amount of asset to receive.
    function pushAssets(uint256 value) external;

    /// @notice Transfers asset from this module back to the Subvault.
    /// @dev Only callable by the Subvault.
    /// @param value Amount of asset to return.
    function pullAssets(uint256 value) external;

    /// @notice Push flow: approves the Request, then mints PT/YT using an off-chain authorization.
    /// @dev Only callable by PUSH_ROLE.
    ///      Checks: isRequestAllowed(request), asset == module asset,
    ///      mintAuthorization(this) covers maxPt and minYt, module balance >= authPt.
    ///      Approves asset to request, calls request.mint(maxPt, minYt), resets approval.
    /// @param request Address of the 3F Request contract.
    /// @param maxPt   Maximum PT amount to commit; reverts if authorized PT < maxPt.
    /// @param minYt   Minimum YT amount to accept; reverts if authorized YT < minYt.
    function push(address request, uint128 maxPt, uint128 minYt) external;

    /// @notice Pull flow step 1: constructs and stores an ERC-1271 authorization for a new offer.
    /// @dev Only callable by PULL_ROLE.
    ///      Checks: isRequestAllowed(request), asset matches, amount > 0, duration > 0.
    ///      Constructs the Offer internally: maker=address(this), nonce=nextNonce(request),
    ///      expiration=block.timestamp+duration, useCallback=true.
    ///      Stores OfferAuthorization{maxPt=amount} keyed by the EIP-712 offer hash.
    ///      The 3F consumer then calls request.consume(offer, "", ptAmount) independently;
    ///      the Request validates isValidSignature and calls back onRequestConsumed().
    /// @param request        Address of the 3F Request contract.
    /// @param amount         Maximum PT the module is willing to lend (= Offer.amount); must be > 0.
    /// @param expectedReturn Total YT expected for a full fill (= Offer.expectedReturn).
    /// @param duration       Offer validity window in seconds; expiration = block.timestamp + duration.
    function authorizeOffer(address request, uint256 amount, uint256 expectedReturn, uint256 duration) external;

    /// @notice Cancels all pending offers for a request by advancing its on-chain nonce.
    /// @dev Only callable by PULL_ROLE. Calls request.setNonce(nonce(address(this)) + 1).
    ///      Any stored authorizations with nonces <= the new nonce become unreachable via consume().
    ///      Emits OfferCancelled.
    /// @param request Address of the 3F Request contract.
    function cancelOffer(address request) external;

    /// @notice Exit flow: redeems all PT/YT balances from a repaid Request.
    /// @dev Only callable by BURN_ROLE.
    ///      Checks: isRequestAllowed(request), request is active, minAssetOut > 0,
    ///      isRepaid(), canWithdraw().
    ///      Calls request.burnAll(address(this), address(this)); assets stay in this module.
    /// @param request     Address of the 3F Request contract to exit.
    /// @param minAssetOut Minimum total asset amount (pAssets + yAssets) to accept.
    function burn(address request, uint256 minAssetOut) external;

    // Events

    event AssetsPushed(uint256 value);
    event AssetsPulled(uint256 value);

    event RequestAllowed(address indexed request);
    event RequestDisallowed(address indexed request);

    /// @notice Emitted when a request is added to the active positions set for the first time.
    event RequestActivated(address indexed request);
    /// @notice Emitted when a request is removed from the active positions set after all balances are redeemed.
    event RequestDeactivated(address indexed request);

    /// @param ptMinted PT amount newly minted to this module in this call (balanceAfter - balanceBefore).
    /// @param ytMinted YT amount newly minted to this module in this call (balanceAfter - balanceBefore).
    event Pushed(address indexed request, uint128 maxPt, uint128 minYt, uint128 ptMinted, uint128 ytMinted);

    /// @param offerHash     EIP-712 hash of the constructed offer.
    /// @param amount        Offer.amount — max PT the consumer may pull per consume call.
    /// @param expectedReturn Offer.expectedReturn — total YT for a full fill.
    /// @param nonce         Offer.nonce assigned by the module.
    /// @param expiration    Offer.expiration computed as block.timestamp + duration.
    event OfferAuthorized(
        address indexed request,
        bytes32 indexed offerHash,
        uint256 amount,
        uint256 expectedReturn,
        uint256 nonce,
        uint256 expiration
    );

    /// @param newNonce The nonce value that was set on the Request to invalidate pending offers.
    event OfferCancelled(address indexed request, uint256 newNonce);

    /// @param principal PT amount pulled (approved to the Request in onRequestConsumed).
    /// @param yield     YT amount credited to this module by the Request.
    event Pulled(address indexed request, uint256 principal, uint256 yield);

    /// @param ptShares PT shares redeemed.
    /// @param ytShares YT shares redeemed.
    /// @param pAssets  Principal assets received.
    /// @param yAssets  Yield assets received.
    event Burned(address indexed request, uint256 ptShares, uint256 ytShares, uint256 pAssets, uint256 yAssets);
}
