// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IOfferReceiver, Offer} from "../../scripts/common/interfaces/3F/IOfferReceiver.sol";
import {IRequest} from "../../scripts/common/interfaces/3F/IRequest.sol";

import {IRequestFactory} from "../../scripts/common/interfaces/3F/IRequestFactory.sol";
import {IWhitelist} from "../../scripts/common/interfaces/3F/IWhitelist.sol";

import "../interfaces/utils/IThreeFModule.sol";

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../libraries/SlotLibrary.sol";
import "../permissions/MellowACL.sol";

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ThreeFModule is IThreeFModule, MellowACL, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes4 private constant _ERC1271_MAGIC_VALUE = 0x1626ba7e;
    bytes4 private constant _ERC1271_INVALID = 0xffffffff;

    /// @inheritdoc IThreeFModule
    bytes32 public constant CALLER_ROLE = keccak256("utils.ThreeFModule.CALLER_ROLE");

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
    function nonce(address request) public view returns (uint256) {
        return _threeFModuleStorage().nonces[request];
    }

    /// @inheritdoc IThreeFModule
    function isValidSignature(bytes32, bytes calldata) external view returns (bytes4) {
        if (_threeFModuleStorage().isValidSignatureFlag && isRequestAllowed(msg.sender)) {
            return _ERC1271_MAGIC_VALUE;
        }
        return _ERC1271_INVALID;
    }

    // Mutable functions

    /// @inheritdoc IFactoryEntity
    function initialize(bytes calldata data) external initializer {
        (address admin, address subvault_, address whitelist_, address requestFactory_, address curator) =
            abi.decode(data, (address, address, address, address, address));
        if (
            admin == address(0) || subvault_ == address(0) || whitelist_ == address(0) || requestFactory_ == address(0)
                || curator == address(0)
        ) {
            revert ZeroValue();
        }
        ThreeFModuleStorage storage $ = _threeFModuleStorage();
        $.subvault = subvault_;
        $.whitelist = whitelist_;
        $.requestFactory = requestFactory_;
        $.isValidSignatureFlag = false;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(CALLER_ROLE, curator);
        emit Initialized(data);
    }

    /// @inheritdoc IThreeFModule
    function pushAssets(uint256 value) external onlySubvault {
        IERC20(asset).safeTransferFrom(_msgSender(), address(this), value);
        emit AssetsPushed(value);
    }

    /// @inheritdoc IThreeFModule
    function pullAssets(uint256 value) external onlySubvault {
        IERC20(asset).safeTransfer(_msgSender(), value);
        emit AssetsPulled(value);
    }

    /// @inheritdoc IThreeFModule
    function push(address request, uint128 maxPt, uint128 minYt) external onlyRole(CALLER_ROLE) {
        if (!isRequestAllowed(request)) {
            revert NotAllowedRequest();
        }
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
        if (IERC20(asset).balanceOf(_this) < authPt) {
            revert InsufficientBalance();
        }
        (uint128 ptBefore, uint128 ytBefore) = IRequest(request).balancesOf(_this);
        IERC20(asset).forceApprove(request, maxPt);
        IRequest(request).mint(maxPt, minYt);
        IERC20(asset).forceApprove(request, 0);
        (uint128 ptAfter, uint128 ytAfter) = IRequest(request).balancesOf(_this);
        _threeFModuleStorage().activeRequests.add(request);
        emit Pushed(request, maxPt, minYt, ptAfter - ptBefore, ytAfter - ytBefore);
    }

    /// @inheritdoc IThreeFModule
    function pull(address request, Offer calldata offer, uint256 ptAmount, uint256 minYt)
        external
        nonReentrant
        onlyRole(CALLER_ROLE)
    {
        address _this = address(this);
        if (!isRequestAllowed(request)) {
            revert NotAllowedRequest();
        }
        if (IRequest(request).asset() != asset) {
            revert AssetMismatch();
        }
        if (offer.maker != _this) {
            revert InvalidMaker();
        }
        if (offer.useCallback) {
            revert CallbackNotAllowed();
        }
        if (offer.expiration < block.timestamp) {
            revert OfferExpired();
        }
        if (ptAmount > offer.amount) {
            revert ExceedsOfferAmount();
        }
        ThreeFModuleStorage storage $ = _threeFModuleStorage();
        if (offer.nonce <= $.nonces[request]) {
            revert StaleNonce();
        }
        if (IERC20(asset).balanceOf(_this) < ptAmount) {
            revert InsufficientBalance();
        }
        IERC20(asset).forceApprove(request, ptAmount);
        $.isValidSignatureFlag = true;
        uint256 ytAmount = IRequest(request).consume(offer, new bytes(0), ptAmount);
        $.isValidSignatureFlag = false;
        IERC20(asset).forceApprove(request, 0);
        if (ytAmount < minYt) {
            revert InsufficientYt();
        }
        $.activeRequests.add(request);
        emit Pulled(request, ptAmount, ytAmount);
    }

    /// @inheritdoc IThreeFModule
    function burn(address request, uint256 minAssetOut) external onlyRole(CALLER_ROLE) {
        if (!isRequestAllowed(request)) {
            revert NotAllowedRequest();
        }
        if (!IRequest(request).isRepaid()) {
            revert NotRepaid();
        }
        if (!IRequest(request).canWithdraw()) {
            revert WithdrawalNotAllowed();
        }
        ThreeFModuleStorage storage $ = _threeFModuleStorage();
        (uint256 ptShares, uint256 ytShares, uint256 pAssets, uint256 yAssets) =
            IRequest(request).burnAll(address(this), address(this));
        if (pAssets + yAssets < minAssetOut) {
            revert InsufficientOutput();
        }
        $.activeRequests.remove(request);
        emit Burned(request, ptShares, ytShares, pAssets, yAssets);
    }

    /// @inheritdoc IThreeFModule
    function cancelOffer(address request) external onlyRole(CALLER_ROLE) {
        if (!isRequestAllowed(request)) {
            revert NotAllowedRequest();
        }
        ThreeFModuleStorage storage $ = _threeFModuleStorage();
        IOfferReceiver(request).setNonce(++$.nonces[request]);
    }

    // Internal functions

    function _threeFModuleStorage() internal view returns (ThreeFModuleStorage storage $) {
        bytes32 slot = _threeFModuleStorageSlot;
        assembly {
            $.slot := slot
        }
    }
}
