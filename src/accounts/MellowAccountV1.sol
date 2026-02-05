// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IFactoryEntity} from "../interfaces/factories/IFactoryEntity.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

contract MellowAccountV1 is IFactoryEntity, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    struct Call {
        address target;
        bytes data;
    }

    constructor() {
        _disableInitializers();
    }

    // @inheritdoc IFactoryEntity
    function initialize(bytes memory data) external initializer {
        __Ownable_init(abi.decode(data, (address)));
        __ReentrancyGuard_init();
        emit Initialized(data);
    }

    function multicall(Call[] calldata calls) external nonReentrant onlyOwner returns (bytes[] memory results) {
        results = new bytes[](calls.length);
        for (uint256 i = 0; i < calls.length; i++) {
            results[i] = Address.functionCall(calls[i].target, calls[i].data);
        }
        emit Executed(_msgSender());
    }

    event Executed(address indexed caller);
}
