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
        mapping(address subvault => uint256) limits;
    }

    // View functions

    function subvaultFactory() external view returns (address);

    function subvaults() external view returns (uint256);

    function subvaultAt(uint256 index) external view returns (address);

    function isSubvault(address subvault) external view returns (bool);

    // Mutable functions

    function createSubvault(uint256 version, address owner, address subvaultAdmin, address verifier, bytes32 salt)
        external
        returns (address subvault);

    function disconnectSubvault(address subvault) external;

    function reconnectSubvault(address subvault) external;
}
