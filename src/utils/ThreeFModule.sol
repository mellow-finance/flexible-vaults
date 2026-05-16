// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IOfferReceiver, Offer} from "../../scripts/common/interfaces/3F/IOfferReceiver.sol";
import {IRequest} from "../../scripts/common/interfaces/3F/IRequest.sol";

import {IRequestCallback} from "../../scripts/common/interfaces/3F/IRequestCallback.sol";
import {IRequestFactory} from "../../scripts/common/interfaces/3F/IRequestFactory.sol";
import {IWhitelist} from "../../scripts/common/interfaces/3F/IWhitelist.sol";

import "../interfaces/utils/IThreeFModule.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../libraries/SlotLibrary.sol";
import "../libraries/TransferLibrary.sol";
import "../permissions/MellowACL.sol";

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

contract ThreeFModule is IThreeFModule, MellowACL, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;
    using Math for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

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
    function nextNonce(address request) public view returns (uint256) {
        return IOfferReceiver(request).nonce(address(this)) + 1;
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
        ThreeFModuleStorage storage $ = _threeFModuleStorage();
        if (IRequest(request).asset() != asset) {
            revert AssetMismatch();
        }
        if (!isRequestWhitelisted(request)) {
            revert RequestNotWhitelisted();
        }
        if ($.allowedRequests.add(request)) {
            emit RequestAllowed(request);
        }
    }

    /// @inheritdoc IThreeFModule
    function disallowRequest(address request) external onlyRole(ALLOW_REQUEST_ROLE) {
        if (_threeFModuleStorage().allowedRequests.remove(request)) {
            emit RequestDisallowed(request);
        }
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
    function push(address request) external nonReentrant onlyRole(PUSH_ROLE) {
        _checkRequest(request);
        address _this = address(this);
        (uint128 maxPt, uint128 minYt) = IRequest(request).mintAuthorization(_this);
        /// @dev throw an error, because request is silently returns
        if (maxPt == 0 && minYt == 0) {
            revert InsufficientAuthorization();
        }
        if (TransferLibrary.balanceOf(asset, _this) < maxPt) {
            revert InsufficientBalance();
        }
        (uint128 ptBefore, uint128 ytBefore) = IRequest(request).balancesOf(_this);
        IERC20(asset).forceApprove(request, maxPt);
        IRequest(request).mint(maxPt, minYt);
        IERC20(asset).forceApprove(request, 0);
        (uint128 ptAfter, uint128 ytAfter) = IRequest(request).balancesOf(_this);
        uint128 ptMinted = ptAfter - ptBefore;
        uint128 ytMinted = ytAfter - ytBefore;
        if (ptMinted > maxPt || ytMinted < minYt) {
            revert SlippageExceeded();
        }
        emit Pushed(request, maxPt, minYt, ptMinted, ytMinted);
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
        uint256 offerNonce = nextNonce(request);
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
        _threeFModuleStorage().authorizedOffers[offerHash] = OfferAuthorization(maxPt, minYt);
        emit OfferAuthorized(request, offerHash, offer);
    }

    /// @inheritdoc IRequestCallback
    function onRequestConsumed(Offer calldata offer, bytes calldata, uint256 principal, uint256 yield)
        external
        nonReentrant
    {
        address request = _msgSender();

        _checkRequest(request);

        bytes32 offerHash = _hashOffer(request, offer);
        ThreeFModuleStorage storage $ = _threeFModuleStorage();
        OfferAuthorization memory auth = $.authorizedOffers[offerHash];

        if (auth.maxPt == 0) {
            revert OfferNotAuthorized();
        }
        if (principal > auth.maxPt) {
            revert ExceedsPtAuthorization();
        }

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
    function cancelOffer(address request) external nonReentrant onlyRole(PULL_ROLE) {
        _checkRequest(request);
        uint256 newNonce = nextNonce(request);
        IOfferReceiver(request).setNonce(newNonce);
        emit OfferCancelled(request, newNonce);
    }

    /// @inheritdoc IThreeFModule
    function burn(address request) external nonReentrant onlyRole(BURN_ROLE) {
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
        IERC20(asset).forceApprove(request, 0);
        emit Burned(request, ptShares, ytShares, pAssets, yAssets);
    }

    // Internal functions

    function _checkRequest(address request) internal view {
        if (!isRequestAllowed(request)) {
            revert RequestNotAllowed();
        }
        if (!isRequestWhitelisted(request)) {
            revert RequestNotWhitelisted();
        }
    }

    function _hashOffer(address request, Offer memory offer) internal view returns (bytes32) {
        // keccak256("Offer(address maker,uint256 amount,uint256 expectedReturn,uint256 nonce,uint256 expiration,bool useCallback)")
        bytes32 offerTypeHash = 0x3ded0c963332962cf2d273c8fb4f3e69f4ef33407ca72484fcebb56263ad0664;
        // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
        bytes32 domainTypeHash = 0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;
        bytes32 domainSep = keccak256(
            abi.encode(
                domainTypeHash,
                keccak256(bytes(IRequest(request).name())),
                keccak256(_REQUEST_VERSION),
                block.chainid,
                request
            )
        );
        bytes32 structHash = keccak256(abi.encode(offerTypeHash, offer));
        return keccak256(abi.encodePacked("\x19\x01", domainSep, structHash));
    }

    function _threeFModuleStorage() internal view returns (ThreeFModuleStorage storage $) {
        bytes32 slot = _threeFModuleStorageSlot;
        assembly {
            $.slot := slot
        }
    }
}
