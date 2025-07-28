// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./IShareManager.sol";

/// @title ITokenizedShareManager
/// @notice Interface for the TokenizedShareManager contract.
/// @dev This module allows making vault shares externally transferable and fully compliant with the ERC20 standard.
/// It's intended for vaults that require tokenized shares usable across external protocols, wallets, or DeFi integrations.
interface ITokenizedShareManager {
    /// @notice Storage layout for TokenizedShareManager.
    struct TokenizedShareManagerStorage {
        /// @notice Indicates that shares are being claimed.
        /// @dev This is used as reentrancy guard to avoid recursive `claim` calls.
        bool isClaiming;
    }
}
