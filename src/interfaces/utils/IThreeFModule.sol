// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IOfferReceiver, Offer} from "../../../scripts/common/interfaces/3F/IOfferReceiver.sol";
import {IRequest} from "../../../scripts/common/interfaces/3F/IRequest.sol";
import {IRequestCallback} from "../../../scripts/common/interfaces/3F/IRequestCallback.sol";
import {IRequestFactory} from "../../../scripts/common/interfaces/3F/IRequestFactory.sol";
import {IWhitelist} from "../../../scripts/common/interfaces/3F/IWhitelist.sol";

import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../factories/IFactoryEntity.sol";

/// @title IThreeFModule
/// @notice Interface for the 3F liquidity module. A Subvault delegates all 3F auction
///         Request interactions to this module: push flow (authorization-based mint),
///         pull flow (standing ERC-1271 offer consumed by the 3F consumer), and exit
///         (burnAll after repayment). The underlying asset is fixed at deployment and
///         all safety checks are enforced here.
interface IThreeFModule is IFactoryEntity, IRequestCallback, IERC1271 {
    // Structs

    /// @dev Per-offer authorization stored when authorizeOffer() is called.
    ///      Keyed by the EIP-712 offer hash. Deleted unconditionally in onRequestConsumed() because
    ///      the 3F nonce advances on every consume, making the same offer hash unreplayable.
    /// @param maxPt  Maximum PT the module will lend for this offer.
    ///               Must be > 0; used as an existence sentinel (0 means no authorization).
    /// @param minYt  Minimum YT for a full fill (= Offer.expectedReturn).
    ///               Yield floor for a partial fill: mulDiv(minYt, principal, offer.amount).
    struct OfferAuthorization {
        uint256 maxPt;
        uint256 minYt;
    }

    /// @dev EIP-7201 namespaced storage layout for the module.
    /// @param subvault          Address of the Subvault that owns this module.
    /// @param whitelist         Address of the RequestWhitelist registry. Fixed after initialization.
    /// @param requestFactory    Address of the 3F RequestFactory. Fixed after initialization.
    ///                          Used to verify a request was deployed by the known factory via isRequest().
    /// @param allowedRequests   Enumerable set of allowed Request addresses.
    ///                          Maintained by ALLOW_REQUEST_ROLE. Requests are validated (asset,
    ///                          whitelist) at allow-time and re-checked at every operation.
    /// @param authorizedOffers  Standing pull-flow authorizations keyed by EIP-712 offer hash.
    ///                          Set in authorizeOffer(), cleared in onRequestConsumed().
    struct ThreeFModuleStorage {
        address subvault;
        address whitelist;
        address requestFactory;
        EnumerableSet.AddressSet allowedRequests;
        mapping(bytes32 => OfferAuthorization) authorizedOffers;
    }

    // Errors

    error ZeroValue();
    error NotSubvault();
    error RequestNotAllowed();
    error RequestWrongFactory();
    error RequestNotWhitelisted();
    error RequestAlreadyAllowed();
    error AssetMismatch();
    error InsufficientAuthorization();
    error SlippageExceeded();
    error OfferNotAuthorized();
    error ExceedsPtAuthorization();
    error InsufficientYt();
    error NotRepaid();
    error WithdrawalNotAllowed();
    error InsufficientBalance();

    // Roles

    /// @notice Role authorised to call push().
    function PUSH_ROLE() external view returns (bytes32);

    /// @notice Role authorised to call authorizeOffer() and cancelOffer().
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

    /// @notice Returns true if the request is present in the internal allow set.
    /// @dev Does not check 3F contracts.
    /// @param request Address to validate.
    function isRequestAllowed(address request) external view returns (bool);

    /// @notice Returns true if the request is deployed by the known factory and is whitelisted by 3F.
    /// @param request Address to validate.
    function isRequestWhitelisted(address request) external view returns (bool);

    /// @notice Returns the number of requests in the internal allow set.
    function allowedRequestsCount() external view returns (uint256);

    /// @notice Returns the allowed request address at a given index.
    /// @param index Zero-based index into the allowed requests set.
    function allowedRequestAt(uint256 index) external view returns (address);

    /// @notice Returns the next valid offer nonce for pull-flow offers targeting this module on a Request.
    /// @dev Wraps IOfferReceiver(request).nonce(address(this)) + 1.
    /// @param request Address of the 3F Request contract.
    function nextNonce(address request) external view returns (uint256);

    // Mutable functions

    /// @notice Adds a request to the internal allow set after validating asset and whitelist.
    /// @dev Only callable by ALLOW_REQUEST_ROLE. Validates asset match and whitelist status.
    ///      Reverts RequestAlreadyAllowed if the request is already in the set.
    ///      Emits RequestAllowed on success.
    /// @param request Address of the 3F Request contract to allow.
    function allowRequest(address request) external;

