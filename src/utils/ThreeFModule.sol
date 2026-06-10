// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/utils/IThreeFModule.sol";
import "../libraries/SlotLibrary.sol";
import "../libraries/TransferLibrary.sol";
import "../permissions/MellowACL.sol";

contract ThreeFModule is IThreeFModule, MellowACL, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;
    using Math for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    //  keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
    bytes32 private constant _DOMAIN_TYPEHASH = 0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;

    // keccak256("Offer(address maker,uint256 amount,uint256 expectedReturn,uint256 nonce,uint256 expiration,bool useCallback)");
    bytes32 private constant _OFFER_TYPEHASH = 0x3ded0c963332962cf2d273c8fb4f3e69f4ef33407ca72484fcebb56263ad0664;

    /// @notice Role authorised to call push().
    bytes32 public constant PUSH_ROLE = keccak256("utils.ThreeFModule.PUSH_ROLE");

    /// @notice Role authorised to call authorizeOffer() and cancelOffers().
    bytes32 public constant PULL_ROLE = keccak256("utils.ThreeFModule.PULL_ROLE");

    /// @notice Role authorised to call burn().
    bytes32 public constant BURN_ROLE = keccak256("utils.ThreeFModule.BURN_ROLE");

    /// @notice Role authorised to call allowRequest() and disallowRequest().
    bytes32 public constant ALLOW_REQUEST_ROLE = keccak256("utils.ThreeFModule.ALLOW_REQUEST_ROLE");

    /// @inheritdoc IThreeFModule
    address public immutable asset;

    bytes32 private immutable _threeFModuleStorageSlot;

    constructor(string memory name_, uint256 version_, address asset_) MellowACL(name_, version_) {
        if (asset_ == address(0)) {
            revert ZeroValue();
        }
        asset = asset_;
        _threeFModuleStorageSlot = SlotLibrary.getSlot("ThreeFModule", name_, version_);
    }

    modifier onlySubvault() {
        if (_msgSender() != _threeFModuleStorage().subvault) {
            revert NotSubvault();
        }
        _;
    }

    // View functions

    /// @inheritdoc IThreeFModule
    function subvault() public view returns (address) {
        return _threeFModuleStorage().subvault;
    }

    /// @inheritdoc IThreeFModule
    function whitelist() public view returns (address) {
        return _threeFModuleStorage().whitelist;
    }

    /// @inheritdoc IThreeFModule
    function requestFactory() public view returns (address) {
        return _threeFModuleStorage().requestFactory;
    }

    /// @inheritdoc IThreeFModule
    function isRequestAllowed(address request) public view returns (bool) {
        return _threeFModuleStorage().allowedRequests.contains(request);
    }

    /// @inheritdoc IThreeFModule
    function allowedRequestsCount() public view returns (uint256) {
        return _threeFModuleStorage().allowedRequests.length();
    }

    /// @inheritdoc IThreeFModule
    function allowedRequestAt(uint256 index) public view returns (address) {
        return _threeFModuleStorage().allowedRequests.at(index);
    }

    /// @inheritdoc IThreeFModule
    function isRequestWhitelisted(address request) public view returns (bool) {
        ThreeFModuleStorage storage $ = _threeFModuleStorage();
        return IRequestFactory($.requestFactory).isRequest(request)
            && IWhitelist($.whitelist).isWhitelisted(request) == IWhitelist.WhitelistStatus.Whitelisted;
    }

    /// @inheritdoc IThreeFModule
    function currentNonce(address request) public view returns (uint256) {
        return IOfferReceiver(request).nonce(address(this));
    }

    /// @inheritdoc IThreeFModule
    function lastIssuedNonce(address request) public view returns (uint256) {
        return _threeFModuleStorage().lastIssuedNonce[request];
    }

    /// @inheritdoc IERC1271
    function isValidSignature(bytes32 hash, bytes calldata) external view returns (bytes4) {
        if (_threeFModuleStorage().authorizedOffers[hash].maxPt > 0) {
            return IERC1271.isValidSignature.selector;
        }
        return bytes4(0xffffffff);
    }

    // Mutable functions

    /// @inheritdoc IFactoryEntity
    function initialize(bytes calldata data) external initializer {
        (
            address admin,
            address subvault_,
            address whitelist_,
            address requestFactory_,
            address[] memory holders,
            bytes32[] memory roles
        ) = abi.decode(data, (address, address, address, address, address[], bytes32[]));
        if (admin == address(0) || subvault_ == address(0) || whitelist_ == address(0) || requestFactory_ == address(0))
        {
            revert ZeroValue();
        }
        ThreeFModuleStorage storage $ = _threeFModuleStorage();
        $.subvault = subvault_;
        $.whitelist = whitelist_;
        $.requestFactory = requestFactory_;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        for (uint256 i = 0; i < holders.length; i++) {
            if (holders[i] == address(0) || roles[i] == bytes32(0)) {
                revert ZeroValue();
            }
            _grantRole(roles[i], holders[i]);
        }
        emit Initialized(data);
    }

    /// @inheritdoc IThreeFModule
    function allowRequest(address request) external onlyRole(ALLOW_REQUEST_ROLE) {
        if (IRequest(request).asset() != asset) {
            revert AssetMismatch();
        }
        if (!isRequestWhitelisted(request)) {
            revert RequestNotWhitelisted();
        }
        if (!_threeFModuleStorage().allowedRequests.add(request)) {
            revert RequestAlreadyAllowed();
        }
        emit RequestAllowed(request);
    }

    /// @inheritdoc IThreeFModule
    function disallowRequest(address request) external nonReentrant onlyRole(ALLOW_REQUEST_ROLE) {
        ThreeFModuleStorage storage $ = _threeFModuleStorage();
        if (!$.allowedRequests.remove(request)) {
            revert RequestNotAllowed();
        }
        _cancelOffers(request, $.lastIssuedNonce[request]);
        emit RequestDisallowed(request);
    }

    /// @inheritdoc IThreeFModule
    function pushAssets(uint256 value) external onlySubvault nonReentrant {
        TransferLibrary.receiveAssets(asset, _msgSender(), value);
        emit AssetsPushed(value);
    }

    /// @inheritdoc IThreeFModule
    function pullAssets(uint256 value) external onlySubvault nonReentrant {
        TransferLibrary.sendAssets(asset, _msgSender(), value);
        emit AssetsPulled(value);
    }

    /// @inheritdoc IThreeFModule
    function push(address request, uint128 maxPt, uint128 minYt) external nonReentrant onlyRole(PUSH_ROLE) {
        _checkRequest(request);
        address _this = address(this);
        (uint128 authPt, uint128 authYt) = IRequest(request).mintAuthorization(_this);
        // (0,0) means no authorization exists; mint() would no-op silently without this guard
        if (authPt == 0 && authYt == 0) {
            revert InsufficientAuthorization();
        }
        if (authPt > maxPt || authYt < minYt) {
            revert InsufficientAuthorization();
        }
        if (TransferLibrary.balanceOf(asset, _this) < authPt) {
            revert InsufficientBalance();
        }
        (uint128 ptBefore, uint128 ytBefore) = IRequest(request).balancesOf(_this);
        IERC20(asset).forceApprove(request, authPt);
        IRequest(request).mint(authPt, authYt);
        IERC20(asset).forceApprove(request, 0);
        (uint128 ptAfter, uint128 ytAfter) = IRequest(request).balancesOf(_this);
        uint128 ptMinted = ptAfter - ptBefore;
        uint128 ytMinted = ytAfter - ytBefore;
        if (ptMinted > authPt || ytMinted < authYt) {
            revert SlippageExceeded();
        }
        emit Pushed(request, authPt, authYt, ptMinted, ytMinted);
    }

    /// @inheritdoc IThreeFModule
    function authorizeOffer(address request, uint256 maxPt, uint256 minYt, uint256 duration)
        external
        nonReentrant
        onlyRole(PULL_ROLE)
        returns (Offer memory offer, bytes32 offerHash)
    {
        _checkRequest(request);
        if (IRequest(request).asset() != asset) {
            revert AssetMismatch();
        }
        if (maxPt == 0 || duration == 0) {
            revert ZeroValue();
        }
        ThreeFModuleStorage storage $ = _threeFModuleStorage();
        uint256 offerNonce = $.lastIssuedNonce[request].max(IOfferReceiver(request).nonce(address(this))) + 1;
        $.lastIssuedNonce[request] = offerNonce;
        uint256 expiration = block.timestamp + duration;
        offer = Offer({
            maker: address(this),
            amount: maxPt,
            expectedReturn: minYt,
            nonce: offerNonce,
            expiration: expiration,
            useCallback: true
        });
        offerHash = _hashOffer(request, offer);
        $.authorizedOffers[offerHash] = OfferAuthorization(maxPt, minYt);
        emit OfferAuthorized(request, offerHash, offer);
    }

    /// @inheritdoc IRequestCallback
    /// @notice Pull-flow callback invoked by the 3F Request before transferring principal asset from this module.
    /// @dev Only the Request contract itself calls this (msg.sender == request).
    function onRequestConsumed(Offer calldata offer, bytes calldata, uint256 principal, uint256 yield)
        external
        nonReentrant
    {
        if (principal == 0) {
            revert ZeroValue();
        }

        address request = _msgSender();

        _checkRequest(request);

        if (block.timestamp > offer.expiration) {
            revert OfferExpired();
        }

        bytes32 offerHash = _hashOffer(request, offer);
        ThreeFModuleStorage storage $ = _threeFModuleStorage();
        OfferAuthorization memory auth = $.authorizedOffers[offerHash];

        if (auth.maxPt == 0) {
            revert OfferNotAuthorized();
        }
        if (principal > auth.maxPt) {
            revert ExceedsPtAuthorization();
        }
        /// @dev exactly the same as at line 422 https://github.com/3FLabs/grunt/blob/main/src/request/Request.sol
        /// ytAmount = offer.expectedReturn.mulDiv(ptAmount, offer.amount);
        if (yield < auth.minYt.mulDiv(principal, offer.amount)) {
            revert InsufficientYt();
        }
        if (TransferLibrary.balanceOf(asset, address(this)) < principal) {
            revert InsufficientBalance();
        }

        // Nonce advances in Request.consume() — same offer hash is unreplayable after this call.
        delete $.authorizedOffers[offerHash];
        IERC20(asset).forceApprove(request, principal);
        emit OfferConsumed(request, offerHash, offer, principal, yield);
    }

    /// @inheritdoc IThreeFModule
    function cancelOffers(address request, uint256 targetNonce) external nonReentrant onlyRole(PULL_ROLE) {
        _checkRequest(request);
        ThreeFModuleStorage storage $ = _threeFModuleStorage();
        if (targetNonce <= IOfferReceiver(request).nonce(address(this))) {
            revert NonceTooLow();
        }
        if (targetNonce > $.lastIssuedNonce[request]) {
            revert NonceNotIssued();
        }
        _cancelOffers(request, targetNonce);
    }

    /// @inheritdoc IThreeFModule
    function burn(address request) external nonReentrant onlyRole(BURN_ROLE) {
        /// @dev intentionally skip _checkRequest() to allow burning of requests that may have been disallowed after minting
        if (IRequest(request).asset() != asset) {
            revert AssetMismatch();
        }
        if (!IRequestFactory(_threeFModuleStorage().requestFactory).isRequest(request)) {
            revert RequestWrongFactory();
        }
        if (!IRequest(request).isRepaid()) {
            revert NotRepaid();
        }
        if (!IRequest(request).canWithdraw()) {
            revert WithdrawalNotAllowed();
        }
        (uint256 ptShares, uint256 ytShares, uint256 pAssets, uint256 yAssets) =
            IRequest(request).burnAll(address(this), address(this));

        if (IERC20(asset).allowance(address(this), request) > 0) {
            IERC20(asset).forceApprove(request, 0);
        }
        emit Burned(request, ptShares, ytShares, pAssets, yAssets);
    }

    // Internal functions

    /// @dev Advances the on-chain nonce to `targetNonce` if it hasn't been reached yet, emits OfferCancelled.
    ///      No-ops silently when targetNonce <= currentNonce (e.g. no offers issued, all already consumed).
    function _cancelOffers(address request, uint256 targetNonce) private {
        if (targetNonce <= IOfferReceiver(request).nonce(address(this))) {
            return;
        }
        IOfferReceiver(request).setNonce(targetNonce);
        emit OfferCancelled(request, targetNonce);
    }

    /// @dev Checks that `request` is in the allow set and currently whitelisted by 3F, reverts otherwise.
    ///      Asset match is not re-checked here — it is validated once at allowRequest().
    ///      Called by push(), authorizeOffer(), onRequestConsumed(), and cancelOffers().
    function _checkRequest(address request) internal view {
        if (!isRequestAllowed(request)) {
            revert RequestNotAllowed();
        }
        if (!isRequestWhitelisted(request)) {
            revert RequestNotWhitelisted();
        }
    }

    function _hashOffer(address request, Offer memory offer) internal view returns (bytes32) {
        (, string memory name, string memory version,,,,) = IERC5267(request).eip712Domain();
        bytes32 domainSep = keccak256(
            abi.encode(_DOMAIN_TYPEHASH, keccak256(bytes(name)), keccak256(bytes(version)), block.chainid, request)
        );
        bytes32 structHash = keccak256(abi.encode(_OFFER_TYPEHASH, offer));
        return keccak256(abi.encodePacked("\x19\x01", domainSep, structHash));
    }

    function _threeFModuleStorage() internal view returns (ThreeFModuleStorage storage $) {
        bytes32 slot = _threeFModuleStorageSlot;
        assembly {
            $.slot := slot
        }
    }
}
