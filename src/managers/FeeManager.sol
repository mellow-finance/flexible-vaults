// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/managers/IFeeManager.sol";

import "../libraries/SlotLibrary.sol";

contract FeeManager is IFeeManager, OwnableUpgradeable {
    bytes32 private immutable _feeManagerStorageSlot;

    constructor(string memory name_, uint256 version_) {
        _feeManagerStorageSlot = SlotLibrary.getSlot("FeeManager", name_, version_);
        _disableInitializers();
    }

    // View functions

    /// @inheritdoc IFeeManager
    function feeRecipient() public view returns (address) {
        return _feeManagerStorage().feeRecipient;
    }

    /// @inheritdoc IFeeManager
    function depositFeeD6() public view returns (uint24) {
        return _feeManagerStorage().depositFeeD6;
    }

    /// @inheritdoc IFeeManager
    function redeemFeeD6() public view returns (uint24) {
        return _feeManagerStorage().redeemFeeD6;
    }

    /// @inheritdoc IFeeManager
    function performanceFeeD6() public view returns (uint24) {
        return _feeManagerStorage().performanceFeeD6;
    }

    /// @inheritdoc IFeeManager
    function protocolFeeD6() public view returns (uint24) {
        return _feeManagerStorage().protocolFeeD6;
    }

    /// @inheritdoc IFeeManager
    function timestamps(address vault) public view returns (uint256) {
        return _feeManagerStorage().timestamps[vault];
    }

    /// @inheritdoc IFeeManager
    function maxPriceD18(address vault) public view returns (uint256) {
        return _feeManagerStorage().maxPriceD18[vault];
    }

    /// @inheritdoc IFeeManager
    function baseAsset(address vault) public view returns (address) {
        return _feeManagerStorage().baseAsset[vault];
    }

    /// @inheritdoc IFeeManager
    function calculateDepositFee(uint256 amount) public view returns (uint256) {
        return (amount * depositFeeD6()) / 1e6;
    }

    /// @inheritdoc IFeeManager
    function calculateRedeemFee(uint256 amount) public view returns (uint256) {
        return (amount * redeemFeeD6()) / 1e6;
    }

    /// @inheritdoc IFeeManager
    function calculatePerformanceFee(address vault, address asset, uint256 priceD18) public view returns (uint256) {
        FeeManagerStorage storage $ = _feeManagerStorage();
        if (asset != $.baseAsset[vault]) {
            return 0;
        }
        uint256 maxPriceD18_ = $.maxPriceD18[vault];
        if (maxPriceD18_ == 0 || priceD18 <= maxPriceD18_) {
            return 0;
        }
        return Math.mulDiv(priceD18 - maxPriceD18_, $.performanceFeeD6, 1e6);
    }

    /// @inheritdoc IFeeManager
    function calculateProtocolFee(address vault, uint256 totalShares) public view returns (uint256 shares) {
        FeeManagerStorage storage $ = _feeManagerStorage();
        uint256 previousTimestamp = $.timestamps[vault];
        uint256 timeElapsed = block.timestamp - previousTimestamp;
        if (timeElapsed == 0 || totalShares == 0 || $.protocolFeeD6 == 0) {
            return 0;
        }
        return Math.mulDiv(totalShares, $.protocolFeeD6 * timeElapsed, 365e6 days);
    }

    // Mutable functions

    /// @inheritdoc IFeeManager
    function setFeeRecipient(address feeRecipient_) external onlyOwner {
        _setFeeRecipient(feeRecipient_);
    }

    /// @inheritdoc IFeeManager
    function setFees(uint24 depositFeeD6_, uint24 redeemFeeD6_, uint24 performanceFeeD6_, uint24 protocolFeeD6_)
        external
        onlyOwner
    {
        _setFees(depositFeeD6_, redeemFeeD6_, performanceFeeD6_, protocolFeeD6_);
    }

    /// @inheritdoc IFeeManager
    function setBaseAsset(address vault, address baseAsset_) external onlyOwner {
        if (vault == address(0) || baseAsset_ == address(0)) {
            revert ZeroAddress();
        }
        FeeManagerStorage storage $ = _feeManagerStorage();
        if ($.baseAsset[vault] != address(0)) {
            revert BaseAssetAlreadSet(vault, $.baseAsset[vault]);
        }
        $.baseAsset[vault] = baseAsset_;
        emit SetBaseAsset(vault, baseAsset_);
    }

    /// @inheritdoc IFeeManager
    function updateState(address asset, uint256 priceD18) external {
        FeeManagerStorage storage $ = _feeManagerStorage();
        address vault = _msgSender();
        if ($.baseAsset[vault] != asset) {
            return;
        }
        if ($.maxPriceD18[vault] < priceD18) {
            $.maxPriceD18[vault] = priceD18;
        }
        $.timestamps[vault] = block.timestamp;
        emit UpdateState(vault, asset, priceD18);
    }

    /// @inheritdoc IFactoryEntity
    function initialize(bytes calldata data) external virtual initializer {
        (
            address owner_,
            address feeRecipient_,
            uint24 depositFeeD6_,
            uint24 redeemFeeD6_,
            uint24 performanceFeeD6_,
            uint24 protocolFeeD6_
        ) = abi.decode(data, (address, address, uint24, uint24, uint24, uint24));
        __Ownable_init(owner_);
        _setFeeRecipient(feeRecipient_);
        _setFees(depositFeeD6_, redeemFeeD6_, performanceFeeD6_, protocolFeeD6_);
        emit Initialized(data);
    }

    // Internal functions

    function _setFeeRecipient(address feeRecipient_) internal {
        if (feeRecipient_ == address(0)) {
            revert ZeroAddress();
        }
        FeeManagerStorage storage $ = _feeManagerStorage();
        $.feeRecipient = feeRecipient_;
        emit SetFeeRecipient(feeRecipient_);
    }

    function _setFees(uint24 depositFeeD6_, uint24 redeemFeeD6_, uint24 performanceFeeD6_, uint24 protocolFeeD6_)
        internal
    {
        if (depositFeeD6_ > 1e6) {
            revert InvalidDepositFee(depositFeeD6_);
        }
        if (redeemFeeD6_ > 1e6) {
            revert InvalidRedeemFee(redeemFeeD6_);
        }
        if (performanceFeeD6_ > 1e6) {
            revert InvalidPerformanceFee(performanceFeeD6_);
        }
        if (protocolFeeD6_ > 1e6) {
            revert InvalidProtocolFee(protocolFeeD6_);
        }
        FeeManagerStorage storage $ = _feeManagerStorage();
        $.depositFeeD6 = depositFeeD6_;
        $.redeemFeeD6 = redeemFeeD6_;
        $.performanceFeeD6 = performanceFeeD6_;
        $.protocolFeeD6 = protocolFeeD6_;
        emit SetFees(depositFeeD6_, redeemFeeD6_, performanceFeeD6_, protocolFeeD6_);
    }

    function _feeManagerStorage() internal view returns (FeeManagerStorage storage $) {
        bytes32 slot = _feeManagerStorageSlot;
        assembly {
            $.slot := slot
        }
    }
}
