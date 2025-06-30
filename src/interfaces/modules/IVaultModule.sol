// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../factories/IFactory.sol";

import "../managers/IRiskManager.sol";
import "./IACLModule.sol";
import "./IShareModule.sol";
import "./ISubvaultModule.sol";
import "./IVerifierModule.sol";

interface IVaultModule is IACLModule {
    error AlreadyConnected(address subvault);
    error NotConnected(address subvault);
    error NotEntity(address subvault);
    error InvalidSubvault(address subvault);

    struct VaultModuleStorage {
        address riskManager;
        EnumerableSet.AddressSet subvaults;
    }

    // View functions

    function subvaultFactory() external view returns (address);

    function subvaults() external view returns (uint256);

    function subvaultAt(uint256 index) external view returns (address);

    function hasSubvault(address subvault) external view returns (bool);

    function riskManager() external view returns (IRiskManager);

    // Mutable functions

    function createSubvault(uint256 version, address owner, address verifier) external returns (address subvault);

    function disconnectSubvault(address subvault) external;

    function reconnectSubvault(address subvault) external;

    function pushAssets(address subvault, address asset, uint256 value) external;

    function pullAssets(address subvault, address asset, uint256 value) external;
}
