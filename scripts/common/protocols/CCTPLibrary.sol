// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {ABILibrary} from "../ABILibrary.sol";
import {ArraysLibrary} from "../ArraysLibrary.sol";
import {JsonLibrary} from "../JsonLibrary.sol";
import {ParameterLibrary} from "../ParameterLibrary.sol";
import {ProofLibrary} from "../ProofLibrary.sol";
import {ERC20Library} from "./ERC20Library.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {IMessageTransmitter} from "../interfaces/IMessageTransmitter.sol";
import {ITokenMessenger} from "../interfaces/ITokenMessenger.sol";
import "../interfaces/Imports.sol";

library CCTPLibrary {
    using ParameterLibrary for ParameterLibrary.Parameter[];

    /// 248 bytes - is a regular length of CCTP message without body
    uint256 constant CCTP_MESSAGE_DEFAULT_LENGTH = 248;

    /// @dev usually CCTP uses two 65 bytes signature
    uint256 constant CCTP_SIGNATURE_DEFAULT_LENGTH = 130;

    struct Info {
        address curator;
        address subvault;
        string subvaultName;
        address subvaultTarget;
        string subvaultTargetName;
        string targetChainName;
        address tokenMessenger;
        address messageTransmitter;
        uint32 destinationDomain;
        address burnToken;
        address caller; // if not zero -> depositForBurnWithCaller, else depositForBurn
    }

    function getCCTPProofs(BitmaskVerifier bitmaskVerifier, Info memory $)
        internal
        pure
        returns (IVerifier.VerificationPayload[] memory leaves)
    {
        leaves = new IVerifier.VerificationPayload[](3);
        uint256 iterator = 0;

        iterator = ArraysLibrary.insert(
            leaves,
            ERC20Library.getERC20Proofs(
                bitmaskVerifier,
                ERC20Library.Info({
                    curator: $.curator,
                    assets: ArraysLibrary.makeAddressArray(abi.encode($.burnToken)),
                    to: ArraysLibrary.makeAddressArray(abi.encode($.tokenMessenger))
                })
            ),
            iterator
        );
        if ($.caller == address(0)) {
            leaves[iterator++] = ProofLibrary.makeVerificationPayload(
                bitmaskVerifier,
                $.curator,
                $.tokenMessenger,
                0,
                abi.encodeCall(
                    ITokenMessenger.depositForBurn,
                    (0, $.destinationDomain, addressToBytes32($.subvaultTarget), $.burnToken)
                ),
                ProofLibrary.makeBitmask(
                    true,
                    true,
                    true,
                    true,
                    abi.encodeCall(
                        ITokenMessenger.depositForBurn,
                        (0, type(uint32).max, bytes32(type(uint256).max), address(type(uint160).max))
                    )
                )
            );
        } else {
            leaves[iterator++] = ProofLibrary.makeVerificationPayload(
                bitmaskVerifier,
                $.curator,
                $.tokenMessenger,
                0,
                abi.encodeCall(
                    ITokenMessenger.depositForBurnWithCaller,
                    (
                        0,
                        $.destinationDomain,
                        addressToBytes32($.subvaultTarget),
                        $.burnToken,
                        addressToBytes32($.caller)
                    )
                ),
                ProofLibrary.makeBitmask(
                    true,
                    true,
                    true,
                    true,
                    abi.encodeCall(
                        ITokenMessenger.depositForBurnWithCaller,
                        (
                            0,
                            type(uint32).max,
                            bytes32(type(uint256).max),
                            address(type(uint160).max),
                            bytes32(type(uint256).max)
                        )
                    )
                )
            );
        }
        /// @dev ability to receive any message
        bytes memory defaultEmptyMessage = new bytes(CCTP_MESSAGE_DEFAULT_LENGTH);
        bytes memory defaultEmptySignature = new bytes(CCTP_SIGNATURE_DEFAULT_LENGTH);

        leaves[iterator++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.messageTransmitter,
            0,
            abi.encodeCall(IMessageTransmitter.receiveMessage, (defaultEmptyMessage, defaultEmptySignature)),
            ProofLibrary.makeBitmask(
                true,
                true,
                true,
                true,
                abi.encodeCall(IMessageTransmitter.receiveMessage, (defaultEmptyMessage, defaultEmptySignature))
            )
        );
    }

    function getCCTPDescriptions(Info memory $) internal view returns (string[] memory descriptions) {
        descriptions = new string[](3);
        uint256 iterator = 0;

        iterator = ArraysLibrary.insert(
            descriptions,
            ERC20Library.getERC20Descriptions(
                ERC20Library.Info({
                    curator: $.curator,
                    assets: ArraysLibrary.makeAddressArray(abi.encode($.burnToken)),
                    to: ArraysLibrary.makeAddressArray(abi.encode($.tokenMessenger))
                })
            ),
            iterator
        );

        if ($.caller == address(0)) {
            ParameterLibrary.Parameter[] memory innerParameters;
            innerParameters = innerParameters.addAny("amount").add(
                "destinationDomain", Strings.toString($.destinationDomain)
            ).add("subvaultTarget", Strings.toHexString($.subvaultTarget)).add(
                "burnToken", Strings.toHexString($.burnToken)
            );

            descriptions[iterator++] = JsonLibrary.toJson(
                string(
                    abi.encodePacked(
                        "TokenMessenger.depositForBurn(anyInt, ",
                        "targetChain=",
                        $.targetChainName,
                        ", ",
                        "targetSubvault=",
                        $.subvaultTargetName,
                        ", ",
                        "burnToken=",
                        IERC20Metadata($.burnToken).symbol(),
                        ")"
                    )
                ),
                ABILibrary.getABI(ITokenMessenger.depositForBurn.selector),
                ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.tokenMessenger), "0"),
                innerParameters
            );
        } else {
            ParameterLibrary.Parameter[] memory innerParameters;
            innerParameters = innerParameters.addAny("amount").add(
                "destinationDomain", Strings.toString($.destinationDomain)
            ).add("subvaultTarget", Strings.toHexString($.subvaultTarget)).add(
                "burnToken", Strings.toHexString($.burnToken)
            ).add("destinationCaller", Strings.toHexString($.caller));

            descriptions[iterator++] = JsonLibrary.toJson(
                string(
                    abi.encodePacked(
                        "TokenMessenger.depositForBurnWithCaller(anyInt, ",
                        "targetChain=",
                        $.targetChainName,
                        ", ",
                        "targetSubvault=",
                        $.subvaultTargetName,
                        ", ",
                        "burnToken=",
                        IERC20Metadata($.burnToken).symbol(),
                        ", ",
                        "destinationCaller=",
                        Strings.toHexString($.caller),
                        ")"
                    )
                ),
                ABILibrary.getABI(ITokenMessenger.depositForBurnWithCaller.selector),
                ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.tokenMessenger), "0"),
                innerParameters
            );
        }

        ParameterLibrary.Parameter[] memory innerParameters;
        innerParameters = innerParameters.addAny("message").addAny("signature");

        descriptions[iterator++] = JsonLibrary.toJson(
            string(abi.encodePacked("MessageTransmitter.receiveMessage(anyBytes, anyBytes)")),
            ABILibrary.getABI(IMessageTransmitter.receiveMessage.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.messageTransmitter), "0"),
            innerParameters
        );
    }

    function getCCTPCalls(Info memory $) internal pure returns (Call[][] memory calls) {
        uint256 index = 0;
        calls = new Call[][](100);

        index = ArraysLibrary.insert(
            calls,
            ERC20Library.getERC20Calls(
                ERC20Library.Info({
                    curator: $.curator,
                    assets: ArraysLibrary.makeAddressArray(abi.encode($.burnToken)),
                    to: ArraysLibrary.makeAddressArray(abi.encode($.tokenMessenger))
                })
            ),
            index
        );

        // ITokenMessenger.depositForBurn
        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            if ($.caller == address(0)) {
                tmp[i++] = Call(
                    $.curator,
                    $.tokenMessenger,
                    0,
                    abi.encodeCall(
                        ITokenMessenger.depositForBurn,
                        (0, $.destinationDomain, addressToBytes32($.subvaultTarget), $.burnToken)
                    ),
                    true
                );
                tmp[i++] = Call(
                    $.curator,
                    $.tokenMessenger,
                    0,
                    abi.encodeCall(
                        ITokenMessenger.depositForBurn,
                        (1e6, $.destinationDomain, addressToBytes32($.subvaultTarget), $.burnToken)
                    ),
                    true
                );
                tmp[i++] = Call(
                    $.curator,
                    $.tokenMessenger,
                    1 wei,
                    abi.encodeCall(
                        ITokenMessenger.depositForBurn,
                        (0, $.destinationDomain, addressToBytes32($.subvaultTarget), $.burnToken)
                    ),
                    false
                );
                tmp[i++] = Call(
                    $.curator,
                    $.tokenMessenger,
                    0,
                    abi.encodeCall(
                        ITokenMessenger.depositForBurn,
                        (1e6, $.destinationDomain + 1, addressToBytes32($.subvaultTarget), $.burnToken)
                    ),
                    false
                );
                tmp[i++] = Call(
                    $.curator,
                    $.tokenMessenger,
                    0,
                    abi.encodeCall(
                        ITokenMessenger.depositForBurn,
                        (1e6, $.destinationDomain, addressToBytes32(address(0xdead)), $.burnToken)
                    ),
                    false // bad call
                );
                tmp[i++] = Call(
                    $.curator,
                    $.tokenMessenger,
                    0,
                    abi.encodeCall(
                        ITokenMessenger.depositForBurn,
                        (1e6, $.destinationDomain, addressToBytes32($.subvaultTarget), address(0xdead))
                    ),
                    false
                );
                tmp[i++] = Call(
                    $.curator,
                    $.tokenMessenger,
                    0,
                    abi.encode(
                        ITokenMessenger.depositForBurn.selector,
                        1e6,
                        $.destinationDomain,
                        addressToBytes32($.subvaultTarget),
                        $.burnToken
                    ),
                    false
                );
            } else {
                tmp[i++] = Call(
                    $.curator,
                    $.tokenMessenger,
                    0,
                    abi.encodeCall(
                        ITokenMessenger.depositForBurnWithCaller,
                        (
                            0,
                            $.destinationDomain,
                            addressToBytes32($.subvaultTarget),
                            $.burnToken,
                            addressToBytes32($.caller)
                        )
                    ),
                    true
                );
                tmp[i++] = Call(
                    $.curator,
                    $.tokenMessenger,
                    0,
                    abi.encodeCall(
                        ITokenMessenger.depositForBurnWithCaller,
                        (
                            1e6,
                            $.destinationDomain,
                            addressToBytes32($.subvaultTarget),
                            $.burnToken,
                            addressToBytes32($.caller)
                        )
                    ),
                    true
                );
                tmp[i++] = Call(
                    $.curator,
                    $.tokenMessenger,
                    1 wei,
                    abi.encodeCall(
                        ITokenMessenger.depositForBurnWithCaller,
                        (
                            0,
                            $.destinationDomain,
                            addressToBytes32($.subvaultTarget),
                            $.burnToken,
                            addressToBytes32($.caller)
                        )
                    ),
                    false
                );
                tmp[i++] = Call(
                    $.curator,
                    $.tokenMessenger,
                    0,
                    abi.encodeCall(
                        ITokenMessenger.depositForBurnWithCaller,
                        (
                            1e6,
                            $.destinationDomain + 1,
                            addressToBytes32($.subvaultTarget),
                            $.burnToken,
                            addressToBytes32($.caller)
                        )
                    ),
                    false
                );
                tmp[i++] = Call(
                    $.curator,
                    $.tokenMessenger,
                    0,
                    abi.encodeCall(
                        ITokenMessenger.depositForBurnWithCaller,
                        (
                            1e6,
                            $.destinationDomain,
                            addressToBytes32(address(0xdead)),
                            $.burnToken,
                            addressToBytes32($.caller)
                        )
                    ),
                    false
                );
                tmp[i++] = Call(
                    $.curator,
                    $.tokenMessenger,
                    0,
                    abi.encodeCall(
                        ITokenMessenger.depositForBurnWithCaller,
                        (
                            1e6,
                            $.destinationDomain,
                            addressToBytes32($.subvaultTarget),
                            address(0xdead),
                            addressToBytes32($.caller)
                        )
                    ),
                    false
                );
                tmp[i++] = Call(
                    $.curator,
                    $.tokenMessenger,
                    0,
                    abi.encodeCall(
                        ITokenMessenger.depositForBurnWithCaller,
                        (
                            1e6,
                            $.destinationDomain,
                            addressToBytes32($.subvaultTarget),
                            $.burnToken,
                            addressToBytes32(address(0xdead))
                        )
                    ),
                    false
                );
                tmp[i++] = Call(
                    $.curator,
                    $.tokenMessenger,
                    0,
                    abi.encode(
                        ITokenMessenger.depositForBurnWithCaller.selector,
                        1e6,
                        $.destinationDomain,
                        addressToBytes32($.subvaultTarget),
                        $.burnToken,
                        addressToBytes32($.caller)
                    ),
                    false
                );
            }
            assembly {
                mstore(tmp, i)
            }
            calls[index++] = tmp;
        }
        // IMessageTransmitter.receiveMessage
        {
            // real tx https://etherscan.io/tx/0x5a770beae8e755ff8e6fbe90e0b701935adc56d88e4ec16185406b17a2502190
            bytes memory message =
                hex"00000000000000060000000000000000000b9e9f0000000000000000000000001682ae6375c4e4a97e4b583bc394c861a46d8962000000000000000000000000bd3fa81b58ba92a82136038b25adec7066af3155000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000833589fcd6edb6e08f4c7c32d4f71b54bda02913000000000000000000000000fd62020cee216dc543e29752058ee9f60f7d9ff900000000000000000000000000000000000000000000000000000000000f4240000000000000000000000000fd62020cee216dc543e29752058ee9f60f7d9ff9";
            bytes memory signature =
                hex"0cca607b30e28758e4b25a424e3889d7e79ab43d0bfe08f5e05c7f696092c7666da9b3524d7a5d966863827ef8a6eef32f7406d6bbd19bd9d785b30eea7ab9c21b222ebd743325ddd4fb33894251913a12ccf84f9eeb09389987d93ccee39859095d7f5e09740244d7832b04d2cd2b316f25cd26a1ce9049d230278904db6ec4c51c";
            bytes memory emptyMessage = new bytes(CCTP_MESSAGE_DEFAULT_LENGTH);
            bytes memory emptySignature = new bytes(CCTP_SIGNATURE_DEFAULT_LENGTH);
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] = Call(
                $.curator,
                $.messageTransmitter,
                0,
                abi.encodeCall(IMessageTransmitter.receiveMessage, (emptyMessage, emptySignature)),
                true
            );
            tmp[i++] = Call(
                $.curator,
                $.messageTransmitter,
                0,
                abi.encodeCall(IMessageTransmitter.receiveMessage, (message, emptySignature)),
                true
            );
            tmp[i++] = Call(
                $.curator,
                $.messageTransmitter,
                0,
                abi.encodeCall(IMessageTransmitter.receiveMessage, (emptyMessage, signature)),
                true
            );
            tmp[i++] = Call(
                $.curator,
                $.messageTransmitter,
                0,
                abi.encodeCall(IMessageTransmitter.receiveMessage, (message, signature)),
                true
            );
            tmp[i++] = Call(
                $.curator,
                $.messageTransmitter,
                0,
                abi.encodeCall(IMessageTransmitter.receiveMessage, (new bytes(0), signature)),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.messageTransmitter,
                0,
                abi.encodeCall(IMessageTransmitter.receiveMessage, (message, new bytes(0))),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.messageTransmitter,
                0,
                abi.encodeCall(IMessageTransmitter.receiveMessage, (new bytes(0), new bytes(0))),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.messageTransmitter,
                1 wei,
                abi.encodeCall(IMessageTransmitter.receiveMessage, (message, signature)),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.messageTransmitter,
                0,
                abi.encode(IMessageTransmitter.receiveMessage.selector, message, signature),
                false
            );
            assembly {
                mstore(tmp, i)
            }
            calls[index++] = tmp;
        }
        assembly {
            mstore(calls, index)
        }
    }

    function addressToBytes32(address addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }

    function bytes32ToAddress(bytes32 data) internal pure returns (address) {
        return address(uint160(uint256(data)));
    }
}
