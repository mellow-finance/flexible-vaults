// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

library Permissions {
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    bytes32 public constant SET_VAULT_LIMIT_ROLE = keccak256("managers.RiskManager.SET_VAULT_LIMIT_ROLE");
    bytes32 public constant SET_SUBVAULT_LIMIT_ROLE = keccak256("managers.RiskManager.SET_SUBVAULT_LIMIT_ROLE");
    bytes32 public constant ALLOW_SUBVAULT_ASSETS_ROLE = keccak256("managers.RiskManager.ALLOW_SUBVAULT_ASSETS_ROLE");
    bytes32 public constant DISALLOW_SUBVAULT_ASSETS_ROLE =
        keccak256("managers.RiskManager.DISALLOW_SUBVAULT_ASSETS_ROLE");
    bytes32 public constant MODIFY_PENDING_ASSETS_ROLE = keccak256("managers.RiskManager.MODIFY_PENDING_ASSETS_ROLE");
    bytes32 public constant MODIFY_VAULT_BALANCE_ROLE = keccak256("managers.RiskManager.MODIFY_VAULT_BALANCE_ROLE");
    bytes32 public constant MODIFY_SUBVAULT_BALANCE_ROLE =
        keccak256("managers.RiskManager.MODIFY_SUBVAULT_BALANCE_ROLE");

    bytes32 public constant SET_FLAGS_ROLE = keccak256("managers.ShareManager.SET_FLAGS_ROLE");
    bytes32 public constant SET_ACCOUNT_INFO_ROLE = keccak256("managers.ShareManager.SET_ACCOUNT_INFO_ROLE");
    bytes32 public constant SET_WHITELIST_MERKLE_ROOT_ROLE =
        keccak256("managers.ShareManager.SET_WHITELIST_MERKLE_ROOT_ROLE");

    bytes32 public constant SET_HOOK_ROLE = keccak256("modules.ShareModule.SET_HOOK_ROLE");
    bytes32 public constant CREATE_QUEUE_ROLE = keccak256("modules.ShareModule.CREATE_QUEUE_ROLE");
    bytes32 public constant SET_QUEUE_STATUS_ROLE = keccak256("modules.ShareModule.SET_QUEUE_STATUS_ROLE");
    bytes32 public constant SET_QUEUE_LIMIT_ROLE = keccak256("modules.ShareModule.SET_QUEUE_LIMIT_ROLE");
    bytes32 public constant REMOVE_QUEUE_ROLE = keccak256("modules.ShareModule.REMOVE_QUEUE_ROLE");

    bytes32 public constant CREATE_SUBVAULT_ROLE = keccak256("modules.VaultModule.CREATE_SUBVAULT_ROLE");
    bytes32 public constant DISCONNECT_SUBVAULT_ROLE = keccak256("modules.VaultModule.DISCONNECT_SUBVAULT_ROLE");
    bytes32 public constant RECONNECT_SUBVAULT_ROLE = keccak256("modules.VaultModule.RECONNECT_SUBVAULT_ROLE");
    bytes32 public constant PULL_LIQUIDITY_ROLE = keccak256("modules.VaultModule.PULL_LIQUIDITY_ROLE");
    bytes32 public constant PUSH_LIQUIDITY_ROLE = keccak256("modules.VaultModule.PUSH_LIQUIDITY_ROLE");

    bytes32 public constant SUBMIT_REPORTS_ROLE = keccak256("oracles.Oracle.SUBMIT_REPORTS_ROLE");
    bytes32 public constant ACCEPT_REPORT_ROLE = keccak256("oracles.Oracle.ACCEPT_REPORT_ROLE");
    bytes32 public constant SET_SECURITY_PARAMS_ROLE = keccak256("oracles.Oracle.SET_SECURITY_PARAMS_ROLE");
    bytes32 public constant ADD_SUPPORTED_ASSETS_ROLE = keccak256("oracles.Oracle.ADD_SUPPORTED_ASSETS_ROLE");
    bytes32 public constant REMOVE_SUPPORTED_ASSETS_ROLE = keccak256("oracles.Oracle.REMOVE_SUPPORTED_ASSETS_ROLE");

    bytes32 public constant EIGEN_LAYER_VERIFIER_ASSET_ROLE =
        keccak256("permissions.protocols.EigenLayerVerifier.ASSET_ROLE");
    bytes32 public constant EIGEN_LAYER_VERIFIER_CALLER_ROLE =
        keccak256("permissions.protocols.EigenLayerVerifier.CALLER_ROLE");
    bytes32 public constant EIGEN_LAYER_VERIFIER_MELLOW_VAULT_ROLE =
        keccak256("permissions.protocols.EigenLayerVerifier.MELLOW_VAULT_ROLE");
    bytes32 public constant EIGEN_LAYER_VERIFIER_OPERATOR_ROLE =
        keccak256("permissions.protocols.EigenLayerVerifier.OPERATOR_ROLE");
    bytes32 public constant EIGEN_LAYER_VERIFIER_RECEIVER_ROLE =
        keccak256("permissions.protocols.EigenLayerVerifier.RECEIVER_ROLE");
    bytes32 public constant EIGEN_LAYER_VERIFIER_STRATEGY_ROLE =
        keccak256("permissions.protocols.EigenLayerVerifier.STRATEGY_ROLE");

    bytes32 public constant ERC20_VERIFIER_ASSET_ROLE = keccak256("permissions.protocols.ERC20Verifier.ASSET_ROLE");
    bytes32 public constant ERC20_VERIFIER_CALLER_ROLE = keccak256("permissions.protocols.ERC20Verifier.CALLER_ROLE");
    bytes32 public constant ERC20_VERIFIER_RECIPIENT_ROLE =
        keccak256("permissions.protocols.ERC20Verifier.RECIPIENT_ROLE");

    bytes32 public constant SYMBIOTIC_VERIFIER_CALLER_ROLE =
        keccak256("permissions.protocols.SymbioticVerifier.CALLER_ROLE");
    bytes32 public constant SYMBIOTIC_VERIFIER_MELLOW_VAULT_ROLE =
        keccak256("permissions.protocols.SymbioticVerifier.MELLOW_VAULT_ROLE");
    bytes32 public constant SYMBIOTIC_VERIFIER_SYMBIOTIC_FARM_ROLE =
        keccak256("permissions.protocols.SymbioticVerifier.SYMBIOTIC_FARM_ROLE");
    bytes32 public constant SYMBIOTIC_VERIFIER_SYMBIOTIC_VAULT_ROLE =
        keccak256("permissions.protocols.SymbioticVerifier.SYMBIOTIC_VAULT_ROLE");

    bytes32 public constant SET_MERKLE_ROOT_ROLE = keccak256("permissions.Verifier.SET_MERKLE_ROOT_ROLE");
    bytes32 public constant CALLER_ROLE = keccak256("permissions.Verifier.CALLER_ROLE");
    bytes32 public constant ALLOW_CALL_ROLE = keccak256("permissions.Verifier.ALLOW_CALL_ROLE");
    bytes32 public constant DISALLOW_CALL_ROLE = keccak256("permissions.Verifier.DISALLOW_CALL_ROLE");

    bytes32 public constant SWAP_MODULE_TOKEN_IN_ROLE = keccak256("utils.SwapModule.TOKEN_IN_ROLE");
    bytes32 public constant SWAP_MODULE_TOKEN_OUT_ROLE = keccak256("utils.SwapModule.TOKEN_OUT_ROLE");
    bytes32 public constant SWAP_MODULE_ROUTER_ROLE = keccak256("utils.SwapModule.ROUTER_ROLE");
    bytes32 public constant SWAP_MODULE_CALLER_ROLE = keccak256("utils.SwapModule.CALLER_ROLE");
    bytes32 public constant SWAP_MODULE_SET_SLIPPAGE_ROLE = keccak256("utils.SwapModule.SET_SLIPPAGE_ROLE");

    bytes32 public constant TIMELOCK_CONTROLLER_PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant TIMELOCK_CONTROLLER_EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant TIMELOCK_CONTROLLER_CANCELLER_ROLE = keccak256("CANCELLER_ROLE");
}
