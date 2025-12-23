// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

library LidoV3Permissions {
    /**
     * @notice Permission for funding the StakingVault.
     */
    /// @dev 0x933b7d5c112a4d05b489cea0b2ced98acb27d3d0fc9827c92cdacb2d6c5559c2
    bytes32 public constant FUND_ROLE = keccak256("vaults.Permissions.Fund");

    /**
     * @notice Permission for withdrawing funds from the StakingVault.
     */
    /// @dev 0x355caf1c2580ed8185acb5ea3573b71f85186b41bdf69e3eb8f1fcd122a562df
    bytes32 public constant WITHDRAW_ROLE = keccak256("vaults.Permissions.Withdraw");

    /**
     * @notice Permission for minting stETH shares backed by the StakingVault.
     */
    /// @dev 0xe996ac9b332538bb1fa3cd6743aa47011623cdb94bd964a494ee9d371e4a27d3
    bytes32 public constant MINT_ROLE = keccak256("vaults.Permissions.Mint");

    /**
     * @notice Permission for burning stETH shares backed by the StakingVault.
     */
    /// @dev 0x689f0a569be0c9b6cd2c11c81cb0add722272abdae6b649fdb1e05f1d9bb8a2f
    bytes32 public constant BURN_ROLE = keccak256("vaults.Permissions.Burn");

    /**
     * @notice Permission for rebalancing the StakingVault.
     */
    /// @dev 0x3f82ecf462ddac43fc17ba11472c35f18b7760b4f5a5fc50b9625f9b5a22cf62
    bytes32 public constant REBALANCE_ROLE = keccak256("vaults.Permissions.Rebalance");

    /**
     * @notice Permission for pausing beacon chain deposits on the StakingVault.
     */
    /// @dev 0xa90c7030a27f389f9fc8ed21a0556f40c88130cc14a80db936bed68261819b2c
    bytes32 public constant PAUSE_BEACON_CHAIN_DEPOSITS_ROLE = keccak256("vaults.Permissions.PauseDeposits");

    /**
     * @notice Permission for resuming beacon chain deposits on the StakingVault.
     */
    /// @dev 0x59d005e32db662b94335d6bedfeb453fd2202b9f0cc7a6ed498d9098171744b0
    bytes32 public constant RESUME_BEACON_CHAIN_DEPOSITS_ROLE = keccak256("vaults.Permissions.ResumeDeposits");

    /**
     * @notice Permission for requesting validator exit from the StakingVault.
     */
    /// @dev 0x32d0d6546e21c13ff633616141dc9daad87d248d1d37c56bf493d06d627ecb7b
    bytes32 public constant REQUEST_VALIDATOR_EXIT_ROLE = keccak256("vaults.Permissions.RequestValidatorExit");

    /**
     * @notice Permission for triggering validator withdrawal from the StakingVault using EIP-7002 triggerable exit.
     */
    /// @dev 0xea19d3b23bd90fdd52445ad672f2b6fb1fef7230d49c6a827c1cd288d02994d5
    bytes32 public constant TRIGGER_VALIDATOR_WITHDRAWAL_ROLE =
        keccak256("vaults.Permissions.TriggerValidatorWithdrawal");

    /**
     * @notice Permission for voluntary disconnecting the StakingVault.
     */
    /// @dev 0x9586321ac05f110e4b4a0a42aba899709345af0ca78910e8832ddfd71fed2bf4
    bytes32 public constant VOLUNTARY_DISCONNECT_ROLE = keccak256("vaults.Permissions.VoluntaryDisconnect");

    /**
     * @dev Permission for vault configuration operations on the OperatorGrid (tier changes, tier sync, share limit updates).
     */
    /// @dev 0x25482e7dc9e29f6da5bd70b6d19d17bbf44021da51ba0664a9f430c94a09c674
    bytes32 public constant VAULT_CONFIGURATION_ROLE = keccak256("vaults.Permissions.VaultConfiguration");
}
