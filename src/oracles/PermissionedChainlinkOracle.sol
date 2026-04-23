// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title PermissionedChainlinkOracle
 * @notice Simple permissioned price oracle mimicking Chainlink AggregatorV3.
 * @dev Intentionally centralized — security depends fully on the owner (use multisig).
 */
contract PermissionedChainlinkOracle is Ownable {
    error InvalidPrice(); // Price out of allowed range
    error InvalidDecimals(); // Decimals > 36
    error InvalidAllowedRange(); // min > max or invalid bounds

    /// @notice Minimum allowed price (inclusive)
    int256 public immutable minAllowedAnswer;

    /// @notice Maximum allowed price (inclusive)
    int256 public immutable maxAllowedAnswer;

    /// @notice Price decimals (e.g. 8 for USD feeds)
    uint8 public immutable decimals;

    /// @notice Feed description (e.g. "ETH / USD")
    string public description;

    /// @notice Latest price answer
    int256 public latestAnswer;

    /// @notice Timestamp of the last update
    uint256 public latestTimestamp;

    /**
     * @notice Deploy and initialize the oracle
     * @param owner_ Contract owner (recommended: multisig)
     * @param decimals_ Price decimals (<= 36)
     * @param initialAnswer_ Initial price
     * @param minAllowedAnswer_ Lower bound
     * @param maxAllowedAnswer_ Upper bound
     * @param description_ Feed description
     */
    constructor(
        address owner_,
        uint8 decimals_,
        int256 initialAnswer_,
        int256 minAllowedAnswer_,
        int256 maxAllowedAnswer_,
        string memory description_
    ) Ownable(owner_) {
        if (decimals_ > 36) {
            revert InvalidDecimals();
        }
        if (minAllowedAnswer_ < 0 || minAllowedAnswer_ > maxAllowedAnswer_) {
            revert InvalidAllowedRange();
        }

        decimals = decimals_;
        minAllowedAnswer = minAllowedAnswer_;
        maxAllowedAnswer = maxAllowedAnswer_;
        description = description_;

        _set(initialAnswer_);
    }

    // -------------------------------------------------------------------------
    // VIEW FUNCTIONS
    // -------------------------------------------------------------------------

    /**
     * @notice Returns latest round data in Chainlink AggregatorV3 format
     * @dev roundId and answeredInRound are always 0 in this permissioned version
     */
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (0, latestAnswer, latestTimestamp, latestTimestamp, 0);
    }

    // -------------------------------------------------------------------------
    // MUTABLE FUNCTIONS
    // -------------------------------------------------------------------------

    /**
     * @notice Update the price (owner only)
     * @param newAnswer New price value
     */
    function updatePrice(int256 newAnswer) external onlyOwner {
        _set(newAnswer);
    }

    // -------------------------------------------------------------------------
    // INTERNAL FUNCTIONS
    // -------------------------------------------------------------------------

    /**
     * @dev Validate bounds and store new price + timestamp
     */
    function _set(int256 newAnswer) internal {
        if (newAnswer < minAllowedAnswer || newAnswer > maxAllowedAnswer) {
            revert InvalidPrice();
        }

        latestAnswer = newAnswer;
        latestTimestamp = block.timestamp;

        emit AnswerUpdated(newAnswer, 0, block.timestamp);
    }

    // -------------------------------------------------------------------------
    // EVENTS
    // -------------------------------------------------------------------------

    /**
     * @notice Emitted when price is updated
     * @param current New price value
     * @param roundId Always 0 (permissioned feed)
     * @param updatedAt Update timestamp
     */
    event AnswerUpdated(int256 indexed current, uint256 indexed roundId, uint256 updatedAt);
}
