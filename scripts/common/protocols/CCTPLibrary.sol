// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {ABILibrary} from "../ABILibrary.sol";
import {ArraysLibrary} from "../ArraysLibrary.sol";
import {JsonLibrary} from "../JsonLibrary.sol";
import {ParameterLibrary} from "../ParameterLibrary.sol";
import {ProofLibrary} from "../ProofLibrary.sol";
import {ERC20Library} from "./ERC20Library.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import "../interfaces/Imports.sol";
import {ITokenMessenger} from "../interfaces/ITokenMessenger.sol";
import {IMessageTransmitter} from "../interfaces/IMessageTransmitter.sol";

library CCTPLibrary {
    using ParameterLibrary for ParameterLibrary.Parameter[];

    struct Info {
        address curator;
        address subvault;
        string subvaultName;
        address tokenMessenger;
        address messageTransmitter;
        uint32 destinationDomain;
        address mintRecipient;
        address burnToken;
        address caller; // if not zero -> depositForBurnWithCaller, else depositForBurn
    }

    function getCCTPProofs(BitmaskVerifier bitmaskVerifier, Info memory $)
        internal
        view
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
                abi.encodeCall(ITokenMessenger.depositForBurn, (0, $.destinationDomain, addressToBytes32($.mintRecipient), $.burnToken)),
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
                    (0, $.destinationDomain, addressToBytes32($.mintRecipient), $.burnToken, addressToBytes32($.caller))
                ),
                ProofLibrary.makeBitmask(
                    true,
                    true,
                    true,
                    true,
                    abi.encodeCall(
                        ITokenMessenger.depositForBurnWithCaller,
                        (0, type(uint32).max, bytes32(type(uint256).max), address(type(uint160).max), bytes32(type(uint256).max))
                    )
                )
            );
        }

        leaves[iterator++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.messageTransmitter,
            0,
            abi.encodeCall(IMessageTransmitter.receiveMessage, (new bytes(0), new bytes(0))),
            ProofLibrary.makeBitmask(
                true,
                true,
                true,
                true,
                abi.encodeCall(
                    IMessageTransmitter.receiveMessage,
                    (new bytes(0), new bytes(0))
                )
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
            innerParameters = innerParameters.addAny("amount").add("destinationDomain", Strings.toString($.destinationDomain)).add(
                "mintRecipient", Strings.toHexString($.mintRecipient)).add("burnToken", Strings.toHexString($.burnToken));

            descriptions[iterator++] = JsonLibrary.toJson(
                string(abi.encodePacked(
                    "TokenMessenger(", Strings.toHexString($.tokenMessenger), ").depositForBurn(any,", 
                    Strings.toString($.destinationDomain), ", ",
                    Strings.toHexString($.mintRecipient), ", ",
                    Strings.toHexString($.burnToken), ")"
                )),
                ABILibrary.getABI(ITokenMessenger.depositForBurn.selector),
                ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.tokenMessenger), "0"),
                innerParameters
            );
        } else {
            ParameterLibrary.Parameter[] memory innerParameters;
            innerParameters = innerParameters.addAny("amount").add("destinationDomain", Strings.toString($.destinationDomain)).add(
                "mintRecipient", Strings.toHexString($.mintRecipient)).add("burnToken", Strings.toHexString($.burnToken))
                .add("destinationCaller", Strings.toHexString($.caller));

            descriptions[iterator++] = JsonLibrary.toJson(
                string(abi.encodePacked(
                    "TokenMessenger(", Strings.toHexString($.tokenMessenger), ").depositForBurnWithCaller(any,", 
                    Strings.toString($.destinationDomain),  ", ",
                    Strings.toHexString($.mintRecipient), ", ",
                    Strings.toHexString($.burnToken), ", ",
                    Strings.toHexString($.caller), ")"
                )),
                ABILibrary.getABI(ITokenMessenger.depositForBurnWithCaller.selector),
                ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.tokenMessenger), "0"),
                innerParameters
            );
        }

        ParameterLibrary.Parameter[] memory innerParameters;
        innerParameters = innerParameters.addAny("message").addAny("signature");

        descriptions[iterator++] = JsonLibrary.toJson(
            string(abi.encodePacked(
                "MessageTransmitter(", Strings.toHexString($.messageTransmitter), ").receiveMessage(any, any)"
            )),
            ABILibrary.getABI(IMessageTransmitter.receiveMessage.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.messageTransmitter), "0"),
            innerParameters
        );
    }

    function addressToBytes32(address addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }

    function bytes32ToAddress(bytes32 data) internal pure returns (address) {
        return address(uint160(uint256(data)));
    }
}
