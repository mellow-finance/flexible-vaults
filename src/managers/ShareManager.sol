// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/managers/IShareManager.sol";

import "../libraries/MerkleHashingLibrary.sol";
import "../libraries/PermissionsLibrary.sol";
import "../libraries/ShareManagerFlagLibrary.sol";
import "../libraries/SlotLibrary.sol";

abstract contract ShareManager is IShareManager, ContextUpgradeable {
    using ShareManagerFlagLibrary for uint256;

    bytes32 private immutable _shareManagerStorageSlot;

    constructor(string memory name_, uint256 version_) {
        _shareManagerStorageSlot = SlotLibrary.getSlot("ShareManager", name_, version_);
        _disableInitializers();
    }

    // View functions

    modifier onlyQueue() {
        require(
            IShareModule(_shareManagerStorage().vault).hasQueue(_msgSender()), "ShareManager: caller is not a queue"
        );
        _;
    }

    modifier onlyRole(bytes32 role) {
        require(
            IACLModule(_shareManagerStorage().vault).hasRole(role, _msgSender()),
            "ShareManager: caller does not have the required role"
        );
        _;
    }

    function isDepositorWhitelisted(address account, bytes32[] calldata merkleProof) public view returns (bool) {
        ShareManagerStorage storage $ = _shareManagerStorage();
        if ($.flags.hasWhitelist() && !$.accounts[account].canDeposit) {
            return false;
        }
        bytes32 whitelistMerkleRoot_ = $.whitelistMerkleRoot;
        if (
            whitelistMerkleRoot_ != bytes32(0)
                && !MerkleProof.verify(merkleProof, whitelistMerkleRoot_, MerkleHashingLibrary.hash(account))
        ) {
            return false;
        }
        return true;
    }

    function sharesOf(address account) public view returns (uint256) {
        return activeSharesOf(account) + claimableSharesOf(account);
    }

    function claimableSharesOf(address account) public view returns (uint256) {
        return IShareModule(_shareManagerStorage().vault).claimableSharesOf(account);
    }

    function activeSharesOf(address account) public view virtual returns (uint256);

    function activeShares() public view virtual returns (uint256);

    function totalShares() public view returns (uint256) {
        return _shareManagerStorage().allocatedShares + activeShares();
    }

    function vault() public view returns (address) {
        return _shareManagerStorage().vault;
    }

    function allocatedShares() public view returns (uint256) {
        return _shareManagerStorage().allocatedShares;
    }

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

    function whitelistMerkleRoot() public view returns (bytes32) {
        return _shareManagerStorage().whitelistMerkleRoot;
    }

    function sharesLimit() public view returns (uint256) {
        return _shareManagerStorage().sharesLimit;
    }

    function accounts(address account)
        public
        view
        returns (bool canDeposit, bool canTransfer, bool isBlacklisted, uint232 lockedUntil)
    {
        ShareManagerStorage storage $ = _shareManagerStorage();
        AccountInfo memory info = $.accounts[account];
        return (info.canDeposit, info.canTransfer, info.isBlacklisted, info.lockedUntil);
    }

    // Mutable functions

    function claimShares(address account) public {
        IShareModule(vault()).claimShares(account);
    }

    function setAccountInfo(address account, AccountInfo memory info)
        external
        onlyRole(PermissionsLibrary.SET_ACCOUNT_INFO_ROLE)
    {
        _shareManagerStorage().accounts[account] = info;
    }

    function setFlags(Flags calldata f) external onlyRole(PermissionsLibrary.SET_FLAGS_ROLE) {
        uint256 bitmask = uint256(0).setHasMintPause(f.hasMintPause).setHasBurnPause(f.hasBurnPause);
        bitmask = bitmask.setHasTransferPause(f.hasTransferPause).setHasWhitelist(f.hasWhitelist);
        bitmask = bitmask.setHasBlacklist(f.hasBlacklist).setHasTransferWhitelist(f.hasTransferWhitelist);
        bitmask = bitmask.setGlobalLockup(f.globalLockup).setTargetedLockup(f.targetedLockup);
        _shareManagerStorage().flags = bitmask;
    }

    function allocateShares(uint256 value) external onlyQueue {
        _shareManagerStorage().allocatedShares += value;
    }

    function mintAllocatedShares(address account, uint256 value) external {
        ShareManagerStorage storage $ = _shareManagerStorage();
        if (value > $.allocatedShares) {
            revert("ShareManager: insufficient allocated shares");
        }
        $.allocatedShares -= value;
        mint(account, value);
    }

    function mint(address account, uint256 value) public onlyQueue {
        _mintShares(account, value);
        ShareManagerStorage storage $ = _shareManagerStorage();
        uint32 targetLockup = $.flags.getTargetedLockup();
        if (targetLockup != 0) {
            $.accounts[account].lockedUntil = uint32(block.timestamp) + targetLockup;
        }
    }

    function burn(address account, uint256 value) public onlyQueue {
        _burnShares(account, value);
    }

    function updateChecks(address from, address to, uint256 value) public view {
        ShareManagerStorage storage $ = _shareManagerStorage();
        uint256 flags_ = $.flags;
        AccountInfo memory info;
        if (from != address(0)) {
            info = $.accounts[from];
            if (block.timestamp < flags_.getGlobalLockup()) {
                revert("ShareManager: global lockup is active");
            }
            if (block.timestamp < info.lockedUntil) {
                revert("ShareManager: targeted lockup is active");
            }
            if (flags_.hasBlacklist() && info.isBlacklisted) {
                revert("ShareManager: sender is blacklisted");
            }
            if (to != address(0)) {
                if (flags_.hasTransferPause()) {
                    revert("ShareManager: transfers are paused");
                }
                if (flags_.hasTransferWhitelist()) {
                    if (info.canTransfer || !$.accounts[to].canTransfer) {
                        revert("ShareManager: transfer is not whitelisted");
                    }
                }
            } else {
                if (flags_.hasBurnPause()) {
                    revert("ShareManager: burning is paused");
                }
            }
        } else {
            if (flags_.hasMintPause()) {
                revert("ShareManager: minting is paused");
            }
            if (totalShares() + value > $.sharesLimit) {
                revert("ShareManager: shares limit exceeded");
            }
            if (to != address(0)) {
                info = $.accounts[to];
                if (flags_.hasWhitelist() && !info.canDeposit) {
                    revert("ShareManager: recipient is not whitelisted");
                }
                if (flags_.hasBlacklist() && info.isBlacklisted) {
                    revert("ShareManager: recipient is blacklisted");
                }
            }
        }
    }

    // Internal functions

    function __ShareManager_init(address vault_, bytes32 whitelistMerkleRoot_, uint256 sharesLimit_)
        internal
        onlyInitializing
    {
        require(vault_ != address(0), "ShareManager: vault cannot be zero address");
        ShareManagerStorage storage $ = _shareManagerStorage();
        $.vault = vault_;
        $.whitelistMerkleRoot = whitelistMerkleRoot_;
        $.sharesLimit = sharesLimit_;
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
