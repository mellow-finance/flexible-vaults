// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {Offer} from "../../../scripts/common/interfaces/3F/IOfferReceiver.sol";
import {IRequestFactory} from "../../../scripts/common/interfaces/3F/IRequestFactory.sol";

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../factories/IFactoryEntity.sol";

/// @title IThreeFModule
/// @notice Interface for the 3F liquidity module. A Subvault delegates all 3F auction
///         Request interactions to this module: push flow (authorization-based mint),
///         pull flow (signed-offer consume), and exit (burnAll after repayment).
///         The underlying asset is fixed at deployment and all safety checks are enforced here.
interface IThreeFModule is IFactoryEntity {
    // Structs

    /// @dev EIP-7201 namespaced storage layout for the module.
    /// @param subvault             Address of the Subvault that owns this module.
    /// @param whitelist            Address of the RequestWhitelist registry. Fixed after initialization.
    /// @param requestFactory       Address of the 3F RequestFactory. Fixed after initialization.
    ///                             Used to verify a request was deployed by the known factory via isRequest().
    /// @param nonces               Per-request monotonically increasing counters used to cancel
    ///                             pull-flow offers. Incremented by cancelOffer(request); curators
    ///                             use nonces[request] + 1 when constructing offers for that request.
    /// @param isValidSignatureFlag Transient flag set to true during pull() to self-authorize
    ///                             the inner request.consume() call via ERC-1271.
    /// @param activeRequests       Set of Request addresses where this module currently holds a
    ///                             PT/YT position. Added on push/pull, removed on burn.
    ///                             Uses EnumerableSet for O(1) add, remove, and indexed access.
    struct ThreeFModuleStorage {
        address subvault;
        address whitelist;
        address requestFactory;
        mapping(address => uint256) nonces;
        bool isValidSignatureFlag;
        EnumerableSet.AddressSet activeRequests;
    }

    // Errors

    error ZeroValue();
    error NotSubvault();
    error NotAllowedRequest();
    error AssetMismatch();
    error InsufficientPtAuthorization();
    error InsufficientYtAuthorization();
    error InvalidMaker();
    error CallbackNotAllowed();
    error OfferExpired();
    error StaleNonce();
    error ExceedsOfferAmount();
    error InsufficientYt();
    error NotRepaid();
    error WithdrawalNotAllowed();
    error InsufficientOutput();
    error InsufficientBalance();

    // Roles

    /// @notice Role authorised to call push(), pull(), burn(), and cancelOffer().
    function CALLER_ROLE() external view returns (bytes32);

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

    /// @notice Returns true if request passes both factory and whitelist checks.
    /// @dev Equivalent to: requestFactory.isRequest(request) &&
    ///      whitelist.isWhitelisted(request) == WhitelistStatus.Whitelisted.
    ///      Used internally before every interaction with a Request contract.
    /// @param request Address to validate.
    function isRequestAllowed(address request) external view returns (bool);

    /// @notice Returns the PT and YT internal balances credited to this module inside a Request.
    /// @dev Wraps request.balancesOf(address(this)).
    /// @param request Address of the 3F Request contract.
    /// @return pt PT balance held by this module inside the Request.
    /// @return yt YT balance held by this module inside the Request.
    function balancesOf(address request) external view returns (uint128 pt, uint128 yt);

    /// @notice Returns the push-flow mint authorization granted to this module by a Request.
    /// @dev Wraps request.mintAuthorization(address(this)). Curator should call this before push()
    ///      to confirm 3F has issued authorization and to size maxPt / minYt arguments.
    /// @param request Address of the 3F Request contract.
    /// @return ptAmount Maximum PT the module is authorized to mint.
    /// @return ytAmount Minimum YT the Request guarantees in return.
    function mintAuthorization(address request) external view returns (uint128 ptAmount, uint128 ytAmount);

    /// @notice Estimates the underlying asset payout for this module's current PT/YT position.
    /// @dev Calls request.balancesOf(address(this)) then request.convertToAssets(pt, yt).
    ///      Useful for curator to preview the exit value before calling burn().
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
    /// @dev    Iterates activeRequests[offset .. offset+limit), calls convertToAssets on each.
    ///         Use offset/limit to paginate and avoid OOG on large position sets.
    ///         Call activeRequestsCount() first to know the total length.
    /// @param offset Zero-based start index in the active requests array.
    /// @param limit  Maximum number of requests to include in this call.
    /// @return totalAssets Sum of pAssets + yAssets across the requested slice.
    function balance(uint256 offset, uint256 limit) external view returns (uint256 totalAssets);

    /// @notice Returns the current nonce for a given Request. Curators must use nonce(request) + 1
    ///         when constructing pull-flow offers for that request.
    /// @param request Address of the 3F Request contract.
    function nonce(address request) external view returns (uint256);

