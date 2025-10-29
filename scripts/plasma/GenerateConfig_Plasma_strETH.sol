// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {GenerateConfig} from "../common/GenerateConfig.sol";
import {IVerifier} from "../../src/interfaces/modules/IVerifierModule.sol";
import {SubvaultCalls} from "../common/interfaces/Imports.sol";

import {OFTLibrary} from "../common/protocols/OFTLibrary.sol";
import {Constants} from "./Constants.sol";
import {PlasmaStrETHLibrary} from "./PlasmaStrETHLibrary.sol";

/// @title GenerateConfig_Plasma_strETH
/// @notice Verification script for Plasma strETH vault subvault calls
/// @dev Inherits from VerifySubvaultCallsBase and provides Plasma strETH-specific configuration
contract GenerateConfig_Plasma_strETH is GenerateConfig {
    // Plasma strETH vault configuration
    address constant SUBVAULT = Constants.STRETH_PLASMA_SUBVAULT_0;
    address constant CURATOR = 0x5Dbf9287787A5825beCb0321A276C9c92d570a75;
    address constant ACTIVE_VAULT_ADMIN = 0xeb1CaFBcC8923eCbc243ff251C385C201A6c734a;

    function getSubvaultAddress() internal pure override returns (address) {
        return SUBVAULT;
    }

    function getCuratorAddress() internal pure override returns (address) {
        return CURATOR;
    }

    function getActiveVaultAdmin() internal pure override returns (address) {
        return ACTIVE_VAULT_ADMIN;
    }

    function getPlasmaStrETHInfo() internal pure returns (PlasmaStrETHLibrary.Info memory) {
        return PlasmaStrETHLibrary.Info({
            curator: CURATOR,
            ethereumSubvault: Constants.STRETH_ETHEREUM_SUBVAULT_0,
            asset: Constants.WSTETH,
            ccipRouter: Constants.CCIP_PLASMA_ROUTER,
            ccipEthereumSelector: Constants.CCIP_ETHEREUM_CHAIN_SELECTOR,
            aavePool: Constants.AAVE_POOL,
            weETH: Constants.WEETH,
            wethOFTAdapter: Constants.WETH_OFT_ADAPTER,
            lzEthereumEid: Constants.LZ_ETHEREUM_EID
        });
    }

    function getSubvaultCalls(address subvaultAddress) internal view override returns (SubvaultCalls memory calls) {
        PlasmaStrETHLibrary.Info memory info = getPlasmaStrETHInfo();
        (, IVerifier.VerificationPayload[] memory leaves) = PlasmaStrETHLibrary.getPlasmaStrETHProofs(info);
        calls = PlasmaStrETHLibrary.getPlasmaStrETHCalls(info, leaves);
    }

    function getDescriptions(address subvaultAddress) internal view override returns (string[] memory descriptions) {
        PlasmaStrETHLibrary.Info memory info = getPlasmaStrETHInfo();

        descriptions = PlasmaStrETHLibrary.getPlasmaStrETHDescriptions(info);
    }

    function getJsonName() internal pure override returns (string memory) {
        return "plasma:strETH:subvault0";
    }
}
