// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import "../factories/IFactoryEntity.sol";
import "../modules/IACLModule.sol";
import "../modules/IShareModule.sol";

/// @title IShareManager
/// @notice Interface for managing share allocations, permissions, minting, burning, and user restrictions
/// @dev Intended for use within modular vault systems that decouple share logic from core vault
interface IShareManager is IFactoryEntity {
    /// @notice Unauthorized call
    error Forbidden();

    /// @notice Attempted to mint more shares than allocated
    error InsufficientAllocatedShares(uint256 value, uint256 allocated);

    /// @notice Global lockup not yet expired
    error GlobalLockupNotExpired(uint256 timestamp, uint32 globalLockup);

    /// @notice Targeted lockup not yet expired
    error TargetedLockupNotExpired(uint256 timestamp, uint32 targetedLockup);

    /// @notice Blacklisted account tried to interact
    error Blacklisted(address account);

    /// @notice Transfers are currently paused
    error TransferPaused();

    /// @notice Minting is currently paused
    error MintPaused();

    /// @notice Burning is currently paused
    error BurnPaused();

    /// @notice Mint would exceed share limit
    error LimitExceeded(uint256 value, uint256 limit);

    /// @notice Account is not whitelisted to deposit
    error NotWhitelisted(address account);

    /// @notice Transfer between accounts not allowed by whitelist
    error TransferNotAllowed(address from, address to);

    /// @notice Provided value was zero
    error ZeroValue();

    /// @notice Storage layout for ShareManager. Handles permissioning, user states, and share allocation for a vault.
    struct ShareManagerStorage {
        /// @notice Address of the vault associated with this ShareManager.
        address vault;
        /// @notice Bitpacked configuration flags controlling global minting, burning, transfers, and whitelists.
        uint256 flags;
        /// @notice Total shares allocated to all accounts (includes unclaimed and locked shares).
        uint256 allocatedShares;
        /// @notice Merkle root for verifying account permissions (used for deposits if whitelist flags are active).
        bytes32 whitelistMerkleRoot;
        /// @notice Tracks individual account permissions, blacklist status, and lockup.
        mapping(address account => AccountInfo) accounts;
    }

    /// @notice Per-account permission and state tracking.
    struct AccountInfo {
        /// @notice Whether the account is allowed to deposit when the `hasWhitelist` flag is active.
        bool canDeposit;
        /// @notice If true, account is allowed to transfer shares regardless of global transfer whitelist state.
        bool canTransfer;
        /// @notice If true, account is blocked from all transfer actions.
        bool isBlacklisted;
        /// @notice Timestamp (in seconds) until which shares are non-transferable due to lockup.
        /// Set on per-account basis.
        uint32 lockedUntil;
    }

    /// @notice Decoded configuration flags from `ShareManagerStorage.flags`.
    struct Flags {
        /// @notice If true, minting is globally paused.
        bool hasMintPause;
        /// @notice If true, burning of shares is globally paused.
        bool hasBurnPause;
        /// @notice If true, transfers of shares between accounts are globally paused.
        bool hasTransferPause;
        /// @notice If true, deposit access is controlled via onchain mapping.
        bool hasWhitelist;
        /// @notice If true, transfer access is controlled via onchain mapping.
        bool hasTransferWhitelist;
        /// @notice Global lockup duration (in seconds) applied after every mint.
        uint32 globalLockup;
        /// @notice Optional per-account lockup override (in seconds). Apply to all users separately after every deposit.
        uint32 targetedLockup;
    }

    /// @notice Returns address of the vault using this ShareManager
    function vault() external view returns (address);

    /// @notice Total allocated shares
    function allocatedShares() external view returns (uint256);

    /// @notice Returns current system-wide flags (as decoded struct)
    function flags() external view returns (Flags memory);

    /// @notice Returns Merkle root used for whitelist verification
    function whitelistMerkleRoot() external view returns (bytes32);

    /// @return bool Returns true whether depositor is allowed under current Merkle root and flag settings
    function isDepositorWhitelisted(address account, bytes32[] calldata merkleProof) external view returns (bool);

    /// @notice Returns total shares (active + claimable) for an account
    function sharesOf(address account) external view returns (uint256);

    /// @notice Returns claimable shares for an account
    function claimableSharesOf(address account) external view returns (uint256);

    /// @notice Returns active (non-claimable) shares
    function activeSharesOf(address account) external view returns (uint256);

    /// @notice Returns total active shares across the vault
    function activeShares() external view returns (uint256);

    /// @notice Total shares including active and claimable
    function totalShares() external view returns (uint256);

    /// @notice Returns account-specific configuration and permissions
    function accounts(address account) external view returns (AccountInfo memory);

    /// @notice Internal checks for mint/burn/transfer under flags, lockups, blacklists, etc.
    function updateChecks(address from, address to) external view;

    /// @notice Triggers share claiming from queue to user
    function claimShares(address account) external;

    /// @notice Sets permissions and flags for a specific account
    function setAccountInfo(address account, AccountInfo memory info) external;

    /// @notice Sets global flag bitmask controlling mints, burns, lockups, etc.
    function setFlags(Flags calldata flags) external;

    /// @notice Allocates `shares` that can be later minted via `mintAllocatedShares`
    function allocateShares(uint256 shares) external;

    /// @notice Mints shares from the allocated pool
    function mintAllocatedShares(address to, uint256 shares) external;

    /// @notice Mints new shares to a user directly
    function mint(address to, uint256 shares) external;

    /// @notice Burns user's shares
    function burn(address account, uint256 amount) external;

    /// @notice One-time vault assignment during initialization
    function setVault(address vault_) external;

    /// @notice Emitted when shares are allocated or removed (positive/negative)
    event AllocateShares(int256 value);

    /// @notice Emitted when new shares are minted
    event Mint(address indexed account, uint256 shares, uint32 lockedUntil);

    /// @notice Emitted when shares are burned
    event Burn(address indexed account, uint256 shares);

    /// @notice Emitted when global flag configuration is changed
    event SetFlags(Flags flags);

    /// @notice Emitted when a user account is updated
    event SetAccountInfo(address indexed account, AccountInfo info);

    /// @notice Emitted when vault is set
    event SetVault(address indexed vault);
}