    /// @notice ERC-1271 validation used during pull() to self-authorize request.consume().
    /// @dev Returns the magic value only when:
    ///      - isValidSignatureFlag is true (we are inside an active pull() call),
    ///      - isRequestAllowed(msg.sender) is true.
    ///      The flag is set immediately before request.consume() and cleared after it returns,
    ///      so this cannot be triggered outside the pull() execution context.
    /// @param hash      EIP-712 offer digest produced by the Request contract.
    /// @param signature Ignored; pass empty bytes.
    /// @return magicValue 0x1626ba7e on success, 0xffffffff otherwise.
    function isValidSignature(bytes32 hash, bytes calldata signature) external view returns (bytes4 magicValue);

    // Mutable functions

    /// @notice Transfers asset from the Subvault into this module.
    /// @dev Only callable by the Subvault.
    /// @param value Amount of asset to receive.
    function pushAssets(uint256 value) external;

    /// @notice Transfers asset from this module back to the Subvault.
    /// @dev Only callable by the Subvault.
    /// @param value Amount of asset to return.
    function pullAssets(uint256 value) external;

    /// @notice Push flow: approves the Request, then mints PT/YT using an off-chain authorization.
    /// @dev Only callable by CALLER_ROLE.
    ///      Checks: isRequestAllowed(request), asset == module asset,
    ///      mintAuthorization(this) covers maxPt and minYt.
    ///      Approves asset to request, calls request.mint(maxPt, minYt), resets approval.
    ///      PT/YT are credited as internal balances to this module inside the Request; no token
    ///      transfer to the Subvault occurs. Redeemable later via burn().
    /// @param request Address of the 3F Request contract.
    /// @param maxPt   Maximum PT amount to commit; reverts if authorized PT < maxPt.
    /// @param minYt   Minimum YT amount to accept; reverts if authorized YT < minYt.
    function push(address request, uint128 maxPt, uint128 minYt) external;

    /// @notice Pull flow: approves the Request, sets the ERC-1271 flag, calls request.consume()
    ///         with an empty signature, then clears the flag.
    /// @dev Only callable by CALLER_ROLE. Marked nonReentrant.
    ///      offer.maker must equal address(this). offer.useCallback must be false.
    ///      Checks: isRequestAllowed(request), asset matches, offer.expiration >= block.timestamp,
    ///      ptAmount <= offer.amount, ytAmount >= minYt.
    ///      Approves ptAmount to request before consume and resets after.
    ///      request.consume() calls back isValidSignature() on this module; the flag makes it return
    ///      the magic value for the duration of the consume call only.
    ///      PT/YT are credited as internal balances to this module inside the Request; no token
    ///      transfer to the Subvault occurs. Redeemable later via burn().
    /// @param request  Address of the 3F Request contract.
    /// @param offer    Offer struct; maker must equal address(this), useCallback must be false.
    /// @param ptAmount PT amount to mint; must be <= offer.amount.
    /// @param minYt    Minimum YT amount to accept from the consume call.
    function pull(address request, Offer calldata offer, uint256 ptAmount, uint256 minYt) external;

    /// @notice Exit flow: redeems all PT/YT balances from a repaid Request.
    /// @dev Only callable by CALLER_ROLE.
    ///      Checks: isRequestAllowed(request), isRepaid(), canWithdraw().
    ///      Calls request.burnAll(address(this), address(this)); assets stay in this module.
    ///      Reverts with InsufficientOutput if pAssets + yAssets < minAssetOut.
    /// @param request     Address of the 3F Request contract to exit.
    /// @param minAssetOut Minimum total asset amount (pAssets + yAssets) to accept.
    function burn(address request, uint256 minAssetOut) external;

    /// @notice Cancels all pending pull-flow offers on a Request by incrementing the module nonce.
    /// @dev Only callable by CALLER_ROLE.
    ///      Checks: isRequestAllowed(request).
    ///      Increments storage nonce, then calls request.setNonce(nonce).
    ///      Any unconsumed offer with a nonce <= the new value becomes permanently invalid.
    /// @param request Address of the 3F Request contract.
    function cancelOffer(address request) external;

    // Events

    event AssetsPushed(uint256 value);
    event AssetsPulled(uint256 value);

    /// @param ptBalance PT internal balance credited to this module inside the Request after mint.
    /// @param ytBalance YT internal balance credited to this module inside the Request after mint.
    event Pushed(address indexed request, uint128 maxPt, uint128 minYt, uint128 ptBalance, uint128 ytBalance);

    /// @param ytAmount YT internal balance credited to this module inside the Request after consume.
    event Pulled(address indexed request, uint256 ptAmount, uint256 ytAmount);

    /// @param ptShares PT shares redeemed.
    /// @param ytShares YT shares redeemed.
    /// @param pAssets  Principal assets received.
    /// @param yAssets  Yield assets received.
    event Burned(address indexed request, uint256 ptShares, uint256 ytShares, uint256 pAssets, uint256 yAssets);
}
