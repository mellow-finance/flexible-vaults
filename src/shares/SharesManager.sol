// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../libraries/SharesManagerFlagLibrary.sol";
import "../modules/DepositModule.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

abstract contract SharesManager {
    using SharesManagerFlagLibrary for uint256;

    bytes32 public constant SET_FLAGS_ROLE = keccak256("SHARES_MANAGER:SET_FLAGS_ROLE");
    address payable public immutable vault;

    uint256 public flags;
    bytes32 public whitelistMerkleRoot;
    mapping(address account => bool) public isSubjectToLockup;
    mapping(address account => uint256) public lockedUntil;
    mapping(address account => bool) public isWhitelisted;
    mapping(address account => bool) public isBlacklisted;

    function isDepositAllowed(address account, bytes32[] calldata proof)
        public
        view
        returns (bool)
    {
        if (flags.hasMintPause()) {
            return false;
        }
        if (flags.hasMappingWhitelist() && !isWhitelisted[account]) {
            return false;
        }
        if (
            flags.hasMerkleWhitelist()
                && !MerkleProof.verify(
                    proof, whitelistMerkleRoot, keccak256(bytes.concat(keccak256(abi.encode(account))))
                )
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
        return DepositModule(vault).claimableSharesOf(account);
    }

    // Setters
    function setFlags(uint256 flags_) external {
        require(
            IAccessControl(vault).hasRole(SET_FLAGS_ROLE, msg.sender),
            "SharesManager: Caller is not authorized to set flags"
        );
        flags = flags_;
    }

    // Virtual functcions

    function activeSharesOf(address account) public view virtual returns (uint256);

    function mintShares(address to, uint256 shares) external virtual;

    function allocateShares(uint256 shares) external virtual;

    function mintAllocatedShares(address to, uint256 shares) external virtual;

    function pullShares(address from, uint256 amount) external virtual;

    function burnShares(address from, uint256 amount) external virtual;

    // Events

    event SharesMinted(address indexed to, uint256 amount);

    event SharesBurned(address indexed from, uint256 amount);
}
