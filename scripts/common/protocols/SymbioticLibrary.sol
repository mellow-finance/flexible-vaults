// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/utils/Strings.sol";

import {ABILibrary} from "../ABILibrary.sol";
import {JsonLibrary} from "../JsonLibrary.sol";
import "../ParameterLibrary.sol";
import "../ProofLibrary.sol";
import "../interfaces/Imports.sol";

import {ISymbioticVault as IVault} from "../../../src/strategies/SymbioticStrategy.sol";

library SymbioticLibrary {
    using ParameterLibrary for ParameterLibrary.Parameter[];

    struct Info {
        address subvault;
        string subvaultName;
        address curator;
        address symbioticVault;
    }

    function getSymbioticProofs(BitmaskVerifier bitmaskVerifier, Info memory $)
        internal
        view
        returns (IVerifier.VerificationPayload[] memory leaves)
    {
        uint256 length = 4;
        leaves = new IVerifier.VerificationPayload[](length);
        uint256 index = 0;
        leaves[index++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            IVault($.symbioticVault).collateral(),
            0,
            abi.encodeCall(IERC20.approve, ($.symbioticVault, 0)),
            ProofLibrary.makeBitmask(
                true, true, true, true, abi.encodeCall(IERC20.approve, (address(type(uint160).max), 0))
            )
        );
        leaves[index++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            asset,
            0,
            abi.encodeCall(IVault.deposit, ($.subvault, 0)),
            ProofLibrary.makeBitmask(
                true, true, true, true, abi.encodeCall(IVault.deposit, (address(type(uint160).max), 0))
            )
        );
        leaves[index++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            asset,
            0,
            abi.encodeCall(IVault.withdraw, ($.subvault, 0)),
            ProofLibrary.makeBitmask(
                true, true, true, true, abi.encodeCall(IVault.withdraw, (address(type(uint160).max), 0))
            )
        );
        leaves[index++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            asset,
            0,
            abi.encodeCall(IVault.claim, ($.subvault, 0)),
            ProofLibrary.makeBitmask(
                true, true, true, true, abi.encodeCall(IVault.claim, (address(type(uint160).max), 0))
            )
        );

        assembly {
            mstore(leaves, index)
        }
    }

    function getSymbioticDescriptions(Info memory $) internal view returns (string[] memory descriptions) {
        uint256 length = ($.assets.length * 5);
        descriptions = new string[](length);
        uint256 index = 0;

        ParameterLibrary.Parameter[] memory innerParameters;
        address collateral = IVault($.symbioticVault).collateral();

        string memory collateralSymbol = IERC20Metadata(collateral).symbol();

        innerParameters = ParameterLibrary.buildERC20(Strings.toHexString($.symbioticVault));
        descriptions[index++] = JsonLibrary.toJson(
            string(
                abi.encodePacked(
                    "IERC20(",
                    IERC20Metadata(collateral).symbol(),
                    ").approve(SymbioticVault(",
                    Strings.toHexString($.symbioticVault),
                    "), anyInt)"
                )
            ),
            ABILibrary.getABI(IERC20.approve.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString(collateral), "0"),
            innerParameters
        );

        innerParameters = ParameterLibrary.build("onBehalfOf", Strings.toHexString($.subvault)).add("amount", "any");
        descriptions[index++] = JsonLibrary.toJson(
            string(
                abi.encodePacked(
                    "ISymbioticVault(",
                    Strings.toHexString($.symbioticVault),
                    ").deposit(",
                    Strings.toHexString($.subvault),
                    ", anyInt)"
                )
            ),
            ABILibrary.getABI(IVault.deposit.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.symbioticVault), "0"),
            innerParameters
        );

        innerParameters = ParameterLibrary.build("claimer", Strings.toHexString($.subvault)).add("amount", "any");
        descriptions[index++] = JsonLibrary.toJson(
            string(
                abi.encodePacked(
                    "ISymbioticVault(",
                    Strings.toHexString($.symbioticVault),
                    ").withdraw(",
                    Strings.toHexString($.subvault),
                    ", anyInt)"
                )
            ),
            ABILibrary.getABI(IVault.withdraw.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.symbioticVault), "0"),
            innerParameters
        );

        innerParameters = ParameterLibrary.build("recipient", Strings.toHexString($.subvault)).add("epoch", "any");
        descriptions[index++] = JsonLibrary.toJson(
            string(
                abi.encodePacked(
                    "ISymbioticVault(",
                    Strings.toHexString($.symbioticVault),
                    ").claim(",
                    Strings.toHexString($.subvault),
                    ", anyInt)"
                )
            ),
            ABILibrary.getABI(IVault.claim.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.symbioticVault), "0"),
            innerParameters
        );
    }

    function getSymbioticCalls(Info memory $) internal view returns (Call[][] memory calls) {
        // uint256 index = 0;
        // calls = new Call[][]($.assets.length * 5);

        // for (uint256 j = 0; j < $.assets.length; j++) {
        //     address asset = $.assets[j];
        //     address underlyingAsset = IERC4626(asset).asset();
        //     {
        //         Call[] memory tmp = new Call[](16);
        //         uint256 i = 0;
        //         tmp[i++] = Call($.curator, underlyingAsset, 0, abi.encodeCall(IERC20.approve, (asset, 0)), true);
        //         tmp[i++] = Call($.curator, underlyingAsset, 0, abi.encodeCall(IERC20.approve, (asset, 1 ether)), true);
        //         tmp[i++] =
        //             Call(address(0xdead), underlyingAsset, 0, abi.encodeCall(IERC20.approve, (asset, 1 ether)), false);
        //         tmp[i++] = Call($.curator, address(0xdead), 0, abi.encodeCall(IERC20.approve, (asset, 1 ether)), false);
        //         tmp[i++] = Call(
        //             $.curator, underlyingAsset, 0, abi.encodeCall(IERC20.approve, (address(0xdead), 1 ether)), false
        //         );
        //         tmp[i++] =
        //             Call($.curator, underlyingAsset, 1 wei, abi.encodeCall(IERC20.approve, (asset, 1 ether)), false);
        //         tmp[i++] =
        //             Call($.curator, underlyingAsset, 0, abi.encode(IERC20.approve.selector, asset, 1 ether), false);
        //         assembly {
        //             mstore(tmp, i)
        //         }
        //         calls[index++] = tmp;
        //     }

        //     // ERC4626 deposit
        //     {
        //         Call[] memory tmp = new Call[](16);
        //         uint256 i = 0;
        //         tmp[i++] = Call($.curator, asset, 0, abi.encodeCall(IERC4626.deposit, (0, $.subvault)), true);
        //         tmp[i++] = Call($.curator, asset, 0, abi.encodeCall(IERC4626.deposit, (1 ether, $.subvault)), true);
        //         tmp[i++] =
        //             Call(address(0xdead), asset, 0, abi.encodeCall(IERC4626.deposit, (1 ether, $.subvault)), false);
        //         tmp[i++] =
        //             Call($.curator, address(0xdead), 0, abi.encodeCall(IERC4626.deposit, (1 ether, $.subvault)), false);
        //         tmp[i++] = Call($.curator, asset, 1 wei, abi.encodeCall(IERC4626.deposit, (1 ether, $.subvault)), false);
        //         tmp[i++] =
        //             Call($.curator, asset, 0, abi.encodeCall(IERC4626.deposit, (1 ether, address(0xdead))), false);
        //         tmp[i++] = Call($.curator, asset, 0, abi.encode(IERC4626.deposit.selector, 1 ether, $.subvault), false);
        //         assembly {
        //             mstore(tmp, i)
        //         }
        //         calls[index++] = tmp;
        //     }

        //     // ERC4626 mint
        //     {
        //         Call[] memory tmp = new Call[](16);
        //         uint256 i = 0;
        //         tmp[i++] = Call($.curator, asset, 0, abi.encodeCall(IERC4626.mint, (0, $.subvault)), true);
        //         tmp[i++] = Call($.curator, asset, 0, abi.encodeCall(IERC4626.mint, (1 ether, $.subvault)), true);
        //         tmp[i++] = Call(address(0xdead), asset, 0, abi.encodeCall(IERC4626.mint, (1 ether, $.subvault)), false);
        //         tmp[i++] =
        //             Call($.curator, address(0xdead), 0, abi.encodeCall(IERC4626.mint, (1 ether, $.subvault)), false);
        //         tmp[i++] = Call($.curator, asset, 1 wei, abi.encodeCall(IERC4626.mint, (1 ether, $.subvault)), false);
        //         tmp[i++] = Call($.curator, asset, 0, abi.encodeCall(IERC4626.mint, (1 ether, address(0xdead))), false);
        //         tmp[i++] = Call($.curator, asset, 0, abi.encode(IERC4626.mint.selector, 1 ether, $.subvault), false);
        //         assembly {
        //             mstore(tmp, i)
        //         }
        //         calls[index++] = tmp;
        //     }

        //     // ERC4626 redeem
        //     {
        //         Call[] memory tmp = new Call[](16);
        //         uint256 i = 0;
        //         tmp[i++] = Call($.curator, asset, 0, abi.encodeCall(IERC4626.redeem, (0, $.subvault, $.subvault)), true);
        //         tmp[i++] =
        //             Call($.curator, asset, 0, abi.encodeCall(IERC4626.redeem, (1 ether, $.subvault, $.subvault)), true);
        //         tmp[i++] = Call(
        //             address(0xdead), asset, 0, abi.encodeCall(IERC4626.redeem, (1 ether, $.subvault, $.subvault)), false
        //         );
        //         tmp[i++] = Call(
        //             $.curator,
        //             address(0xdead),
        //             0,
        //             abi.encodeCall(IERC4626.redeem, (1 ether, $.subvault, $.subvault)),
        //             false
        //         );
        //         tmp[i++] = Call(
        //             $.curator, asset, 1 wei, abi.encodeCall(IERC4626.redeem, (1 ether, $.subvault, $.subvault)), false
        //         );
        //         tmp[i++] = Call(
        //             $.curator, asset, 0, abi.encodeCall(IERC4626.redeem, (1 ether, address(0xdead), $.subvault)), false
        //         );
        //         tmp[i++] = Call(
        //             $.curator, asset, 0, abi.encodeCall(IERC4626.redeem, (1 ether, $.subvault, address(0xdead))), false
        //         );
        //         tmp[i++] = Call(
        //             $.curator, asset, 0, abi.encode(IERC4626.redeem.selector, 1 ether, $.subvault, $.subvault), false
        //         );
        //         assembly {
        //             mstore(tmp, i)
        //         }
        //         calls[index++] = tmp;
        //     }

        //     // ERC4626 withdraw
        //     {
        //         Call[] memory tmp = new Call[](16);
        //         uint256 i = 0;
        //         tmp[i++] =
        //             Call($.curator, asset, 0, abi.encodeCall(IERC4626.withdraw, (0, $.subvault, $.subvault)), true);
        //         tmp[i++] = Call(
        //             $.curator, asset, 0, abi.encodeCall(IERC4626.withdraw, (1 ether, $.subvault, $.subvault)), true
        //         );
        //         tmp[i++] = Call(
        //             address(0xdead),
        //             asset,
        //             0,
        //             abi.encodeCall(IERC4626.withdraw, (1 ether, $.subvault, $.subvault)),
        //             false
        //         );
        //         tmp[i++] = Call(
        //             $.curator,
        //             address(0xdead),
        //             0,
        //             abi.encodeCall(IERC4626.withdraw, (1 ether, $.subvault, $.subvault)),
        //             false
        //         );
        //         tmp[i++] = Call(
        //             $.curator, asset, 1 wei, abi.encodeCall(IERC4626.withdraw, (1 ether, $.subvault, $.subvault)), false
        //         );
        //         tmp[i++] = Call(
        //             $.curator,
        //             asset,
        //             0,
        //             abi.encodeCall(IERC4626.withdraw, (1 ether, address(0xdead), $.subvault)),
        //             false
        //         );
        //         tmp[i++] = Call(
        //             $.curator,
        //             asset,
        //             0,
        //             abi.encodeCall(IERC4626.withdraw, (1 ether, $.subvault, address(0xdead))),
        //             false
        //         );
        //         tmp[i++] = Call(
        //             $.curator, asset, 0, abi.encode(IERC4626.withdraw.selector, 1 ether, $.subvault, $.subvault), false
        //         );
        //         assembly {
        //             mstore(tmp, i)
        //         }
        //         calls[index++] = tmp;
        //     }
        // }
    }
}
