// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import {ABILibrary} from "../ABILibrary.sol";
import {JsonLibrary} from "../JsonLibrary.sol";
import "../ParameterLibrary.sol";
import "../ProofLibrary.sol";
import "../interfaces/Imports.sol";

library ERC4626Library {
    using ParameterLibrary for ParameterLibrary.Parameter[];

    struct Info {
        address subvault;
        string subvaultName;
        address curator;
        address[] assets;
    }

    function getERC4626Proofs(BitmaskVerifier bitmaskVerifier, Info memory $)
        internal
        view
        returns (IVerifier.VerificationPayload[] memory leaves)
    {
        uint256 length = ($.assets.length * 5);
        leaves = new IVerifier.VerificationPayload[](length);
        uint256 index = 0;
        for (uint256 i = 0; i < $.assets.length; i++) {
            address asset = $.assets[i];
            leaves[index++] = ProofLibrary.makeVerificationPayload(
                bitmaskVerifier,
                $.curator,
                IERC4626(asset).asset(),
                0,
                abi.encodeCall(IERC20.approve, (asset, 0)),
                ProofLibrary.makeBitmask(
                    true, true, true, true, abi.encodeCall(IERC20.approve, (address(type(uint160).max), 0))
                )
            );
            leaves[index++] = ProofLibrary.makeVerificationPayload(
                bitmaskVerifier,
                $.curator,
                asset,
                0,
                abi.encodeCall(IERC4626.deposit, (0, $.subvault)),
                ProofLibrary.makeBitmask(
                    true, true, true, true, abi.encodeCall(IERC4626.deposit, (0, address(type(uint160).max)))
                )
            );
            leaves[index++] = ProofLibrary.makeVerificationPayload(
                bitmaskVerifier,
                $.curator,
                asset,
                0,
                abi.encodeCall(IERC4626.mint, (0, $.subvault)),
                ProofLibrary.makeBitmask(
                    true, true, true, true, abi.encodeCall(IERC4626.mint, (0, address(type(uint160).max)))
                )
            );
            leaves[index++] = ProofLibrary.makeVerificationPayload(
                bitmaskVerifier,
                $.curator,
                asset,
                0,
                abi.encodeCall(IERC4626.redeem, (0, $.subvault, $.subvault)),
                ProofLibrary.makeBitmask(
                    true,
                    true,
                    true,
                    true,
                    abi.encodeCall(IERC4626.redeem, (0, address(type(uint160).max), address(type(uint160).max)))
                )
            );
            leaves[index++] = ProofLibrary.makeVerificationPayload(
                bitmaskVerifier,
                $.curator,
                asset,
                0,
                abi.encodeCall(IERC4626.withdraw, (0, $.subvault, $.subvault)),
                ProofLibrary.makeBitmask(
                    true,
                    true,
                    true,
                    true,
                    abi.encodeCall(IERC4626.withdraw, (0, address(type(uint160).max), address(type(uint160).max)))
                )
            );
        }
    }

    function getERC4626Descriptions(Info memory $) internal view returns (string[] memory descriptions) {
        uint256 length = ($.assets.length * 5);
        descriptions = new string[](length);
        uint256 index = 0;

        ParameterLibrary.Parameter[] memory innerParameters;
        for (uint256 i = 0; i < $.assets.length; i++) {
            address asset = $.assets[i];
            address underlyingAsset = IERC4626(asset).asset();

            string memory assetName = IERC20Metadata(asset).name();
            string memory underlyingAssetSymbol = IERC20Metadata(underlyingAsset).symbol();

            innerParameters = ParameterLibrary.build("to", Strings.toHexString(asset)).addAny("amount");
            descriptions[index++] = JsonLibrary.toJson(
                string(
                    abi.encodePacked("IERC20(", underlyingAssetSymbol, ").approve(IERC4626(", assetName, "), anyInt)")
                ),
                ABILibrary.getABI(IERC20.approve.selector),
                ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString(underlyingAsset), "0"),
                innerParameters
            );

            innerParameters = ParameterLibrary.buildAny("assets").add("receiver", Strings.toHexString($.subvault));
            descriptions[index++] = JsonLibrary.toJson(
                string(
                    abi.encodePacked("IERC4626(", assetName, ").deposit(anyInt, ", Strings.toHexString($.subvault), ")")
                ),
                ABILibrary.getABI(IERC4626.deposit.selector),
                ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString(asset), "0"),
                innerParameters
            );

            innerParameters = ParameterLibrary.buildAny("shares").add("receiver", Strings.toHexString($.subvault));
            descriptions[index++] = JsonLibrary.toJson(
                string(
                    abi.encodePacked("IERC4626(", assetName, ").mint(anyInt, ", Strings.toHexString($.subvault), ")")
                ),
                ABILibrary.getABI(IERC4626.mint.selector),
                ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString(asset), "0"),
                innerParameters
            );

            innerParameters = ParameterLibrary.buildAny("shares").add2(
                "receiver", Strings.toHexString($.subvault), "owner", Strings.toHexString($.subvault)
            );
            descriptions[index++] = JsonLibrary.toJson(
                string(
                    abi.encodePacked(
                        "IERC4626(",
                        assetName,
                        ").redeem(anyInt, ",
                        Strings.toHexString($.subvault),
                        ", ",
                        Strings.toHexString($.subvault),
                        ")"
                    )
                ),
                ABILibrary.getABI(IERC4626.redeem.selector),
                ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString(asset), "0"),
                innerParameters
            );

            innerParameters = ParameterLibrary.buildAny("assets").add2(
                "receiver", Strings.toHexString($.subvault), "owner", Strings.toHexString($.subvault)
            );
            descriptions[index++] = JsonLibrary.toJson(
                string(
                    abi.encodePacked(
                        "IERC4626(",
                        assetName,
                        ").withdraw(anyInt, ",
                        Strings.toHexString($.subvault),
                        ", ",
                        Strings.toHexString($.subvault),
                        ")"
                    )
                ),
                ABILibrary.getABI(IERC4626.withdraw.selector),
                ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString(asset), "0"),
                innerParameters
            );
        }
    }

    function getERC4626Calls(Info memory $) internal view returns (Call[][] memory calls) {
        uint256 index = 0;
        calls = new Call[][]($.assets.length * 5);

        for (uint256 j = 0; j < $.assets.length; j++) {
            address asset = $.assets[j];
            address underlyingAsset = IERC4626(asset).asset();
            {
                Call[] memory tmp = new Call[](16);
                uint256 i = 0;
                tmp[i++] = Call($.curator, underlyingAsset, 0, abi.encodeCall(IERC20.approve, (asset, 0)), true);
                tmp[i++] = Call($.curator, underlyingAsset, 0, abi.encodeCall(IERC20.approve, (asset, 1 ether)), true);
                tmp[i++] =
                    Call(address(0xdead), underlyingAsset, 0, abi.encodeCall(IERC20.approve, (asset, 1 ether)), false);
                tmp[i++] = Call($.curator, address(0xdead), 0, abi.encodeCall(IERC20.approve, (asset, 1 ether)), false);
                tmp[i++] = Call(
                    $.curator, underlyingAsset, 0, abi.encodeCall(IERC20.approve, (address(0xdead), 1 ether)), false
                );
                tmp[i++] =
                    Call($.curator, underlyingAsset, 1 wei, abi.encodeCall(IERC20.approve, (asset, 1 ether)), false);
                tmp[i++] =
                    Call($.curator, underlyingAsset, 0, abi.encode(IERC20.approve.selector, asset, 1 ether), false);
                assembly {
                    mstore(tmp, i)
                }
                calls[index++] = tmp;
            }

            // ERC4626 deposit
            {
                Call[] memory tmp = new Call[](16);
                uint256 i = 0;
                tmp[i++] = Call($.curator, asset, 0, abi.encodeCall(IERC4626.deposit, (0, $.subvault)), true);
                tmp[i++] = Call($.curator, asset, 0, abi.encodeCall(IERC4626.deposit, (1 ether, $.subvault)), true);
                tmp[i++] =
                    Call(address(0xdead), asset, 0, abi.encodeCall(IERC4626.deposit, (1 ether, $.subvault)), false);
                tmp[i++] =
                    Call($.curator, address(0xdead), 0, abi.encodeCall(IERC4626.deposit, (1 ether, $.subvault)), false);
                tmp[i++] = Call($.curator, asset, 1 wei, abi.encodeCall(IERC4626.deposit, (1 ether, $.subvault)), false);
                tmp[i++] =
                    Call($.curator, asset, 0, abi.encodeCall(IERC4626.deposit, (1 ether, address(0xdead))), false);
                tmp[i++] = Call($.curator, asset, 0, abi.encode(IERC4626.deposit.selector, 1 ether, $.subvault), false);
                assembly {
                    mstore(tmp, i)
                }
                calls[index++] = tmp;
            }

            // ERC4626 mint
            {
                Call[] memory tmp = new Call[](16);
                uint256 i = 0;
                tmp[i++] = Call($.curator, asset, 0, abi.encodeCall(IERC4626.mint, (0, $.subvault)), true);
                tmp[i++] = Call($.curator, asset, 0, abi.encodeCall(IERC4626.mint, (1 ether, $.subvault)), true);
                tmp[i++] = Call(address(0xdead), asset, 0, abi.encodeCall(IERC4626.mint, (1 ether, $.subvault)), false);
                tmp[i++] =
                    Call($.curator, address(0xdead), 0, abi.encodeCall(IERC4626.mint, (1 ether, $.subvault)), false);
                tmp[i++] = Call($.curator, asset, 1 wei, abi.encodeCall(IERC4626.mint, (1 ether, $.subvault)), false);
                tmp[i++] = Call($.curator, asset, 0, abi.encodeCall(IERC4626.mint, (1 ether, address(0xdead))), false);
                tmp[i++] = Call($.curator, asset, 0, abi.encode(IERC4626.mint.selector, 1 ether, $.subvault), false);
                assembly {
                    mstore(tmp, i)
                }
                calls[index++] = tmp;
            }

            // ERC4626 redeem
            {
                Call[] memory tmp = new Call[](16);
                uint256 i = 0;
                tmp[i++] = Call($.curator, asset, 0, abi.encodeCall(IERC4626.redeem, (0, $.subvault, $.subvault)), true);
                tmp[i++] =
                    Call($.curator, asset, 0, abi.encodeCall(IERC4626.redeem, (1 ether, $.subvault, $.subvault)), true);
                tmp[i++] = Call(
                    address(0xdead), asset, 0, abi.encodeCall(IERC4626.redeem, (1 ether, $.subvault, $.subvault)), false
                );
                tmp[i++] = Call(
                    $.curator,
                    address(0xdead),
                    0,
                    abi.encodeCall(IERC4626.redeem, (1 ether, $.subvault, $.subvault)),
                    false
                );
                tmp[i++] = Call(
                    $.curator, asset, 1 wei, abi.encodeCall(IERC4626.redeem, (1 ether, $.subvault, $.subvault)), false
                );
                tmp[i++] = Call(
                    $.curator, asset, 0, abi.encodeCall(IERC4626.redeem, (1 ether, address(0xdead), $.subvault)), false
                );
                tmp[i++] = Call(
                    $.curator, asset, 0, abi.encodeCall(IERC4626.redeem, (1 ether, $.subvault, address(0xdead))), false
                );
                tmp[i++] = Call(
                    $.curator, asset, 0, abi.encode(IERC4626.redeem.selector, 1 ether, $.subvault, $.subvault), false
                );
                assembly {
                    mstore(tmp, i)
                }
                calls[index++] = tmp;
            }

            // ERC4626 withdraw
            {
                Call[] memory tmp = new Call[](16);
                uint256 i = 0;
                tmp[i++] =
                    Call($.curator, asset, 0, abi.encodeCall(IERC4626.withdraw, (0, $.subvault, $.subvault)), true);
                tmp[i++] = Call(
                    $.curator, asset, 0, abi.encodeCall(IERC4626.withdraw, (1 ether, $.subvault, $.subvault)), true
                );
                tmp[i++] = Call(
                    address(0xdead),
                    asset,
                    0,
                    abi.encodeCall(IERC4626.withdraw, (1 ether, $.subvault, $.subvault)),
                    false
                );
                tmp[i++] = Call(
                    $.curator,
                    address(0xdead),
                    0,
                    abi.encodeCall(IERC4626.withdraw, (1 ether, $.subvault, $.subvault)),
                    false
                );
                tmp[i++] = Call(
                    $.curator, asset, 1 wei, abi.encodeCall(IERC4626.withdraw, (1 ether, $.subvault, $.subvault)), false
                );
                tmp[i++] = Call(
                    $.curator,
                    asset,
                    0,
                    abi.encodeCall(IERC4626.withdraw, (1 ether, address(0xdead), $.subvault)),
                    false
                );
                tmp[i++] = Call(
                    $.curator,
                    asset,
                    0,
                    abi.encodeCall(IERC4626.withdraw, (1 ether, $.subvault, address(0xdead))),
                    false
                );
                tmp[i++] = Call(
                    $.curator, asset, 0, abi.encode(IERC4626.withdraw.selector, 1 ether, $.subvault, $.subvault), false
                );
                assembly {
                    mstore(tmp, i)
                }
                calls[index++] = tmp;
            }
        }
    }
}
