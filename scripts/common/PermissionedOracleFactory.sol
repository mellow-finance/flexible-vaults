// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {PermissionedChainlinkOracle} from "../../src/oracles/PermissionedChainlinkOracle.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

/// @title PermissionedOracleFactory
/// @notice Factory for deploying deterministic PermissionedChainlinkOracle instances using CREATE2
/// @dev Same InitParams always produce the same oracle address
contract PermissionedOracleFactory {
    error AlreadyDeployed();

    using EnumerableMap for EnumerableMap.Bytes32ToAddressMap;

    /// @notice Parameters required to initialize a new oracle
    struct InitParams {
        address owner; // Owner of the new oracle
        uint8 decimals; // Price feed decimals (e.g. 8)
        int256 initialAnswer; // Starting answer value
        int256 minAllowedAnswer; // Lower bound for valid answers
        int256 maxAllowedAnswer; // Upper bound for valid answers
        string description; // Human-readable oracle description
    }

    /// @dev salt => oracle address (enumerable for off-chain indexing)
    EnumerableMap.Bytes32ToAddressMap private _oracles;

    /// @notice Returns how many oracles this factory has created
    function length() external view returns (uint256) {
        return _oracles.length();
    }

    /// @notice Returns salt and oracle at a given index (for enumeration)
    function at(uint256 index) external view returns (bytes32 salt, address oracle) {
        return _oracles.at(index);
    }

    /// @notice Returns oracle address for a salt (reverts if not found)
    function get(bytes32 salt) external view returns (address oracle) {
        return _oracles.get(salt);
    }

    /// @notice Computes deterministic CREATE2 salt from init parameters
    function getSalt(InitParams calldata params) public pure returns (bytes32) {
        return keccak256(abi.encode(params));
    }

    /// @notice Deploys a new oracle with deterministic address
    /// @dev Reverts with AlreadyDeployed if identical params were used before
    /// @return oracle Address of the newly created oracle
    function create(InitParams calldata params) external returns (address oracle) {
        bytes32 salt = getSalt(params);
        if (_oracles.contains(salt)) {
            revert AlreadyDeployed();
        }

        oracle = address(
            new PermissionedChainlinkOracle{salt: salt}(
                params.owner,
                params.decimals,
                params.initialAnswer,
                params.minAllowedAnswer,
                params.maxAllowedAnswer,
                params.description
            )
        );

        _oracles.set(salt, oracle);

        emit Created(oracle, params);
    }

    /// @notice Emitted when a new oracle is created
    event Created(address indexed oracle, InitParams params);
}
