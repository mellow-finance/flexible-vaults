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

    function feeRecipient() public view returns (address) {
        return _feeManagerStorage().feeRecipient;
    }

    function depositFeeD6() public view returns (uint24) {
        return _feeManagerStorage().depositFeeD6;
    }

    function redeemFeeD6() public view returns (uint24) {
        return _feeManagerStorage().redeemFeeD6;
    }

    function performanceFeeD6() public view returns (uint24) {
        return _feeManagerStorage().performanceFeeD6;
    }

    function protocolFeeD6() public view returns (uint24) {
        return _feeManagerStorage().protocolFeeD6;
    }

    function timestamps(address vault) public view returns (uint256) {
        return _feeManagerStorage().timestamps[vault];
    }

    function maxPriceD18(address vault) public view returns (uint256) {
        return _feeManagerStorage().maxPriceD18[vault];
    }

    function baseAsset(address vault) public view returns (address) {
        return _feeManagerStorage().baseAsset[vault];
    }

    function calculateDepositFee(uint256 amount) public view returns (uint256) {
        return (amount * depositFeeD6()) / 1e6;
    }

    function calculateRedeemFee(uint256 amount) public view returns (uint256) {
        return (amount * redeemFeeD6()) / 1e6;
    }

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

    /// @dev shares
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

    function setFeeRecipient(address feeRecipient_) external onlyOwner {
        require(feeRecipient_ != address(0), "FeeManager: zero address");
        _feeManagerStorage().feeRecipient = feeRecipient_;
    }

    function setDepositFeeD6(uint24 depositFeeD6_) external onlyOwner {
        require(depositFeeD6_ <= 1e6, "FeeManager: invalid deposit fee");
        _feeManagerStorage().depositFeeD6 = depositFeeD6_;
    }

    function setRedeemFeeD6(uint24 redeemFeeD6_) external onlyOwner {
        require(redeemFeeD6_ <= 1e6, "FeeManager: invalid redeem fee");
        _feeManagerStorage().redeemFeeD6 = redeemFeeD6_;
    }

    function setPerformanceFeeD6(uint24 performanceFeeD6_) external onlyOwner {
        require(performanceFeeD6_ <= 1e6, "FeeManager: invalid performance fee");
        _feeManagerStorage().performanceFeeD6 = performanceFeeD6_;
    }

    function setProtocolFeeD6(uint24 protocolFeeD6_) external onlyOwner {
        require(protocolFeeD6_ <= 1e6, "FeeManager: invalid protocol fee");
        _feeManagerStorage().protocolFeeD6 = protocolFeeD6_;
    }

    function setBaseAsset(address vault, address baseAsset_) external onlyOwner {
        require(vault != address(0), "FeeManager: zero vault address");
        require(baseAsset_ != address(0), "FeeManager: zero base asset address");
        FeeManagerStorage storage $ = _feeManagerStorage();
        if ($.baseAsset[vault] != address(0)) {
            revert("FeeManager: base asset already set for vault");
        }
        $.baseAsset[vault] = baseAsset_;
    }

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
    }

    function initialize(bytes calldata data) external initializer {
        (
            address owner_,
            address feeRecipient_,
            uint24 depositFeeD6_,
            uint24 redeemFeeD6_,
            uint24 performanceFeeD6_,
            uint24 protocolFeeD6_
        ) = abi.decode(data, (address, address, uint24, uint24, uint24, uint24));
        __FeeManager_init(owner_, feeRecipient_, depositFeeD6_, redeemFeeD6_, performanceFeeD6_, protocolFeeD6_);
    }

    // Internal functions

    function __FeeManager_init(
        address owner_,
        address feeRecipient_,
        uint24 depositFeeD6_,
        uint24 redeemFeeD6_,
        uint24 performanceFeeD6_,
        uint24 protocolFeeD6_
    ) internal onlyInitializing {
        __Ownable_init(owner_);
        FeeManagerStorage storage $ = _feeManagerStorage();
        $.feeRecipient = feeRecipient_;
        $.depositFeeD6 = depositFeeD6_;
        $.redeemFeeD6 = redeemFeeD6_;
        $.performanceFeeD6 = performanceFeeD6_;
        $.protocolFeeD6 = protocolFeeD6_;
    }

    function _feeManagerStorage() internal view returns (FeeManagerStorage storage $) {
        bytes32 slot = _feeManagerStorageSlot;
        assembly {
            $.slot := slot
        }
    }
}
