// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

library PermissionsLibrary {
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    bytes32 public constant SET_MIN_DEPOSIT_ROLE = keccak256("DEPOSIT_MODULE:SET_MIN_DEPOSIT_ROLE");
    bytes32 public constant SET_MAX_DEPOSIT_ROLE = keccak256("DEPOSIT_MODULE:SET_MAX_DEPOSIT_ROLE");
    bytes32 public constant SET_DEPOSIT_HOOK_ROLE = keccak256("DEPOSIT_MODULE:SET_DEPOSIT_HOOK_ROLE");
    bytes32 public constant CREATE_DEPOSIT_QUEUE_ROLE = keccak256("DEPOSIT_MODULE:CREATE_DEPOSIT_QUEUE_ROLE");

    bytes32 public constant SET_MIN_REDEEM_ROLE = keccak256("REDEEM_MODULE.SET_MIN_REDEEM_ROLE");
    bytes32 public constant SET_MAX_REDEEM_ROLE = keccak256("REDEEM_MODULE.SET_MAX_REDEEM_ROLE");
    bytes32 public constant CREATE_WITHDRAWAL_QUEUE_ROLE = keccak256("REDEEM_MODULE.CREATE_WITHDRAWAL_QUEUE_ROLE");

    bytes32 public constant SEND_REPORT_ROLE = keccak256("ORACLE:SEND_REPORT_ROLE");
    bytes32 public constant ACCEPT_REPORT_ROLE = keccak256("ORACLE:ACCEPT_REPORT_ROLE");
    bytes32 public constant SET_SECURITY_PARAMS_ROLE = keccak256("ORACLE:SET_SECURITY_PARAMS_ROLE");
    bytes32 public constant ADD_SUPPORTED_ASSETS_ROLE = keccak256("ORACLE:ADD_SUPPORTED_ASSETS_ROLE");
    bytes32 public constant REMOVE_SUPPORTED_ASSETS_ROLE = keccak256("ORACLE:REMOVE_SUPPORTED_ASSETS_ROLE");

    bytes32 public constant SET_MERKLE_ROOT_ROLE = keccak256("VERIFIER:SET_MERKLE_ROOT_ROLE");
    bytes32 public constant CALL_ROLE = keccak256("VERIFIER:CALL_ROLE");
    bytes32 public constant ADD_ALLOWED_CALLS_ROLE = keccak256("VERIFIER:ADD_ALLOWED_CALLS_ROLE");
    bytes32 public constant REMOVE_ALLOWED_CALLS_ROLE = keccak256("VERIFIER:REMOVE_ALLOWED_CALLS_ROLE");

    bytes32 public constant SET_FLAGS_ROLE = keccak256("SHARES_MANAGER:SET_FLAGS_ROLE");

    bytes32 public constant ADD_SUVAULT_ROLE = keccak256("FACTORY_MODULE:ADD_SUVAULT_ROLE");
}
