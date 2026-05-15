// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

/// @title  IWhitelist
/// @notice Minimal read interface for the `RequestWhitelist` registry.
///         Downstream consumers that only need authorship attestation
///         import this and stay decoupled from the rest of the contract.
interface IWhitelist {
    /// @notice Four-way result of `isWhitelisted`, combining the
    ///         underlying attestation bit with the registry's pause
    ///         state. Only `Whitelisted` is safe to trust; every other
    ///         value should be treated as "do not authorise".
    ///
    /// - `NotWhitelisted`: registry is live and `a` has never been
    ///   attested, or its attestation has been revoked via `unwhitelist`.
    /// - `Whitelisted`: registry is live and `a` is currently attested.
    ///   The only state downstream integrators should accept.
    /// - `PausedNotWhitelisted`: registry is paused and `a` was not
    ///   attested at pause time. Do not authorise.
    /// - `PausedWhitelisted`: registry is paused but `a` was attested
    ///   before the pause. The circuit breaker is active — do not
    ///   authorise; integrators can surface this to users as "temporarily
    ///   unavailable" rather than "never listed".
    enum WhitelistStatus {
        NotWhitelisted,
        Whitelisted,
        PausedNotWhitelisted,
        PausedWhitelisted
    }

    /// @notice Returns the composite status of `a`.
    /// @dev    While the registry is paused the returned value is
    ///         `PausedWhitelisted` or `PausedNotWhitelisted` depending on
    ///         the underlying attestation bit — consumers who only need
    ///         "authorised or not" should gate strictly on
    ///         `status == WhitelistStatus.Whitelisted`. The richer enum
    ///         lets integrators distinguish "never listed" from
    ///         "temporarily gated by the circuit breaker" when surfacing
    ///         the state to users.
    /// @param  a The address whose attestation status is being queried.
    function isWhitelisted(address a) external view returns (WhitelistStatus);

    /// @notice Flips `targets` to the whitelisted state. Owner-only
    ///         direct path — no validator signatures required. Sig-based
    ///         submitters use `whitelistBySig` instead.
    /// @dev    `whenNotPaused`: while paused, `isWhitelisted` is masked to
    ///         the `Paused*` variants anyway, so flipping bits during
    ///         pause would be invisible to integrators and arguably
    ///         misleading. Mirrors the `whenNotPaused` gate on
    ///         `whitelistBySig`.
    ///
    ///         Available only in Phase 1 — once `owner()` is renounced,
    ///         `onlyOwner` reverts and this entry point is permanently
    ///         unreachable; quorum-signed `whitelistBySig` remains.
    /// @param  targets Addresses to whitelist. Already-whitelisted entries
    ///                 are silently skipped (so the call stays idempotent
    ///                 and emits one event per actual flip).
    function whitelist(address[] calldata targets) external;
}
