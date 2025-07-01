// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/managers/IShareManager.sol";

import "../libraries/ShareManagerFlagLibrary.sol";
import "../libraries/SlotLibrary.sol";

abstract contract ShareManager is IShareManager, ContextUpgradeable {
    using ShareManagerFlagLibrary for uint256;

    bytes32 public constant SET_FLAGS_ROLE = keccak256("managers.ShareManager.SET_FLAGS_ROLE");
    bytes32 public constant SET_ACCOUNT_INFO_ROLE = keccak256("managers.ShareManager.SET_ACCOUNT_INFO_ROLE");

    bytes32 private immutable _shareManagerStorageSlot;

    constructor(string memory name_, uint256 version_) {
        _shareManagerStorageSlot = SlotLibrary.getSlot("ShareManager", name_, version_);
        _disableInitializers();
    }

    // View functions

    modifier onlyQueue() {
        if (!IShareModule(_shareManagerStorage().vault).hasQueue(_msgSender())) {
            revert Forbidden();
        }
        _;
    }

    modifier onlyRole(bytes32 role) {
        if (!IACLModule(_shareManagerStorage().vault).hasRole(role, _msgSender())) {
            revert Forbidden();
        }
        _;
    }

    /// @inheritdoc IShareManager
    function isDepositorWhitelisted(address account, bytes32[] calldata merkleProof) public view returns (bool) {
        ShareManagerStorage storage $ = _shareManagerStorage();
        if ($.flags.hasWhitelist() && !$.accounts[account].canDeposit) {
            return false;
        }
        bytes32 whitelistMerkleRoot_ = $.whitelistMerkleRoot;
        if (
            whitelistMerkleRoot_ != bytes32(0)
                && !MerkleProof.verify(
                    merkleProof, whitelistMerkleRoot_, keccak256(bytes.concat(keccak256(abi.encode(account))))
                )
        ) {
            return false;
        }
        return true;
    }

    /// @inheritdoc IShareManager
    function sharesOf(address account) public view returns (uint256) {
        return activeSharesOf(account) + claimableSharesOf(account);
    }

    /// @inheritdoc IShareManager
    function claimableSharesOf(address account) public view returns (uint256) {
        return IShareModule(_shareManagerStorage().vault).claimableSharesOf(account);
    }

    /// @inheritdoc IShareManager
    function activeSharesOf(address account) public view virtual returns (uint256);

    /// @inheritdoc IShareManager
    function activeShares() public view virtual returns (uint256);

    /// @inheritdoc IShareManager
    function totalShares() public view returns (uint256) {
        return _shareManagerStorage().allocatedShares + activeShares();
    }

    /// @inheritdoc IShareManager
    function vault() public view returns (address) {
        return _shareManagerStorage().vault;
    }

    /// @inheritdoc IShareManager
    function allocatedShares() public view returns (uint256) {
        return _shareManagerStorage().allocatedShares;
    }

    /// @inheritdoc IShareManager
    function flags() public view returns (Flags memory f) {
        uint256 bitmask = _shareManagerStorage().flags;
        f.hasMintPause = bitmask.hasMintPause();
        f.hasBurnPause = bitmask.hasBurnPause();
        f.hasTransferPause = bitmask.hasTransferPause();
        f.hasWhitelist = bitmask.hasWhitelist();
        f.hasBlacklist = bitmask.hasBlacklist();
        f.hasTransferWhitelist = bitmask.hasTransferWhitelist();
        f.globalLockup = bitmask.getGlobalLockup();
        f.targetedLockup = bitmask.getTargetedLockup();
    }

    /// @inheritdoc IShareManager
    function whitelistMerkleRoot() public view returns (bytes32) {
        return _shareManagerStorage().whitelistMerkleRoot;
    }

    /// @inheritdoc IShareManager
    function accounts(address account)
        public
        view
        returns (bool canDeposit, bool canTransfer, bool isBlacklisted, uint232 lockedUntil)
    {
        AccountInfo memory info = _shareManagerStorage().accounts[account];
        return (info.canDeposit, info.canTransfer, info.isBlacklisted, info.lockedUntil);
    }

    /// @inheritdoc IShareManager
    function updateChecks(address from, address to) public view {
        ShareManagerStorage storage $ = _shareManagerStorage();
        uint256 flags_ = $.flags;
        AccountInfo memory info;
        if (from != address(0)) {
            info = $.accounts[from];
            if (block.timestamp < flags_.getGlobalLockup()) {
                revert GlobalLockupNotExpired(block.timestamp, flags_.getGlobalLockup());
            }
            if (block.timestamp < info.lockedUntil) {
                revert TargetedLockupNotExpired(block.timestamp, info.lockedUntil);
            }
            if (flags_.hasBlacklist() && info.isBlacklisted) {
                revert Blacklisted(from);
            }
            if (to != address(0)) {
                if (flags_.hasTransferPause()) {
                    revert TransferPaused();
                }
                if (flags_.hasTransferWhitelist()) {
                    if (info.canTransfer || !$.accounts[to].canTransfer) {
                        revert TransferNotAllowed(from, to);
                    }
                }
            } else {
                if (flags_.hasBurnPause()) {
                    revert BurnPaused();
                }
            }
        } else {
            if (flags_.hasMintPause()) {
                revert MintPaused();
            }
            if (to != address(0)) {
                info = $.accounts[to];
                if (flags_.hasWhitelist() && !info.canDeposit) {
                    revert NotWhitelisted(to);
                }
                if (flags_.hasBlacklist() && info.isBlacklisted) {
                    revert Blacklisted(to);
                }
            }
        }
    }

    // Mutable functions

    /// @inheritdoc IShareManager
    function claimShares(address account) public {
        IShareModule(vault()).claimShares(account);
    }

    /// @inheritdoc IShareManager
    function setAccountInfo(address account, AccountInfo memory info) external onlyRole(SET_ACCOUNT_INFO_ROLE) {
        _shareManagerStorage().accounts[account] = info;
        emit SetAccountInfo(account, info);
    }

    /// @inheritdoc IShareManager
    function setFlags(Flags calldata f) external onlyRole(SET_FLAGS_ROLE) {
        uint256 bitmask = uint256(0).setHasMintPause(f.hasMintPause).setHasBurnPause(f.hasBurnPause);
        bitmask = bitmask.setHasTransferPause(f.hasTransferPause).setHasWhitelist(f.hasWhitelist);
        bitmask = bitmask.setHasBlacklist(f.hasBlacklist).setHasTransferWhitelist(f.hasTransferWhitelist);
        bitmask = bitmask.setGlobalLockup(f.globalLockup).setTargetedLockup(f.targetedLockup);
        _shareManagerStorage().flags = bitmask;
        emit SetFlags(f);
    }

    /// @inheritdoc IShareManager
    function allocateShares(uint256 value) external onlyQueue {
        if (value == 0) {
            revert ZeroValue();
        }
        _shareManagerStorage().allocatedShares += value;
        emit AllocateShares(int256(value));
    }

    /// @inheritdoc IShareManager
    function mintAllocatedShares(address account, uint256 value) external {
        ShareManagerStorage storage $ = _shareManagerStorage();
        if (value > $.allocatedShares) {
            revert InsufficientAllocatedShares(value, $.allocatedShares);
        }
        $.allocatedShares -= value;
        emit AllocateShares(-int256(value));
        mint(account, value);
    }

    /// @inheritdoc IShareManager
    function mint(address account, uint256 value) public onlyQueue {
        if (value == 0) {
            revert ZeroValue();
        }
        _mintShares(account, value);
        ShareManagerStorage storage $ = _shareManagerStorage();
        uint32 targetLockup = $.flags.getTargetedLockup();
        if (targetLockup != 0) {
            uint32 lockedUntil = uint32(block.timestamp) + targetLockup;
            $.accounts[account].lockedUntil = lockedUntil;
            emit Mint(account, value, lockedUntil);
        } else {
            emit Mint(account, value, 0);
        }
    }

    /// @inheritdoc IShareManager
    function burn(address account, uint256 value) public onlyQueue {
        if (value == 0) {
            revert ZeroValue();
        }
        _burnShares(account, value);
        emit Burn(account, value);
    }

    // Internal functions

    function __ShareManager_init(address vault_, bytes32 whitelistMerkleRoot_) internal onlyInitializing {
        if (vault_ == address(0)) {
            revert ZeroValue();
        }
        ShareManagerStorage storage $ = _shareManagerStorage();
        $.vault = vault_;
        $.whitelistMerkleRoot = whitelistMerkleRoot_;
    }

    function _shareManagerStorage() private view returns (ShareManagerStorage storage $) {
        bytes32 slot = _shareManagerStorageSlot;
        assembly {
            $.slot := slot
        }
    }

    function _mintShares(address account, uint256 value) internal virtual;

    function _burnShares(address account, uint256 value) internal virtual;
}
