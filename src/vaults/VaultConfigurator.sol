// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "./Vault.sol";

contract VaultConfigurator {
    using EnumerableSet for EnumerableSet.AddressSet;

    struct InitParams {
        uint256 version;
        address proxyAdmin;
        address vaultAdmin;
        uint256 shareManagerVersion;
        bytes shareManagerParams;
        uint256 feeManagerVersion;
        bytes feeManagerParams;
        uint256 riskManagerVersion;
        bytes riskManagerParams;
        uint256 oracleVersion;
        bytes oracleParams;
        address defaultDepositHook;
        address defaultRedeemHook;
        uint256 queueLimit;
        Vault.RoleHolder[] roleHolders;
    }

    IFactory public immutable shareManagerFactory;
    IFactory public immutable feeManagerFactory;
    IFactory public immutable riskManagerFactory;
    IFactory public immutable oracleFactory;
    IFactory public immutable vaultFactory;

    EnumerableSet.AddressSet private _vaults;

    constructor(
        address shareManagerFactory_,
        address feeManagerFactory_,
        address riskManagerFactory_,
        address oracleFactory_,
        address vaultFactory_
    ) {
        shareManagerFactory = IFactory(shareManagerFactory_);
        feeManagerFactory = IFactory(feeManagerFactory_);
        riskManagerFactory = IFactory(riskManagerFactory_);
        oracleFactory = IFactory(oracleFactory_);
        vaultFactory = IFactory(vaultFactory_);
    }

    // View functions

    function entityAt(uint256 index) external view returns (address) {
        return _vaults.at(index);
    }

    function entities() external view returns (uint256) {
        return _vaults.length();
    }

    function isEntity(address vault) external view returns (bool) {
        return _vaults.contains(vault);
    }

    // Mutable functions

    function create(InitParams calldata params)
        external
        returns (address shareManager, address feeManager, address riskManager, address oracle, address vault)
    {
        shareManager =
            shareManagerFactory.create(params.shareManagerVersion, params.proxyAdmin, params.shareManagerParams);
        feeManager = feeManagerFactory.create(params.feeManagerVersion, params.proxyAdmin, params.feeManagerParams);
        riskManager = riskManagerFactory.create(params.riskManagerVersion, params.proxyAdmin, params.riskManagerParams);
        oracle = oracleFactory.create(params.oracleVersion, params.proxyAdmin, params.oracleParams);
        bytes memory initParams = abi.encode(
            params.vaultAdmin,
            shareManager,
            feeManager,
            riskManager,
            oracle,
            params.defaultDepositHook,
            params.defaultRedeemHook,
            params.queueLimit,
            params.roleHolders
        );
        vault = IFactory(vaultFactory).create(params.version, params.proxyAdmin, initParams);
        IShareManager(shareManager).setVault(vault);
        IRiskManager(riskManager).setVault(vault);
        IOracle(oracle).setVault(vault);
        _vaults.add(vault);
    }
}
