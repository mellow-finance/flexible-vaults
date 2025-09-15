// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../src/vaults/Vault.sol";
import "../../src/vaults/VaultConfigurator.sol";

library AcceptanceLibrary {
    struct Deployment {
        VaultConfigurator configurator;
        Vault vault;
    }

    function check(Deployment memory $) internal view {
        require(address($.configurator) != address(0), "VaultConfigurator: address zero");
        require(address($.vault) != address(0), "Vault: address zero");
        require($.configurator.vaultFactory().isEntity(address($.vault)), "Vault is not VaultFactory`s instance");
    }
}
