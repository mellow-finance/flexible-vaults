// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../factories/IFactoryEntity.sol";

import "../modules/IShareModule.sol";
import "../modules/IVaultModule.sol";
import "../permissions/IConsensus.sol";
import "./IQueue.sol";

interface ISignatureQueue is IFactoryEntity {
    error ZeroValue();
    error OrderExpired(uint256 deadline);
    error InvalidCaller(address caller);
    error InvalidQueue(address queue);
    error InvalidAsset(address queue);
    error InvalidNonce(address account, uint256 nonce);
    error InvalidPrice();

    enum SignatureType {
        EIP712,
        EIP1271
    }

    struct SignatureQueueStorage {
        address consensus;
        address vault;
        address asset;
        mapping(address account => uint256 nonce) nonces;
    }

    struct Order {
        uint256 orderId;
        address queue;
        address asset;
        address caller;
        address recipient;
        uint256 ordered;
        uint256 requested;
        uint256 deadline;
        uint256 nonce;
    }

    // View functions

    function ORDER_TYPEHASH() external view returns (bytes32);

    function consensus() external view returns (IConsensus);

    function nonces(address account) external view returns (uint256);

    function hashOrder(Order calldata order) external view returns (bytes32);

    function validateOrder(Order calldata order, IConsensus.Signature[] calldata signatures) external view;

    function vault() external view returns (address);

    function asset() external view returns (address);

    function claimableOf(address account) external view returns (uint256);

    function claim(address account) external returns (uint256);

    function canBeRemoved() external pure returns (bool);

    function handleReport(uint224 priceD18, uint32 latestEligibleTimestamp) external view;

    // Events

    event OrderExecuted(Order order, IConsensus.Signature[] signatures);
}