    /// @notice Removes a request from the internal allow set.
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

    /// @notice Push flow: mints PT/YT using the module's pre-granted authorization from the Request.
    /// @dev Only callable by PUSH_ROLE.
    ///
    ///      Reads (maxPt, minYt) = mintAuthorization(this) and passes them directly to mint().
    ///      Request.mint slippage check: if (ptMintAuth > maxPt || ytMintAuth < minYt) revert
    ///      SlippageExceeded. Within a single atomic transaction both sides resolve to the same
    ///      storage values, so the 3F-side check is a tautological no-op.
    ///
    ///      Authorization is one-time use: Request.mint clears it on success, so a second push()
    ///      on the same request returns (0, 0) and reverts InsufficientAuthorization.
    ///
    ///      Post-conditions verified defensively after mint() returns:
    ///      - ptMinted <= maxPt  )
    ///      - ytMinted >= minYt  ) revert SlippageExceeded if violated
    ///
    /// @param request Address of the 3F Request contract.
    function push(address request) external;

    /// @notice Pull flow step 1: constructs and stores an ERC-1271 authorization for a new offer.
    /// @dev Only callable by PULL_ROLE.
    ///      Constructs the Offer internally: maker=address(this), nonce=nextNonce(request),
    ///      expiration=block.timestamp+duration, useCallback=true.
    ///      offer.amount = maxPt, offer.expectedReturn = minYt.
    ///      Stores OfferAuthorization{maxPt, minYt} keyed by the EIP-712 offer hash.
    ///      Since yield = mulDiv(expectedReturn, ptAmount, amount) = mulDiv(minYt, principal, maxPt),
    ///      minYt is both the Offer.expectedReturn and the yield floor per full fill.
    /// @param request  Address of the 3F Request contract.
    /// @param maxPt    Maximum PT the module will lend (= Offer.amount); must be > 0.
    /// @param minYt    Minimum YT for a full fill (= Offer.expectedReturn). Yield for any fill is
    ///                 proportional: yield = mulDiv(minYt, principal, maxPt).
    /// @param duration Offer validity window in seconds; expiration = block.timestamp + duration.
    /// @return offer      The Offer struct constructed internally by the module.
    /// @return offerHash  EIP-712 hash of the offer; also the key in authorizedOffers storage.
    function authorizeOffer(address request, uint256 maxPt, uint256 minYt, uint256 duration)
        external
        returns (Offer memory offer, bytes32 offerHash);

    /// @notice Cancels all pending offers for a request by advancing its on-chain nonce.
    /// @dev Only callable by PULL_ROLE. Calls request.setNonce(nonce(address(this)) + 1).
    ///      Emits OfferCancelled.
    /// @param request Address of the 3F Request contract.
    function cancelOffer(address request) external;

    /// @notice Exit flow: redeems all PT/YT balances from a repaid Request.
    /// @dev Only callable by BURN_ROLE.
    ///      Checks: asset match, factory membership (isRequest()), isRepaid(), canWithdraw().
    ///      Does NOT require the request to be in the internal allow set.
    ///      Calls request.burnAll(address(this), address(this)); assets stay in this module.
    /// @param request Address of the 3F Request contract to exit.
    function burn(address request) external;

    // Events

    event AssetsPushed(uint256 value);
    event AssetsPulled(uint256 value);

    event RequestAllowed(address indexed request);
    event RequestDisallowed(address indexed request);

    /// @param maxPt    Authorization PT cap read from mintAuthorization (= amount deposited).
    /// @param minYt    Authorization YT floor read from mintAuthorization.
    /// @param ptMinted PT credited to this module after mint().
    /// @param ytMinted YT credited to this module after mint().
    event Pushed(address indexed request, uint128 maxPt, uint128 minYt, uint128 ptMinted, uint128 ytMinted);

    /// @param offerHash EIP-712 hash of the constructed offer; key in authorizedOffers storage.
    /// @param offer     The full Offer struct constructed by the module.
    event OfferAuthorized(address indexed request, bytes32 indexed offerHash, Offer offer);

    /// @param newNonce The nonce set on the Request to invalidate all pending offers for this maker.
    event OfferCancelled(address indexed request, uint256 newNonce);

    /// @param offerHash EIP-712 hash of the consumed offer.
    /// @param offer     The full Offer struct as received in the callback.
    /// @param principal PT amount transferred from this module to the Request.
    /// @param yield     YT amount the 3F consumer credited to this module.
    event OfferConsumed(
        address indexed request, bytes32 indexed offerHash, Offer offer, uint256 principal, uint256 yield
    );

    /// @param ptShares PT shares redeemed.
    /// @param ytShares YT shares redeemed.
    /// @param pAssets  Principal assets received.
    /// @param yAssets  Yield assets received.
    event Burned(address indexed request, uint256 ptShares, uint256 ytShares, uint256 pAssets, uint256 yAssets);
}
