// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import "../modules/IACLModule.sol";
import "../modules/IDepositModule.sol";
import "../modules/IRedeemModule.sol";
import "../modules/ISharesModule.sol";

interface ISharesManager {
    struct SharesManagerStorage {
        address vault;
        uint256 flags;
        uint256 allocatedShares;
        uint256 sharesLimit;
        bytes32 whitelistMerkleRoot;
        mapping(address account => AccountInfo) accounts;
    }

    struct AccountInfo {
        bool canDeposit;
        bool canTransfer;
        bool isBlacklisted;
        uint32 lockedUntil;
    }

    function vault() external view returns (address);

    function allocatedShares() external view returns (uint256);

    function flags() external view returns (uint256);

    function whitelistMerkleRoot() external view returns (bytes32);

    function sharesLimit() external view returns (uint256);

    // function accounts(address account)
    //     external
    //     view
    //     returns (
    //         bool isSubjectToLockup,
    //         bool isWhitelisted,
    //         bool isAllowedTransferRecipient,
    //         bool isBlacklisted,
    //         uint32 lockedUntil
    //     );

    function isDepositorWhitelisted(address account, bytes32[] calldata merkleProof) external view returns (bool);

    function sharesOf(address account) external view returns (uint256);

    function claimableSharesOf(address account) external view returns (uint256);

    function activeSharesOf(address account) external view returns (uint256);

    function activeShares() external view returns (uint256);

    function totalShares() external view returns (uint256);

    function setFlags(uint256 flags_) external;

    function allocateShares(uint256 shares) external;

    function mintAllocatedShares(address to, uint256 shares) external;

    function mint(address to, uint256 shares) external;

    function burn(address account, uint256 amount) external;
}
