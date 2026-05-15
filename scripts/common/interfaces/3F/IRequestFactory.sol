// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface IRequestFactory {
    /// @notice Checks if an address is a Request contract deployed by this factory.
    /// @param request The address to check
    /// @return True if the address is a Request deployed by this factory
    function isRequest(address request) external view returns (bool);

    /// @notice Creates a new Request with its associated PT and YT token proxies.
    /// @dev Deploys three ERC1967 beacon proxies and initializes them atomically:
    ///      1. Deploys Request proxy pointing to REQUEST_BEACON
    ///      2. Deploys PT Token proxy pointing to PT_TOKEN_BEACON
    ///      3. Deploys YT Token proxy pointing to YT_TOKEN_BEACON
    ///      4. Initializes Request with owner, asset, token addresses, metadata, and repayment deadline
    ///      5. Initializes both tokens with the Request as their controller
    ///
    ///      The Request becomes the controller for both tokens, managing minting and burning.
    ///      Emits a {RequestCreated} event.
    /// @param owner The address that will own the Request (admin privileges)
    /// @param puller The address that will have the puller role
    /// @param consumer The address that will have the consumer role (can call consume and authorizeMinting)
    /// @param asset The underlying ERC20 asset address (e.g., USDC)
    /// @param name The base name for PT/YT tokens (prefixed with "PT-" / "YT-")
    /// @param symbol The base symbol for PT/YT tokens (prefixed with "PT-" / "YT-")
    /// @param repaymentDeadline The timestamp after which withdrawals are automatically enabled, regardless of repaid status
    /// @param mintToRepaidDelay Minimum delay (seconds) between the last mint/consume and setRepaid(uint256)
    /// @return request The address of the newly deployed Request proxy
    /// @return ptToken The address of the newly deployed PT Token proxy
    /// @return ytToken The address of the newly deployed YT Token proxy
    function createRequest(
        address owner,
        address puller,
        address consumer,
        address asset,
        string memory name,
        string memory symbol,
        uint64 repaymentDeadline,
        uint40 mintToRepaidDelay
    ) external returns (address request, address ptToken, address ytToken);
}
