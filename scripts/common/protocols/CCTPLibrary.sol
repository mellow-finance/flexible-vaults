// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {ABILibrary} from "../ABILibrary.sol";
import {ArraysLibrary} from "../ArraysLibrary.sol";
import {JsonLibrary} from "../JsonLibrary.sol";
import {ParameterLibrary} from "../ParameterLibrary.sol";
import {ProofLibrary} from "../ProofLibrary.sol";
import {ERC20Library} from "./ERC20Library.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {ITokenMessenger} from "../interfaces/ITokenMessenger.sol";
import "../interfaces/Imports.sol";

library CCTPLibrary {
    using ParameterLibrary for ParameterLibrary.Parameter[];

    struct Info {
        address curator;
        address subvault;
        string subvaultName;
        address subvaultTarget;
        string subvaultTargetName;
        string targetChainName;
        address tokenMessenger;
        address destinationCaller;
        uint32 destinationDomain;
        address burnToken;
    }

    function getCCTPProofs(BitmaskVerifier bitmaskVerifier, Info memory $)
        internal
        pure
        returns (IVerifier.VerificationPayload[] memory leaves)
    {
        leaves = new IVerifier.VerificationPayload[](20);
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

        leaves[iterator++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.tokenMessenger,
            0,
            abi.encodeCall(
                ITokenMessenger.depositForBurn,
                (
                    0,
                    $.destinationDomain,
                    addressToBytes32($.subvaultTarget),
                    $.burnToken,
                    addressToBytes32($.destinationCaller),
                    0,
                    2000
                )
            ),
            ProofLibrary.makeBitmask(
                true,
                true,
                true,
                true,
                abi.encodeCall(
                    ITokenMessenger.depositForBurn,
                    (
                        0, // amount
                        type(uint32).max, // destinationDomain
                        bytes32(type(uint256).max), // mintRecipient
                        address(type(uint160).max), // burnToken
                        bytes32(type(uint256).max), // caller
                        type(uint256).max, // maxFee
                        type(uint32).max // minFinalityThreshold
                    )
                )
            )
        );
        assembly {
            mstore(leaves, iterator)
        }
    }

    function getCCTPDescriptions(Info memory $) internal view returns (string[] memory descriptions) {
        descriptions = new string[](2);
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
        ParameterLibrary.Parameter[] memory innerParameters;
        innerParameters =
            innerParameters.addAny("amount").add("destinationDomain", Strings.toString($.destinationDomain));
        innerParameters = innerParameters.add("subvaultTarget", Strings.toHexString($.subvaultTarget));
        innerParameters = innerParameters.add("burnToken", Strings.toHexString($.burnToken));
        innerParameters = innerParameters.add("destinationCaller", Strings.toHexString($.destinationCaller));
        innerParameters = innerParameters.add("maxFee", "0");
        innerParameters = innerParameters.add("minFinalityThreshold", "2000");

        descriptions[iterator++] = JsonLibrary.toJson(
            string(
                abi.encodePacked(
                    "TokenMessenger.depositForBurn(anyInt, ",
                    "destinationDomain=",
                    $.targetChainName,
                    ", ",
                    "mintRecipient=",
                    $.subvaultTargetName,
                    ", ",
                    "burnToken=",
                    IERC20Metadata($.burnToken).symbol(),
                    ", ",
                    "destinationCaller=",
                    Strings.toHexString($.destinationCaller),
                    ", maxFee=0, minFinalityThreshold=2000",
                    ")"
                )
            ),
            ABILibrary.getABI(ITokenMessenger.depositForBurn.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.tokenMessenger), "0"),
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
            tmp[i++] = Call(
                $.curator,
                $.tokenMessenger,
                0,
                abi.encodeCall(
                    ITokenMessenger.depositForBurn,
                    (
                        0,
                        $.destinationDomain,
                        addressToBytes32($.subvaultTarget),
                        $.burnToken,
                        addressToBytes32($.destinationCaller),
                        0,
                        2000
                    )
                ),
                true
            );
            tmp[i++] = Call(
                $.curator,
                $.tokenMessenger,
                0,
                abi.encodeCall(
                    ITokenMessenger.depositForBurn,
                    (
                        1e6,
                        $.destinationDomain,
                        addressToBytes32($.subvaultTarget),
                        $.burnToken,
                        addressToBytes32($.destinationCaller),
                        0,
                        2000
                    )
                ),
                true
            );
            tmp[i++] = Call(
                $.curator,
                $.tokenMessenger,
                1 wei,
                abi.encodeCall(
                    ITokenMessenger.depositForBurn,
                    (
                        0,
                        $.destinationDomain,
                        addressToBytes32($.subvaultTarget),
                        $.burnToken,
                        addressToBytes32($.destinationCaller),
                        0,
                        2000
                    )
                ),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.tokenMessenger,
                0,
                abi.encodeCall(
                    ITokenMessenger.depositForBurn,
                    (
                        1e6,
                        $.destinationDomain + 1,
                        addressToBytes32($.subvaultTarget),
                        $.burnToken,
                        addressToBytes32($.destinationCaller),
                        0,
                        2000
                    )
                ),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.tokenMessenger,
                0,
                abi.encodeCall(
                    ITokenMessenger.depositForBurn,
                    (
                        1e6,
                        $.destinationDomain,
                        addressToBytes32(address(0xdead)),
                        $.burnToken,
                        addressToBytes32($.destinationCaller),
                        0,
                        2000
                    )
                ),
                false // bad call
            );
            tmp[i++] = Call(
                $.curator,
                $.tokenMessenger,
                0,
                abi.encodeCall(
                    ITokenMessenger.depositForBurn,
                    (
                        1e6,
                        $.destinationDomain,
                        addressToBytes32($.subvaultTarget),
                        address(0xdead),
                        addressToBytes32($.destinationCaller),
                        0,
                        2000
                    )
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
                    $.burnToken,
                    address(0),
                    0,
                    2000
                ),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.tokenMessenger,
                0,
                abi.encodeCall(
                    ITokenMessenger.depositForBurn,
                    (
                        0,
                        $.destinationDomain,
                        addressToBytes32($.subvaultTarget),
                        $.burnToken,
                        addressToBytes32($.destinationCaller),
                        1,
                        2000
                    )
                ),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.tokenMessenger,
                0,
                abi.encodeCall(
                    ITokenMessenger.depositForBurn,
                    (
                        0,
                        $.destinationDomain,
                        addressToBytes32($.subvaultTarget),
                        $.burnToken,
                        addressToBytes32($.destinationCaller),
                        0,
                        1000
                    )
                ),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.tokenMessenger,
                0,
                abi.encodeCall(
                    ITokenMessenger.depositForBurn,
                    (
                        0,
                        $.destinationDomain,
                        addressToBytes32($.subvaultTarget),
                        $.burnToken,
                        bytes32(uint256(0xdead)),
                        0,
                        2000
                    )
                ),
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
