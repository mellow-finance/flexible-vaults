// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @dev PositionInfo is a packed version of solidity structure.
 * Using the packaged version saves gas and memory by not storing the structure fields in memory slots.
 *
 * Layout:
 * 200 bits poolId | 24 bits tickUpper | 24 bits tickLower | 8 bits hasSubscriber
 *
 * Fields in the direction from the least significant bit:
 *
 * A flag to know if the tokenId is subscribed to an address
 * uint8 hasSubscriber;
 *
 * The tickUpper of the position
 * int24 tickUpper;
 *
 * The tickLower of the position
 * int24 tickLower;
 *
 * The truncated poolId. Truncates a bytes32 value so the most signifcant (highest) 200 bits are used.
 * bytes25 poolId;
 *
 * Note: If more bits are needed, hasSubscriber can be a single bit.
 *
 */
type PositionInfo is uint256;

using PositionInfoLibrary for PositionInfo global;

library PositionInfoLibrary {
    uint256 internal constant MASK_UPPER_200_BITS = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00000000000000;
    uint256 internal constant MASK_8_BITS = 0xFF;
    uint24 internal constant MASK_24_BITS = 0xFFFFFF;
    uint256 internal constant SET_UNSUBSCRIBE = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00;
    uint256 internal constant SET_SUBSCRIBE = 0x01;
    uint8 internal constant TICK_LOWER_OFFSET = 8;
    uint8 internal constant TICK_UPPER_OFFSET = 32;

    /// @dev This poolId is NOT compatible with the poolId used in UniswapV4 core. It is truncated to 25 bytes, and just used to lookup PoolKey in the poolKeys mapping.
    function poolId(uint256 info) internal pure returns (bytes25 _poolId) {
        assembly ("memory-safe") {
            _poolId := and(MASK_UPPER_200_BITS, info)
        }
    }

    function tickLower(uint256 info) internal pure returns (int24 _tickLower) {
        assembly ("memory-safe") {
            _tickLower := signextend(2, shr(TICK_LOWER_OFFSET, info))
        }
    }

    function tickUpper(uint256 info) internal pure returns (int24 _tickUpper) {
        assembly ("memory-safe") {
            _tickUpper := signextend(2, shr(TICK_UPPER_OFFSET, info))
        }
    }

    function hasSubscriber(uint256 info) internal pure returns (bool _hasSubscriber) {
        assembly ("memory-safe") {
            _hasSubscriber := and(MASK_8_BITS, info)
        }
    }
}
