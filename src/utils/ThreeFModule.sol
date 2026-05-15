// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IOfferReceiver, Offer} from "../../scripts/common/interfaces/3F/IOfferReceiver.sol";
import {IRequest} from "../../scripts/common/interfaces/3F/IRequest.sol";

import {IRequestCallback} from "../../scripts/common/interfaces/3F/IRequestCallback.sol";
import {IRequestFactory} from "../../scripts/common/interfaces/3F/IRequestFactory.sol";
import {IWhitelist} from "../../scripts/common/interfaces/3F/IWhitelist.sol";

import "../interfaces/utils/IThreeFModule.sol";

import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../libraries/SlotLibrary.sol";
import "../libraries/TransferLibrary.sol";
import "../permissions/MellowACL.sol";

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

contract ThreeFModule is IThreeFModule, MellowACL, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes4 private constant _MAGIC_VALUE = IERC1271.isValidSignature.selector;
    bytes4 private constant _INVALID_SIGNATURE = bytes4(0xffffffff);

    bytes32 private constant _OFFER_TYPEHASH = keccak256(
        "Offer(address maker,uint256 amount,uint256 expectedReturn,uint256 nonce,uint256 expiration,bool useCallback)"
    );

    bytes32 private constant _DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    // Version string from Request._domainNameAndVersion() — hardcoded in 3F source.
    bytes private constant _REQUEST_VERSION = "0.0.1";

    /// @notice Role authorised to call push().
    bytes32 public constant PUSH_ROLE = keccak256("utils.ThreeFModule.PUSH_ROLE");

    /// @notice Role authorised to call authorizeOffer() and cancelOffer().
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
        return _threeFModuleStorage().allowedRequests[request];
    }

    /// @inheritdoc IThreeFModule
    function isRequestWhitelisted(address request) public view returns (bool) {
        ThreeFModuleStorage storage $ = _threeFModuleStorage();
        return IRequestFactory($.requestFactory).isRequest(request)
            && IWhitelist($.whitelist).isWhitelisted(request) == IWhitelist.WhitelistStatus.Whitelisted;
    }

    /// @inheritdoc IThreeFModule
    function balancesOf(address request) public view returns (uint128 pt, uint128 yt) {
        return IRequest(request).balancesOf(address(this));
    }

    /// @inheritdoc IThreeFModule
    function mintAuthorization(address request) public view returns (uint128 ptAmount, uint128 ytAmount) {
        return IRequest(request).mintAuthorization(address(this));
    }

    /// @inheritdoc IThreeFModule
    function convertToAssets(address request) public view returns (uint256 pAssets, uint256 yAssets) {
        (uint128 pt, uint128 yt) = IRequest(request).balancesOf(address(this));
        return IRequest(request).convertToAssets(pt, yt);
    }

    /// @inheritdoc IThreeFModule
    function activeRequestsCount() public view returns (uint256) {
        return _threeFModuleStorage().activeRequests.length();
    }

    /// @inheritdoc IThreeFModule
    function activeRequestAt(uint256 index) public view returns (address) {
        return _threeFModuleStorage().activeRequests.at(index);
    }

    /// @inheritdoc IThreeFModule
    function balance(uint256 offset, uint256 limit) external view returns (uint256 totalAssets) {
        ThreeFModuleStorage storage $ = _threeFModuleStorage();
        uint256 total = $.activeRequests.length();
        uint256 end = offset + limit;
        if (end > total) {
            end = total;
        }
        for (uint256 i = offset; i < end; i++) {
            (uint256 pAssets, uint256 yAssets) = convertToAssets($.activeRequests.at(i));
            totalAssets += pAssets + yAssets;
        }
    }

    /// @inheritdoc IThreeFModule
    function nextNonce(address request) public view returns (uint256) {
        return IOfferReceiver(request).nonce(address(this)) + 1;
    }

    /// @notice Computes the EIP-712 offer hash the Request passes to isValidSignature().
    /// @dev Not part of IThreeFModule; exposed for off-chain tooling and tests.
    function hashOffer(address request, Offer calldata offer) public view returns (bytes32) {
        return _hashOffer(request, offer);
    }

    /// @inheritdoc IThreeFModule
    function isValidSignature(bytes32 hash, bytes calldata) external view returns (bytes4) {
        if (_threeFModuleStorage().authorizedOffers[hash].maxPt > 0) {
            return _MAGIC_VALUE;
        }
        return _INVALID_SIGNATURE;
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
        _threeFModuleStorage().allowedRequests[request] = true;
        emit RequestAllowed(request);
    }

    /// @inheritdoc IThreeFModule
    function disallowRequest(address request) external onlyRole(ALLOW_REQUEST_ROLE) {
        _threeFModuleStorage().allowedRequests[request] = false;
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

        if (IRequest(request).asset() != asset) {
            revert AssetMismatch();
        }
        address _this = address(this);
        (uint128 authPt, uint128 authYt) = IRequest(request).mintAuthorization(_this);
        if (authPt < maxPt) {
            revert InsufficientPtAuthorization();
        }
        if (authYt < minYt) {
            revert InsufficientYtAuthorization();
        }
        if (TransferLibrary.balanceOf(asset, _this) < authPt) {
            revert InsufficientBalance();
        }
        (uint128 ptBefore, uint128 ytBefore) = IRequest(request).balancesOf(_this);
        IERC20(asset).forceApprove(request, maxPt);
        IRequest(request).mint(maxPt, minYt);
        IERC20(asset).forceApprove(request, 0);
        (uint128 ptAfter, uint128 ytAfter) = IRequest(request).balancesOf(_this);
        _activateRequest(_threeFModuleStorage(), request);
        emit Pushed(request, maxPt, minYt, ptAfter - ptBefore, ytAfter - ytBefore);
    }

    /// @inheritdoc IThreeFModule
    function authorizeOffer(address request, uint256 amount, uint256 expectedReturn, uint256 duration)
        external
        nonReentrant
        onlyRole(PULL_ROLE)
    {
        _checkRequest(request);
        if (IRequest(request).asset() != asset) {
            revert AssetMismatch();
        }
        if (amount == 0 || duration == 0) {
            revert ZeroValue();
        }
        address _this = address(this);
        uint256 offerNonce = IOfferReceiver(request).nonce(_this) + 1;
        uint256 expiration = block.timestamp + duration;
        Offer memory offer = Offer({
            maker: _this,
            amount: amount,
            expectedReturn: expectedReturn,
            nonce: offerNonce,
            expiration: expiration,
            useCallback: true
        });
        bytes32 offerHash = _hashOffer(request, offer);
        _threeFModuleStorage().authorizedOffers[offerHash] = OfferAuthorization(amount);
        emit OfferAuthorized(request, offerHash, amount, expectedReturn, offerNonce, expiration);
    }

    /// @inheritdoc IRequestCallback
    function onRequestConsumed(Offer calldata offer, bytes calldata, uint256 principal, uint256 yield)
        external
        nonReentrant
    {
        address request = _msgSender();
        address _this = address(this);

        if (!isRequestAllowed(request)) {
            revert RequestNotAllowed();
        }
        if (!isRequestWhitelisted(request)) {
            revert RequestNotWhitelisted();
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
        if (TransferLibrary.balanceOf(asset, _this) < principal) {
            revert InsufficientBalance();
        }

        uint256 remaining = auth.maxPt - principal;
        if (remaining == 0) {
            delete $.authorizedOffers[offerHash];
        } else {
            $.authorizedOffers[offerHash].maxPt = remaining;
        }
        IERC20(asset).forceApprove(request, principal);
        _activateRequest($, request);
        emit Pulled(request, principal, yield);
    }

    /// @inheritdoc IThreeFModule
    function cancelOffer(address request) external nonReentrant onlyRole(PULL_ROLE) {
        _checkRequest(request);
        uint256 newNonce = IOfferReceiver(request).nonce(address(this)) + 1;
        IOfferReceiver(request).setNonce(newNonce);
        emit OfferCancelled(request, newNonce);
    }

    /// @inheritdoc IThreeFModule
    function burn(address request, uint256 minAssetOut) external nonReentrant onlyRole(BURN_ROLE) {
        _checkRequest(request);
        ThreeFModuleStorage storage $ = _threeFModuleStorage();
        if (!$.activeRequests.contains(request)) {
            revert RequestNotActive();
        }
        if (minAssetOut == 0) {
            revert ZeroMinAssetOut();
        }
        if (!IRequest(request).isRepaid()) {
            revert NotRepaid();
        }
        if (!IRequest(request).canWithdraw()) {
            revert WithdrawalNotAllowed();
        }
        (uint256 ptShares, uint256 ytShares, uint256 pAssets, uint256 yAssets) =
            IRequest(request).burnAll(address(this), address(this));
        if (pAssets + yAssets < minAssetOut) {
            revert InsufficientOutput();
        }
        _deactivateRequest($, request);
        emit Burned(request, ptShares, ytShares, pAssets, yAssets);
    }

    // Internal functions

    function _activateRequest(ThreeFModuleStorage storage $, address request) internal {
        if ($.activeRequests.add(request)) {
            emit RequestActivated(request);
        }
    }

    function _deactivateRequest(ThreeFModuleStorage storage $, address request) internal {
        if ($.activeRequests.remove(request)) {
            emit RequestDeactivated(request);
        }
    }

    function _checkRequest(address request) internal view {
        if (!isRequestAllowed(request)) {
            revert RequestNotAllowed();
        }
        if (!isRequestWhitelisted(request)) {
            revert RequestNotWhitelisted();
        }
    }

    function _hashOffer(address request, Offer memory offer) internal view returns (bytes32) {
        bytes32 domainSep = keccak256(
            abi.encode(
                _DOMAIN_TYPEHASH,
                keccak256(bytes(IRequest(request).name())),
                keccak256(_REQUEST_VERSION),
                block.chainid,
                request
            )
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
