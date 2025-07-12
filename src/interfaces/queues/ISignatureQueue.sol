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
/// @notice Interface for queues that rely on off-chain consensus-based approvals via EIP-712 or EIP-1271 signatures.
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

    /// @notice Persistent storage layout for the signature queue.
    struct SignatureQueueStorage {
        address consensus;
        address vault;
        address asset;
        mapping(address account => uint256 nonce) nonces;
    }

    /// @notice Structure used for off-chain order authorization via signatures.
    struct Order {
        uint256 orderId;
        /// Unique order identifier.
        address queue;
        /// Address of the queue contract expected to process this order.
        address asset;
        /// Address of the ERC20 or ETH asset involved.
        address caller;
        /// Original sender/initiator of the request.
        address recipient;
        /// Address that will receive the assets or result.
        uint256 ordered;
        /// Amount of shares or assets sent in the request.
        uint256 requested;
        /// Amount of assets or shares expected in return.
        uint256 deadline;
        /// Timestamp after which the order is invalid.
        uint256 nonce;
    }
    /// Nonce for replay protection.

    /// @notice Returns the type hash used for signing EIP-712 orders.
    function ORDER_TYPEHASH() external view returns (bytes32);

    /// @notice Returns the factory that deploys and verifies consensus contracts.
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

    /// @notice Returns the amount of tokens currently claimable by a given account.
    /// @param account User address.
    /// @return Amount of claimable assets.
    function claimableOf(address account) external view returns (uint256);

    /// @notice Claims any pending asset balance for the specified account.
    /// @param account Address for which the claim should be executed.
    /// @return Amount of assets claimed.
    function claim(address account) external returns (uint256);

    /// @notice Always returns true to indicate signature queues are stateless and removable.
    function canBeRemoved() external pure returns (bool);

    /// @notice Stub for compatibility; does not do anything in signature queues.
    /// @param priceD18 Price in 18-decimal fixed point.
    /// @param latestEligibleTimestamp The timestamp associated with the price.
    function handleReport(uint224 priceD18, uint32 latestEligibleTimestamp) external view;

    /// @notice Emitted after a signed order is successfully validated and executed.
    /// @param order The executed order.
    /// @param signatures The validator signatures used for consensus.
    event OrderExecuted(Order order, IConsensus.Signature[] signatures);
}
