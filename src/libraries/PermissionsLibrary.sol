// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

library PermissionsLibrary {
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    bytes32 public constant SET_MIN_DEPOSIT_ROLE = keccak256("DEPOSIT_MODULE:SET_MIN_DEPOSIT_ROLE");
    bytes32 public constant SET_MAX_DEPOSIT_ROLE = keccak256("DEPOSIT_MODULE:SET_MAX_DEPOSIT_ROLE");
    bytes32 public constant SET_DEPOSIT_HOOK_ROLE = keccak256("DEPOSIT_MODULE:SET_DEPOSIT_HOOK_ROLE");
    bytes32 public constant CREATE_DEPOSIT_QUEUE_ROLE = keccak256("DEPOSIT_MODULE:CREATE_DEPOSIT_QUEUE_ROLE");
    bytes32 public constant SET_PARENT_MODULE_ROLE = keccak256("NODE_MODULE:SET_PARENT_MODULE_ROLE");
    bytes32 public constant CONNECT_CHILD_NODE_ROLE = keccak256("NODE_MODULE:CONNECT_CHILD_NODE_ROLE");
    bytes32 public constant PULL_LIQUIDITY_ROLE = keccak256("NODE_MODULE:PULL_LIQUIDITY_ROLE");
    bytes32 public constant PUSH_LIQUIDITY_ROLE = keccak256("NODE_MODULE:PUSH_LIQUIDITY_ROLE");
    bytes32 public constant SET_CORRECTIONS_ROLE = keccak256("NODE_MODULE:SET_CORRECTIONS_ROLE");
    bytes32 public constant SET_LIMITS_ROLE = keccak256("NODE_MODULE:SET_LIMITS_ROLE");

    bytes32 public constant SET_MIN_REDEEM_ROLE = keccak256("REDEEM_MODULE.SET_MIN_REDEEM_ROLE");
    bytes32 public constant SET_MAX_REDEEM_ROLE = keccak256("REDEEM_MODULE.SET_MAX_REDEEM_ROLE");
    bytes32 public constant CREATE_WITHDRAWAL_QUEUE_ROLE = keccak256("REDEEM_MODULE.CREATE_WITHDRAWAL_QUEUE_ROLE");

    bytes32 public constant REPORT_PRICES_ROLE = keccak256("ORACLE:REPORT_PRICES_ROLE");
    bytes32 public constant SET_MAX_ABSOLUTE_DEVIATION_ROLE = keccak256("ORACLE:SET_MAX_ABSOLUTE_DEVIATION_ROLE");
    bytes32 public constant SET_MAX_RELATIVE_DEVIATION_ROLE = keccak256("ORACLE:SET_MAX_RELATIVE_DEVIATION_ROLE");
    bytes32 public constant SET_TIMEOUT_ROLE = keccak256("ORACLE:SET_TIMEOUT_ROLE");
    bytes32 public constant SET_DEPOSIT_SECURE_T_ROLE = keccak256("ORACLE:SET_DEPOSIT_SECURE_T_ROLE");
    bytes32 public constant SET_REDEEM_SECURE_T_ROLE = keccak256("ORACLE:SET_REDEEM_SECURE_T_ROLE");
    bytes32 public constant UNLOCK_ROLE = keccak256("ORACLE:UNLOCK_ROLE");

    bytes32 public constant SET_MERKLE_ROOT_ROLE = keccak256("VERIFIER:SET_MERKLE_ROOT_ROLE");
    bytes32 public constant CALL_ROLE = keccak256("VERIFIER:CALL_ROLE");
    bytes32 public constant ADD_ALLOWED_CALLS_ROLE = keccak256("VERIFIER:ADD_ALLOWED_CALLS_ROLE");
    bytes32 public constant REMOVE_ALLOWED_CALLS_ROLE = keccak256("VERIFIER:REMOVE_ALLOWED_CALLS_ROLE");

    bytes32 public constant SET_FLAGS_ROLE = keccak256("SHARES_MANAGER:SET_FLAGS_ROLE");

    bytes32 public constant ADD_SUVAULT_ROLE = keccak256("FACTORY_MODULE:ADD_SUVAULT_ROLE");
}
