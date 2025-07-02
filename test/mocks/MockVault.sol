// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./MockERC20.sol";
import "./MockRiskManager.sol";

import "@openzeppelin/contracts/utils/Address.sol";
import "src/hooks/BasicRedeemHook.sol";
import "src/hooks/RedirectingDepositHook.sol";
import "src/interfaces/managers/IRiskManager.sol";

contract MockVault {
    address[] internal subvault;
    address internal redeemHook;
    address internal redirectingDepositHook;
    address internal _riskManager;

    constructor() {
        redeemHook = address(new BasicRedeemHook());
        redirectingDepositHook = address(new RedirectingDepositHook());
    }

    function addSubvault(address subvault_, MockERC20 asset_, uint256 amount_) external {
        subvault.push(subvault_);
        asset_.mint(subvault_, amount_);
    }

    function addRiskManager(uint256 limit) external {
        _riskManager = address(new MockRiskManager(limit));
    }

    function beforeRedeemHookCall(address asset, uint256 assets) external {
        Address.functionDelegateCall(redeemHook, abi.encodeCall(IRedeemHook.beforeRedeem, (asset, assets)));
    }

    function afterDepositHookCall(address asset, uint256 assets) external {
        Address.functionDelegateCall(redirectingDepositHook, abi.encodeCall(IDepositHook.afterDeposit, (asset, assets)));
    }

    function getLiquidAssetsCall(address asset) external view returns (uint256) {
        return IRedeemHook(redeemHook).getLiquidAssets(asset);
    }

    function riskManager() external view returns (IRiskManager) {
        return IRiskManager(_riskManager);
    }

    function subvaults() external view returns (uint256) {
        return subvault.length;
    }

    function subvaultAt(uint256 index) external view returns (address) {
        return subvault[index];
    }

    function pullAssets(address subvault, address asset, uint256 value) external {
        MockERC20(asset).take(subvault, value);
    }

    function pushAssets(address subvault, address asset, uint256 value) external {
        MockERC20(asset).transfer(subvault, value);
    }

    function test() external {}
}
