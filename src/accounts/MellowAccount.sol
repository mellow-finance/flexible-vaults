// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IFactoryEntity} from "../interfaces/factories/IFactoryEntity.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

contract MellowAccount is IFactoryEntity, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    struct Call {
        address target;
        bytes data;
    }

    // @inheritdoc IFactoryEntity
    function initialize(bytes memory initData) external initializer {
        __Ownable_init(abi.decode(initData, (address)));
        __ReentrancyGuard_init();
    }

    function multicall(Call[] calldata calls) external nonReentrant onlyOwner returns (bytes[] memory results) {
        results = new bytes[](calls.length);
        for (uint256 i = 0; i < calls.length; i++) {
            results[i] = Address.functionCall(calls[i].target, calls[i].data);
        }
    }
}
