// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./MockERC20.sol";
import "./MockRiskManager.sol";

import "@openzeppelin/contracts/utils/Address.sol";
import "src/hooks/BasicRedeemHook.sol";
import "src/hooks/LidoDepositHook.sol";
import "src/hooks/RedirectingDepositHook.sol";
import "src/interfaces/managers/IRiskManager.sol";

contract MockVault {
    address[] internal subvault;
    address public redeemHook;
    address public redirectingDepositHook;
    address public lidoDepositHook;
    address internal _riskManager;

    address public immutable wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address public immutable WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    constructor() {
        redeemHook = address(new BasicRedeemHook());
        redirectingDepositHook = address(new RedirectingDepositHook());
    }

    receive() external payable {}

    function addLidoDepositHook(address nextHook) external {
        lidoDepositHook = address(new LidoDepositHook(wstETH, WETH, nextHook));
    }

    function addSubvault(address subvault_, MockERC20 asset_, uint256 amount_) external {
        subvault.push(subvault_);
        if (amount_ > 0) {
            asset_.mint(subvault_, amount_);
        }
    }

    function addRiskManager(uint256 limit) external {
        _riskManager = address(new MockRiskManager(limit));
    }

    function beforeRedeemHookCall(address asset, uint256 assets) external {
        Address.functionDelegateCall(redeemHook, abi.encodeCall(IHook.callHook, (asset, assets)));
    }

    function afterDepositHookCall(address asset, uint256 assets) external {
        Address.functionDelegateCall(redirectingDepositHook, abi.encodeCall(IHook.callHook, (asset, assets)));
    }

    function lidoDepositHookCall(address asset, uint256 assets) external {
        Address.functionDelegateCall(lidoDepositHook, abi.encodeCall(IHook.callHook, (asset, assets)));
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

    function hookPullAssets(address subvault_, address asset, uint256 value) external {
        MockERC20(asset).take(subvault_, value);
    }

    function hookPushAssets(address subvault_, address asset, uint256 value) external {
        MockERC20(asset).transfer(subvault_, value);
    }

    function pullAssets(address subvault_, address asset, uint256 value) external {
        MockERC20(asset).take(subvault_, value);
    }

    function pushAssets(address subvault_, address asset, uint256 value) external {
        MockERC20(asset).transfer(subvault_, value);
    }

    function test() external {}
}
