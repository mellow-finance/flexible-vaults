// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../factories/IFactory.sol";
import "./IACLModule.sol";
import "./ISharesModule.sol";
import "./ISubvaultModule.sol";

interface IRootVaultModule is IACLModule {
    struct RootVaultModuleStorage {
        EnumerableSet.AddressSet subvaults;
        mapping(address subvault => int256) balances;
        mapping(address subvault => int256) limits;
    }

    struct CreateSubvaultParams {
        uint256 version;
        address owner;
        address subvaultAdmin;
        address verifier;
        int256 limit;
    }

    // View functions

    function subvaultFactory() external view returns (address);

    function subvaults() external view returns (uint256);

    function subvaultAt(uint256 index) external view returns (address);

    function hasSubvault(address subvault) external view returns (bool);

    function getSubvaultState(address subvault) external view returns (int256 limit, int256 balance);

    function convertToShares(address asset, uint256 assets) external view returns (uint256 shares);

    // Mutable functions

    function createSubvault(CreateSubvaultParams calldata initParams) external returns (address subvault);

    function disconnectSubvault(address subvault) external;

    function reconnectSubvault(address subvault, int256 balance, int256 limit) external;

    function applyCorrection(address subvault, int256 correction) external;

    function pushAssets(address subvault, address asset, uint256 value) external;

    function pullAssets(address subvault, address asset, uint256 value) external;

    function setSubvaultLimit(address subvault, int256 limit) external;
}
