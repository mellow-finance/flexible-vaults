// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/utils/Strings.sol";

import {ABILibrary} from "../ABILibrary.sol";
import {JsonLibrary} from "../JsonLibrary.sol";
import {ParameterLibrary} from "../ParameterLibrary.sol";
import "../ProofLibrary.sol";

import "../interfaces/ITokenMessengerV2.sol";
import "../interfaces/Imports.sol";

library CircleBridgeLibrary {
    using ParameterLibrary for ParameterLibrary.Parameter[];

    struct Info {
        address strategy;
        address tokenMessenger;
        address destinationSubvault;
        uint32 destinationDomain;
        address[] assets;
    }

    function getCctpV2BridgeProofs(BitmaskVerifier bitmaskVerifier, Info memory $)
        internal
        pure
        returns (IVerifier.VerificationPayload[] memory leaves)
    {
        /*
            0. IERC20.approve(tokenMessenger, any);
            1. ITokenMessengerV2.depositForBurn(any, destinationDomain, mintRecipient, burnToken, bytes32(0), any, any);
        */
        uint256 length = $.assets.length * 2;
        leaves = new IVerifier.VerificationPayload[](length);
        uint256 index = 0;

        for (uint256 i = 0; i < $.assets.length; i++) {
            leaves[index++] = ProofLibrary.makeVerificationPayload(
                bitmaskVerifier,
                $.strategy,
                $.assets[i],
                0,
                abi.encodeCall(IERC20.approve, ($.tokenMessenger, 0)),
                ProofLibrary.makeBitmask(
                    true, true, true, true, abi.encodeCall(IERC20.approve, (address(type(uint160).max), 0))
                )
            );

            leaves[index++] = ProofLibrary.makeVerificationPayload(
                bitmaskVerifier,
                $.strategy,
                $.tokenMessenger,
                0,
                abi.encodeCall(
                    ITokenMessengerV2.depositForBurn,
                    (
                        0,
                        $.destinationDomain,
                        bytes32(uint256(uint160($.destinationSubvault))),
                        $.assets[i],
                        bytes32(0), // authorize any caller on the destination domain
                        0,
                        0
                    )
                ),
                ProofLibrary.makeBitmask(
                    true,
                    true,
                    true,
                    true,
                    abi.encodeCall(
                        ITokenMessengerV2.depositForBurn,
                        (
                            0,
                            type(uint32).max,
                            bytes32(type(uint256).max),
                            address(type(uint160).max),
                            bytes32(type(uint256).max), // authorize any caller on the destination domain
                            0,
                            0
                        )
                    )
                )
            );
        }
    }

    function getCctpV2BridgeDescriptions(Info memory $) internal view returns (string[] memory descriptions) {
        uint256 length = $.assets.length * 2;
        descriptions = new string[](length);
        uint256 index = 0;
        ParameterLibrary.Parameter[] memory innerParameters;

        for (uint256 i = 0; i < $.assets.length; i++) {
            address asset = $.assets[i];
            string memory assets = IERC20Metadata(asset).symbol();
            innerParameters = ParameterLibrary.build("to", Strings.toHexString($.tokenMessenger)).addAny("amount");
            descriptions[index++] = JsonLibrary.toJson(
                string(abi.encodePacked("IERC20(", assets, ").approve(TokenMessenger, anyInt)")),
                ABILibrary.getABI(IERC20.approve.selector),
                ParameterLibrary.build(Strings.toHexString($.strategy), Strings.toHexString(asset), "0"),
                innerParameters
            );

            innerParameters = ParameterLibrary.build("amount", "any");
            innerParameters = innerParameters.add("destinationDomain", Strings.toString($.destinationDomain));
            innerParameters = innerParameters.add("mintRecipient", Strings.toHexString($.destinationSubvault));
            innerParameters = innerParameters.add("burnToken", Strings.toHexString(asset));
            innerParameters = innerParameters.addAny("destinationCaller");
            innerParameters = innerParameters.addAny("maxFee");
            innerParameters = innerParameters.addAny("minFinalityThreshold");
            descriptions[index++] = JsonLibrary.toJson(
                string(
                    abi.encodePacked(
                        "ITokenMessengerV2.depositForBurn(anyInt, ",
                        Strings.toString($.destinationDomain),
                        ", ",
                        Strings.toHexString($.destinationSubvault),
                        ", ",
                        assets,
                        ", ",
                        Strings.toHexString(0),
                        ", anyInt, anyInt)"
                    )
                ),
                ABILibrary.getABI(ITokenMessengerV2.depositForBurn.selector),
                ParameterLibrary.build(Strings.toHexString($.strategy), Strings.toHexString($.tokenMessenger), "0"),
                innerParameters
            );
        }
    }

    function getCctpV2BridgeCalls(Info memory $) internal pure returns (Call[][] memory calls) {
        uint256 index = 0;
        calls = new Call[][]($.assets.length * 2);
        for (uint256 j = 0; j < $.assets.length; j++) {
            address asset = $.assets[j];

            {
                Call[] memory tmp = new Call[](16);
                uint256 i = 0;
                tmp[i++] = Call($.strategy, asset, 0, abi.encodeCall(IERC20.approve, ($.tokenMessenger, 0)), true);
                tmp[i++] = Call($.strategy, asset, 0, abi.encodeCall(IERC20.approve, ($.tokenMessenger, 1 ether)), true);
                tmp[i++] =
                    Call(address(0xdead), asset, 0, abi.encodeCall(IERC20.approve, ($.tokenMessenger, 1 ether)), false);
                tmp[i++] = Call(
                    $.strategy, address(0xdead), 0, abi.encodeCall(IERC20.approve, ($.tokenMessenger, 1 ether)), false
                );
                tmp[i++] = Call($.strategy, asset, 0, abi.encodeCall(IERC20.approve, (address(0xdead), 1 ether)), false);
                tmp[i++] =
                    Call($.strategy, asset, 1 wei, abi.encodeCall(IERC20.approve, ($.tokenMessenger, 1 ether)), false);
                tmp[i++] =
                    Call($.strategy, asset, 0, abi.encode(IERC20.approve.selector, $.tokenMessenger, 1 ether), false);
                assembly {
                    mstore(tmp, i)
                }
                calls[index++] = tmp;
            }

            {
                //  depositForBurn(uint256 amount, uint32 destinationDomain, bytes32 mintRecipient, address burnToken, bytes32 destinationCaller, uint256 maxFee, uint32 minFinalityThreshold)
                Call[] memory tmp = new Call[](42);
                uint256 i = 0;
                // valid call with 0 amount
                tmp[i++] = Call(
                    $.strategy,
                    $.tokenMessenger,
                    0,
                    abi.encodeCall(
                        ITokenMessengerV2.depositForBurn,
                        (
                            0,
                            $.destinationDomain,
                            bytes32(uint256(uint160($.destinationSubvault))),
                            asset,
                            bytes32(0),
                            0,
                            0
                        )
                    ),
                    true
                );
                // valid call with 1 ether amount
                tmp[i++] = Call(
                    $.strategy,
                    $.tokenMessenger,
                    0,
                    abi.encodeCall(
                        ITokenMessengerV2.depositForBurn,
                        (
                            1 ether,
                            $.destinationDomain,
                            bytes32(uint256(uint160($.destinationSubvault))),
                            asset,
                            bytes32(0),
                            0,
                            0
                        )
                    ),
                    true
                );
                // valid call with maxFee > 0
                tmp[i++] = Call(
                    $.strategy,
                    $.tokenMessenger,
                    0,
                    abi.encodeCall(
                        ITokenMessengerV2.depositForBurn,
                        (
                            0,
                            $.destinationDomain,
                            bytes32(uint256(uint160($.destinationSubvault))),
                            asset,
                            bytes32(0),
                            1 ether,
                            0
                        )
                    ),
                    true
                );
                // valid call with minFinalityThreshold > 0
                tmp[i++] = Call(
                    $.strategy,
                    $.tokenMessenger,
                    0,
                    abi.encodeCall(
                        ITokenMessengerV2.depositForBurn,
                        (
                            0,
                            $.destinationDomain,
                            bytes32(uint256(uint160($.destinationSubvault))),
                            asset,
                            bytes32(0),
                            0,
                            1
                        )
                    ),
                    true
                );
                // invalid call from wrong address
                tmp[i++] = Call(
                    address(0xdead),
                    $.tokenMessenger,
                    0,
                    abi.encodeCall(
                        ITokenMessengerV2.depositForBurn,
                        (
                            0,
                            $.destinationDomain,
                            bytes32(uint256(uint160($.destinationSubvault))),
                            asset,
                            bytes32(0),
                            0,
                            0
                        )
                    ),
                    false
                );
                // invalid call with wrong target address
                tmp[i++] = Call(
                    $.strategy,
                    address(0xdead),
                    0,
                    abi.encodeCall(
                        ITokenMessengerV2.depositForBurn,
                        (
                            0,
                            $.destinationDomain,
                            bytes32(uint256(uint160($.destinationSubvault))),
                            asset,
                            bytes32(0),
                            0,
                            0
                        )
                    ),
                    false
                );
                // invalid call with msg.value > 0
                tmp[i++] = Call(
                    $.strategy,
                    $.tokenMessenger,
                    1 wei,
                    abi.encodeCall(
                        ITokenMessengerV2.depositForBurn,
                        (
                            0,
                            $.destinationDomain,
                            bytes32(uint256(uint160($.destinationSubvault))),
                            asset,
                            bytes32(0),
                            0,
                            0
                        )
                    ),
                    false
                );
                // invalid call with wrong destinationDomain
                tmp[i++] = Call(
                    $.strategy,
                    $.tokenMessenger,
                    0,
                    abi.encodeCall(
                        ITokenMessengerV2.depositForBurn,
                        (
                            1 ether,
                            $.destinationDomain + 1,
                            bytes32(uint256(uint160($.destinationSubvault))),
                            asset,
                            bytes32(0),
                            0,
                            0
                        )
                    ),
                    false
                );
                // invalid call with wrong destinationSubvault
                tmp[i++] = Call(
                    $.strategy,
                    $.tokenMessenger,
                    0,
                    abi.encodeCall(
                        ITokenMessengerV2.depositForBurn,
                        (0, $.destinationDomain, bytes32(uint256(uint160(0xdead))), asset, bytes32(0), 0, 0)
                    ),
                    false
                );
                // invalid call with wrong burnToken
                tmp[i++] = Call(
                    $.strategy,
                    $.tokenMessenger,
                    0,
                    abi.encodeCall(
                        ITokenMessengerV2.depositForBurn,
                        (
                            0,
                            $.destinationDomain,
                            bytes32(uint256(uint160($.destinationSubvault))),
                            address(0xdead),
                            bytes32(0),
                            0,
                            0
                        )
                    ),
                    false
                );
                // invalid call with specified destination caller
                tmp[i++] = Call(
                    $.strategy,
                    $.tokenMessenger,
                    0,
                    abi.encodeCall(
                        ITokenMessengerV2.depositForBurn,
                        (
                            0,
                            $.destinationDomain,
                            bytes32(uint256(uint160($.destinationSubvault))),
                            asset,
                            bytes32(uint256(1)),
                            0,
                            0
                        )
                    ),
                    false
                );
                assembly {
                    mstore(tmp, i)
                }
                calls[index++] = tmp;
            }
        }
    }
}
