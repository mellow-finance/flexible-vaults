// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface ISymbioticVaultFactory {
    function isEntity(address account) external view returns (bool);
}
