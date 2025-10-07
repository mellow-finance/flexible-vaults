// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

interface IMulticall {
    struct Call {
        address target;
        bytes callData;
    }

    function aggregate(Call[] memory calls) external returns (uint256 blockNumber, bytes[] memory returnData);
}

interface IMultiVault is IERC4626 {
    function defaultCollateral() external view returns (address);
}

contract Migrator is Ownable {
    struct Params {
        ProxyAdmin proxyAdmin;
        address proxyAdminOwner;
        address vaultAdmin;
        bytes feeManagerParams;
        bytes riskManagerParams;
        bytes oracleParams;
        uint256 queueLimit;
        Vault.RoleHolder[] roleHolders;
    }

    address public constant MULTICALL = 0xeefBa1e63905eF1D7ACbA5a8513c70307C1cE441;
    address public constant REDIRECTING_DEPOSIT_HOOK = 0x00000004d3B17e5391eb571dDb8fDF95646ca827;
    address public constant BASIC_REDEEM_HOOK = 0x0000000637f1b1ccDA4Af2dB6CDDf5e5Ec45fd93;
    IFactory public constant FEE_MANAGER_FACTORY = 0xF7223356819Ea48f25880b6c2ab3e907CC336D45;
    IFactory public constant RISK_MANAGER_FACTORY = 0xa51E4FA916b939Fa451520D2B7600c740d86E5A0;
    IFactory public constant VAULT_FACTORY = 0x4E38F679e46B3216f0bd4B314E9C429AFfB1dEE3;
    IFactory public constant ORACLE_FACTORY = 0x0CdFf250C7a071fdc72340D820C5C8e29507Aaad;
    address public constant TOKENIZED_SHARE_MANAGER = 0x0000000E8eb7173fA1a3ba60eCA325bcB6aaf378;

    constructor(address owner_) Ownable(owner_) {}

    function migrate(address multiVault, Params memory params) external onlyOwner returns (address vault) {
        require(params.proxyAdmin.owner() == address(this), "Migrator: invalid owner");

        {
            address feeManager = FEE_MANAGER_FACTORY.create(0, params.proxyAdminOwner, params.feeManagerParams);
            address riskManager = RISK_MANAGER_FACTORY.create(0, params.proxyAdminOwner, params.riskManagerParams);
            address oracle = ORACLE_FACTORY.create(0, params.proxyAdminOwner, params.oracleParams);
            bytes memory initParams = abi.encode(
                params.vaultAdmin,
                vault,
                feeManager,
                riskManager,
                oracle,
                REDIRECTING_DEPOSIT_HOOK,
                BASIC_REDEEM_HOOK,
                params.queueLimit,
                params.roleHolders
            );
            vault = VAULT_FACTORY.create(0, params.proxyAdminOwner, initParams);
            IRiskManager(riskManager).setVault(vault);
            IOracle(oracle).setVault(vault);
        }

        address asset = IMultiVault(multiVault).asset();
        address defaultCollateral = IMultiVault(multiVault).defaultCollateral();

        uint256 assetBalance = IERC20(asset).balanceOf(multiVault);
        uint256 defaultCollateralBalance = IERC20(defaultCollateral).balanceOf(multiVault);

        require(
            IMultiVault(multiVault).totalAssets() == assetBalance + defaultCollateralBalance,
            "Migrator: invalid state of MultiVault"
        );

        IMulticall.Call[] memory calls = new IMulticall.Call[](2);
        calls[0] =
            IMulticall.Call({target: asset, callData: abi.encodeCall(IERC20.transfer, (multiVault, assetBalance))});
        calls[1] = IMulticall.Call({
            target: defaultCollateral,
            callData: abi.encodeCall(IERC20.transfer, (multiVault, defaultCollateralBalance))
        });
        params.proxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(multiVault), MULTICALL, abi.encodeCall(IMulticall.aggregate, calls)
        );

        params.proxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(multiVault), TOKENIZED_SHARE_MANAGER, new bytes(0)
        );
        IShareManager(multiVault).setVault(vault);
    }
}
