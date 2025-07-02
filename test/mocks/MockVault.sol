// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./MockERC20.sol";

import "@openzeppelin/contracts/utils/Address.sol";
import "src/hooks/BasicRedeemHook.sol";

contract MockVault {
    address[] internal subvault;
    address redeemHook;

    function addSubvault(address subvault_, MockERC20 asset_, uint256 amount_) external {
        subvault.push(subvault_);
        asset_.mint(subvault_, amount_);
        redeemHook = address(new BasicRedeemHook());
    }

    function beforeRedeemHookCall(address asset, uint256 assets) external {
        Address.functionDelegateCall(redeemHook, abi.encodeCall(IRedeemHook.beforeRedeem, (asset, assets)));
    }

    function getLiquidAssetsCall(address asset) external view returns (uint256) {
        return IRedeemHook(redeemHook).getLiquidAssets(asset);
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
