// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./ICustomOracle.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract FEOracle is Ownable {
    mapping(address vault => ICustomOracle.Data) private _oracles;

    constructor(address owner) Ownable(owner) {}

    function tvl(address vault) external view returns (uint256) {
        ICustomOracle.Data memory data = _oracles[vault];
        address oracle = data.oracle;
        if (oracle == address(0)) {
            revert("FEOracle: oracle not set");
        }
        try ICustomOracle(oracle).tvl(vault, data) returns (uint256 v) {
            return v;
        } catch {}
        return ICustomOracle(oracle).tvl(vault, data.denominator);
    }

    function getOracle(address vault) external view returns (ICustomOracle.Data memory) {
        return _oracles[vault];
    }

    function setOracle(address vault, address oracle, address denominator, string memory metadata) external onlyOwner {
        _oracles[vault] = ICustomOracle.Data(oracle, block.timestamp, denominator, metadata);
        emit OracleSet(vault, oracle, denominator, metadata);
    }

    event OracleSet(address indexed vault, address oracle, address denominator, string metadata);
}
