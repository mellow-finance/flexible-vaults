// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

contract MockFeeManager {
    uint256 internal _depositFeeInPercentage;
    uint256 internal _redeemFeeInPercentage;
    address internal _feeRecipient;

    function calculateDepositFee(uint256 amount) external view returns (uint256) {
        return (amount * _depositFeeInPercentage) / 100;
    }

    function calculateRedeemFee(uint256 shares) external view returns (uint256) {
        return (shares * _redeemFeeInPercentage) / 100;
    }

    function feeRecipient() external view returns (address) {
        return _feeRecipient;
    }

    /// -----------------------------------------------------------------------
    /// Custom functions, just for testing purposes.
    /// -----------------------------------------------------------------------

    function __setDepositFeeInPercentage(uint256 depositFeeInPercentage) external {
        _depositFeeInPercentage = depositFeeInPercentage;
    }

    function __setRedeemFeeInPercentage(uint256 redeemFeeInPercentage) external {
        _redeemFeeInPercentage = redeemFeeInPercentage;
    }

    function __setFeeRecipient(address recipient) external {
        _feeRecipient = recipient;
    }

    function test() external {}
}
