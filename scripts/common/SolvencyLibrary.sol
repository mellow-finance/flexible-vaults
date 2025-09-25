// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {VmSafe} from "forge-std/Vm.sol";

import "./interfaces/Imports.sol";

import "./ArraysLibrary.sol";
import "./Permissions.sol";
import "./ProofLibrary.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "./RandomLib.sol";

library SolvencyLibrary {
    using RandomLib for RandomLib.Storage;

    function _this() private pure returns (VmSafe) {
        return VmSafe(address(uint160(uint256(keccak256("hevm cheat code")))));
    }

    enum Transitions {
        CREATE_DEPOSIT_REQUEST,
        CANCEL_DEPOSIT_REQUEST,
        CREATE_REDEEM_REQUEST,
        HANDLE_BATCHES,
        ORACLE_REPORT,
        SUPPLY_AAVE,
        BORROW_AAVE,
        CREATE_COWSWAP_ORDER,
        EXECUTE_COWSWAP_ORDER,
        IGNORE_COWSWAP_ORDER,
        HANDLE_REDEEMS
    }

    struct State {
        uint256 x;
    }

    function createDepositRequest(RandomLib.Storage storage rnd, VaultDeployment memory $) internal {}
}
