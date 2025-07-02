// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import "../factories/IFactoryEntity.sol";
import "../modules/IACLModule.sol";
import "../modules/IShareModule.sol";

interface IShareManager is IFactoryEntity {
    error Forbidden();
    error InsufficientAllocatedShares(uint256 value, uint256 allocated);
    error GlobalLockupNotExpired(uint256 timestamp, uint32 globalLockup);
    error TargetedLockupNotExpired(uint256 timestamp, uint32 targetedLockup);
    error Blacklisted(address account);
    error TransferPaused();
    error MintPaused();
    error BurnPaused();
    error LimitExceeded(uint256 value, uint256 limit);
    error NotWhitelisted(address account);
    error TransferNotAllowed(address from, address to);
    error ZeroValue();

    struct ShareManagerStorage {
        address vault;
        uint256 flags;
        uint256 allocatedShares;
        bytes32 whitelistMerkleRoot;
        mapping(address account => AccountInfo) accounts;
    }

    struct AccountInfo {
        bool canDeposit;
        bool canTransfer;
        bool isBlacklisted;
        uint32 lockedUntil;
    }

    struct Flags {
        bool hasMintPause;
        bool hasBurnPause;
        bool hasTransferPause;
        bool hasWhitelist;
        bool hasBlacklist;
        bool hasTransferWhitelist;
        uint32 globalLockup;
        uint32 targetedLockup;
    }

    // View functions

    function vault() external view returns (address);

    function allocatedShares() external view returns (uint256);

    function flags() external view returns (Flags memory);

    function whitelistMerkleRoot() external view returns (bytes32);

    function isDepositorWhitelisted(address account, bytes32[] calldata merkleProof) external view returns (bool);

    function sharesOf(address account) external view returns (uint256);

    function claimableSharesOf(address account) external view returns (uint256);

    function activeSharesOf(address account) external view returns (uint256);

    function activeShares() external view returns (uint256);

    function totalShares() external view returns (uint256);

    function accounts(address account)
        external
        view
        returns (bool canDeposit, bool canTransfer, bool isBlacklisted, uint232 lockedUntil);

    function updateChecks(address from, address to) external view;

    // Mutable functions

    function claimShares(address account) external;

    function setAccountInfo(address account, AccountInfo memory info) external;

    function setFlags(Flags calldata flags) external;

    function allocateShares(uint256 shares) external;

    function mintAllocatedShares(address to, uint256 shares) external;

    function mint(address to, uint256 shares) external;

    function burn(address account, uint256 amount) external;

    event AllocateShares(int256 value);

    event Mint(address indexed account, uint256 shares, uint32 lockedUntil);

    event Burn(address indexed account, uint256 shares);

    event SetFlags(Flags flags);

    event SetAccountInfo(address indexed account, AccountInfo info);
}
