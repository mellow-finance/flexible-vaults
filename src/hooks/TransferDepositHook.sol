// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {IHook} from "../interfaces/hooks/IHook.sol";
import {ICallModule} from "../interfaces/modules/ICallModule.sol";
import {IVaultModule} from "../interfaces/modules/IVaultModule.sol";
import {IVerifier} from "../interfaces/permissions/IVerifier.sol";

contract TransferDepositHook is IHook {
    error InvalidAsset();
    error InvalidResponse();
    error InvalidVault();
    error OnlyDelegateCall();
    error UnsupportedSubvault();

    address public immutable asset;
    IVaultModule public immutable vault;
    address public immutable subvault;
    address public immutable to;

    address private immutable _this;

    constructor(address asset_, address vault_, address subvault_, address to_) {
        asset = asset_;
        vault = IVaultModule(vault_);
        subvault = subvault_;
        to = to_;
        _this = address(this);
    }

    function callHook(address asset_, uint256 assets_) public virtual {
        if (address(this) == _this) {
            revert OnlyDelegateCall();
        }
        if (address(this) != address(vault)) {
            revert InvalidVault();
        }
        if (asset_ != asset) {
            revert InvalidAsset();
        }
        if (!vault.hasSubvault(subvault)) {
            revert UnsupportedSubvault();
        }

        // expected no-op
        if (assets_ == 0) {
            return;
        }

        vault.hookPushAssets(subvault, asset, assets_);
        IVerifier.VerificationPayload memory onchainCompactPayload;
        bytes memory transferPayload = abi.encodeCall(IERC20.transfer, (to, assets_));
        bytes memory response = ICallModule(subvault).call(asset, 0, transferPayload, onchainCompactPayload);
        if (response.length != 0) {
            if (response.length != 0x20 || !abi.decode(response, (bool))) {
                revert InvalidResponse();
            }
        }
    }
}
