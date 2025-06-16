// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/shares/ISharesManager.sol";

import "../libraries/MerkleHashingLibrary.sol";
import "../libraries/PermissionsLibrary.sol";
import "../libraries/SharesManagerFlagLibrary.sol";

abstract contract SharesManager is ISharesManager, ContextUpgradeable {
    using SharesManagerFlagLibrary for uint256;

    address public immutable vault;

    uint256 public flags;
    uint256 public allocatedShares;
    uint256 public sharesLimit;
    bytes32 public whitelistMerkleRoot;

    mapping(address account => AccountInfo) public accounts;

    // View functions

    modifier onlyDepositQueue() {
        require(IDepositModule(vault).hasDepositQueue(_msgSender()), "SharesManager: caller is not a deposit queue");
        _;
    }

    modifier onlyRedeemQueue() {
        require(IRedeemModule(vault).hasRedeemQueue(_msgSender()), "SharesManager: caller is not a redeem queue");
        _;
    }

    modifier onlyRole(bytes32 role) {
        require(IACLModule(vault).hasRole(role, _msgSender()), "SharesManager: caller does not have the required role");
        _;
    }

    function isDepositorWhitelisted(address account, bytes32[] calldata merkleProof) public view returns (bool) {
        if (flags.hasWhitelist() && !accounts[account].canDeposit) {
            return false;
        }
        bytes32 whitelistMerkleRoot_ = whitelistMerkleRoot;
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
        if (!flags.hasDepositQueues()) {
            return 0;
        }
        return IDepositModule(vault).claimableSharesOf(account);
    }

    function activeSharesOf(address account) public view virtual returns (uint256);

    function activeShares() public view virtual returns (uint256);

    function totalShares() public view returns (uint256) {
        return allocatedShares + activeShares();
    }

    // Mutable functions

    function setAccountInfo(address account, AccountInfo memory info)
        external
        onlyRole(PermissionsLibrary.SET_ACCOUNT_INFO_ROLE)
    {
        accounts[account] = info;
    }

    function setFlags(uint256 flags_) external onlyRole(PermissionsLibrary.SET_FLAGS_ROLE) {
        flags = flags_;
    }

    function allocateShares(uint256 value) external onlyDepositQueue {
        allocatedShares += value;
    }

    function mintAllocatedShares(address account, uint256 value) external {
        allocatedShares -= value;
        mint(account, value);
    }

    function mint(address account, uint256 value) public onlyDepositQueue {
        _mintShares(account, value);
        uint32 targetLockup = flags.getTargetedLockup();
        if (targetLockup != 0) {
            accounts[account].lockedUntil = uint32(block.timestamp) + targetLockup;
        }
    }

    function burn(address account, uint256 value) public onlyRedeemQueue {
        _burnShares(account, value);
    }

    function updateChecks(address from, address to, uint256 value) public view {
        uint256 flags_ = flags;
        AccountInfo memory info;
        if (from != address(0)) {
            info = accounts[from];
            if (block.timestamp < flags_.getGlobalLockup()) {
                revert("SharesManager: global lockup is active");
            }
            if (block.timestamp < info.lockedUntil) {
                revert("SharesManager: targeted lockup is active");
            }
            if (flags_.hasBlacklist() && info.isBlacklisted) {
                revert("SharesManager: sender is blacklisted");
            }
            if (to != address(0)) {
                if (flags_.hasTransferPause()) {
                    revert("SharesManager: transfers are paused");
                }
                if (flags_.hasTransferWhitelist()) {
                    if (info.canTransfer || !accounts[to].canTransfer) {
                        revert("SharesManager: transfer is not whitelisted");
                    }
                }
            } else {
                if (flags_.hasBurnPause()) {
                    revert("SharesManager: burning is paused");
                }
            }
        } else {
            if (flags_.hasMintPause()) {
                revert("SharesManager: minting is paused");
            }
            if (totalShares() + value > sharesLimit) {
                revert("SharesManager: shares limit exceeded");
            }
            if (to != address(0)) {
                info = accounts[to];
                if (flags_.hasWhitelist() && !info.canDeposit) {
                    revert("SharesManager: recipient is not whitelisted");
                }
                if (flags_.hasBlacklist() && info.isBlacklisted) {
                    revert("SharesManager: recipient is blacklisted");
                }
            }
        }
    }

    // Internal functions

    function _mintShares(address account, uint256 value) internal virtual;

    function _burnShares(address account, uint256 value) internal virtual;
}
