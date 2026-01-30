// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface IYieldBasis {
    function deposit(uint256 assets, uint256 debt, uint256 min_shares) external returns (uint256);

    function withdraw(uint256 shares, uint256 min_assets) external returns (uint256);

    function emergency_withdraw(uint256 shares) external returns (uint256 assets, int256 debt);

    /// @notice returns the address of the gauge
    function staker() external view returns (address);

    function ASSET_TOKEN() external view returns (address);

    function symbol() external view returns (string memory);

    function name() external view returns (string memory);
}
