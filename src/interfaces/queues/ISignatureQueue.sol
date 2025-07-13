// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../factories/IFactory.sol";
import "../factories/IFactoryEntity.sol";

import "../modules/IShareModule.sol";
import "../modules/IVaultModule.sol";
import "../permissions/IConsensus.sol";
import "./IQueue.sol";

/// @title ISignatureQueue
/// @notice Interface for signature-based queues supporting instant deposit and withdrawal approvals via off-chain consensus.
/// @dev Implements fast-lane asset processing using EIP-712 or EIP-1271 signed messages from trusted consensus actors.
///
/// # Overview
/// A `SignatureQueue` enables instant deposits or redemptions by relying on signatures produced off-chain by a consensus group.
/// Instead of queuing requests on-chain and waiting for an oracle report, trusted users can present signed approvals that authorize their actions.
/// This offers a faster alternative to time-delayed queues while still ensuring integrity via oracle-bound price validation.
///
/// # Security Assumptions
/// - A trusted consensus group is responsible for signing approvals.
/// - Off-chain signers are expected to use oracle-compatible pricing when issuing approvals.
/// - On-chain signature verification must conform to EIP-712 or EIP-1271 standards.
/// - Price validation is still enforced on-chain using default oracle bounds.
///
/// # Limitations
/// This mechanism bypasses normal queueing, deposit and redeem fees. Thus, signature queues are generally used in parallel with deposit/redeem queues,
/// and are subject to stricter trust assumptions regarding off-chain actors.
interface ISignatureQueue is IFactoryEntity {
    /// @notice Thrown when a required value is zero.
    error ZeroValue();

    /// @notice Thrown when the address is not registered as a valid entity.
    error NotEntity();

    /// @notice Thrown when the order has already expired.
    error OrderExpired(uint256 deadline);

    /// @notice Thrown when a function is called by an invalid or unauthorized address.
    error InvalidCaller(address caller);

    /// @notice Thrown when the order references a queue that doesn't match `address(this)`.
    error InvalidQueue(address queue);

    /// @notice Thrown when the asset used in the order is not the one bound to the queue.
    error InvalidAsset(address asset);

    /// @notice Thrown when the provided nonce is incorrect for the account.
    error InvalidNonce(address account, uint256 nonce);

    /// @notice Thrown when the price computed during validation is not valid.
    error InvalidPrice();

    /// @notice Supported signature types for order validation.
    enum SignatureType {
        EIP712,
        EIP1271
    }

    /// @notice Storage layout for the SignatureQueue contract.
    /// @dev Tracks consensus configuration, asset context, and per-user signature nonces.
    struct SignatureQueueStorage {
        /// @notice Address of the associated Consensus contract.
        /// @dev Used to validate off-chain approvals via EIP-712 or EIP-1271.
        address consensus;
        /// @notice Address of the parent Vault contract.
        address vault;
        /// @notice Address of the asset managed by this queue (e.g., ERC20 or native ETH).
        address asset;
        /// @notice Mapping of user nonces to prevent signature replay attacks.
        /// @dev Each user has an incrementing nonce that must be included in signed messages.
        mapping(address account => uint256 nonce) nonces;
    }

    /// @notice EIP-712 compatible order structure used for off-chain approvals in SignatureQueue.
    /// @dev Represents a deposit or redeem intent authorized by a consensus group via signature.
    struct Order {
        /// @notice Unique identifier for this order (off-chain tracking).
        uint256 orderId;
        /// @notice Address of this queue contract expected to process this order.
        /// @dev Used to bind the order to a specific queue instance.
        address queue;
        /// @notice Address of the asset involved (ERC20 token or native ETH).
        address asset;
        /// @notice Address that initiated the off-chain request (signer or proxy).
        address caller;
        /// @notice Address that will receive the assets or resulting shares.
        address recipient;
        /// @notice Amount of shares or assets being provided in the request.
        /// @dev Interpreted as assets for deposit, or shares for redeem.
        uint256 ordered;
        /// @notice Amount of shares or assets expected in return.
        /// @dev Interpreted as shares for deposit, or assets for redeem.
        uint256 requested;
        /// @notice Expiration timestamp after which the order is no longer valid.
        uint256 deadline;
        /// @notice Nonce value for replay protection.
        /// @dev Must match current user nonce stored in SignatureQueueStorage to be valid.
        uint256 nonce;
    }

    /// @notice Returns the EIP-712 type hash for the `Order` struct.
    /// @dev This is used to compute the EIP-712 digest for signature verification.
    /// @return typeHash The keccak256 hash of the EIP-712 type definition for `Order`.
    function ORDER_TYPEHASH() external view returns (bytes32 typeHash);

    /// @notice Returns the factory that deploys consensus contracts.
    function consensusFactory() external view returns (IFactory);

    /// @notice Returns the current consensus contract responsible for signature validation.
    function consensus() external view returns (IConsensus);

    /// @notice Returns the current nonce for a given account.
    /// @param account Address of the user.
    /// @return Nonce that must be used in the next order.
    function nonces(address account) external view returns (uint256);

    /// @notice Computes the hash of an order for EIP-712 signature validation.
    /// @param order The structured order to be hashed.
    /// @return The EIP-712 hash digest.
    function hashOrder(Order calldata order) external view returns (bytes32);

    /// @notice Validates a signed order and ensures it meets all queue and consensus checks.
    /// @param order The order being validated.
    /// @param signatures Validator signatures conforming to the consensus contract.
    function validateOrder(Order calldata order, IConsensus.Signature[] calldata signatures) external view;

    /// @notice Returns the address of the connected vault.
    function vault() external view returns (address);

    /// @notice Returns the address of the asset this queue supports.
    function asset() external view returns (address);

    /// @notice Always returns true to indicate signature queues are stateless and removable.
    function canBeRemoved() external pure returns (bool);

    /// @notice Always returns zero.
    /// @dev Included for compatibility with other queue interfaces. This queue does not accumulate claimable shares.
    /// @return claimable Always returns 0.
    function claimableOf(address) external view returns (uint256 claimable);

    /// @notice Always returns false.
    /// @dev Included for compatibility with queue interfaces that support claim functionality. No claims are processed by this queue.
    /// @return success Always returns false.
    function claim(address) external returns (bool success);

    /// @notice No-op placeholder for compatibility.
    /// @dev Stub for interface compatibility. This queue does not process oracle reports.
    function handleReport(uint224, uint32) external view;

    /// @notice Emitted after a signed order is successfully validated and executed.
    /// @param order The executed order.
    /// @param signatures The validator signatures used for consensus.
    event OrderExecuted(Order order, IConsensus.Signature[] signatures);
}
