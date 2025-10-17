// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

contract MockRiskManager {
    uint256 internal _limit;

    mapping(address => mapping(address => bool)) internal _disallowedAssets;

    constructor(uint256 limit) {
        _limit = limit;
    }

    function maxDeposit(address, address) external view returns (uint256) {
        return _limit;
    }

    function modifyPendingAssets(
        address,
        /* asset */
        int256 /* pendingAssets */
    ) external {}

    function modifyVaultBalance(
        address,
        /* asset */
        int256 /* vaultBalance */
    ) external {}

    function isAllowedAsset(address subvault, address asset) external view returns (bool) {
        return !_disallowedAssets[subvault][asset];
    }

    /// -----------------------------------------------------------------------
    /// Test functions
    /// -----------------------------------------------------------------------
    function __setDisallowedAsset(address subvault, address asset) external {
        _disallowedAssets[subvault][asset] = true;
    }

    function test() external {}
}
