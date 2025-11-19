// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/utils/Strings.sol";

import {ABILibrary} from "../ABILibrary.sol";
import {JsonLibrary} from "../JsonLibrary.sol";
import {ParameterLibrary} from "../ParameterLibrary.sol";

import "../ArraysLibrary.sol";
import "../ProofLibrary.sol";
import "../protocols/ERC20Library.sol";

import "../interfaces/ISubRedManagement.sol";
import "../interfaces/Imports.sol";

library DigiFTILibrary {
    using ParameterLibrary for ParameterLibrary.Parameter[];

    struct Info {
        address curator;
        address subRedManagement;
        address stToken;
        address currencyToken;
    }

    function getDigiFTProofs(BitmaskVerifier bitmaskVerifier, Info memory $)
        internal
        pure
        returns (IVerifier.VerificationPayload[] memory leaves)
    {
        leaves = new IVerifier.VerificationPayload[](50);
        uint256 iterator;

        /// @dev approve stToken/currencyToken to SubRedManagement
        iterator = ArraysLibrary.insert(
            leaves,
            ERC20Library.getERC20Proofs(
                bitmaskVerifier,
                ERC20Library.Info({
                    curator: $.curator,
                    assets: ArraysLibrary.makeAddressArray(abi.encode($.stToken, $.currencyToken)),
                    to: ArraysLibrary.makeAddressArray(abi.encode($.subRedManagement, $.subRedManagement))
                })
            ),
            iterator
        );

        leaves[iterator++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.subRedManagement,
            0,
            abi.encodeCall(ISubRedManagement.subscribe, ($.stToken, $.currencyToken, 0, 0)),
            ProofLibrary.makeBitmask(
                true,
                true,
                true,
                true,
                abi.encodeCall(
                    ISubRedManagement.subscribe, (address(type(uint160).max), address(type(uint160).max), 0, 0)
                )
            )
        );

        leaves[iterator++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.subRedManagement,
            0,
            abi.encodeCall(ISubRedManagement.redeem, ($.stToken, $.currencyToken, 0, 0)),
            ProofLibrary.makeBitmask(
                true,
                true,
                true,
                true,
                abi.encodeCall(ISubRedManagement.redeem, (address(type(uint160).max), address(type(uint160).max), 0, 0))
            )
        );
        assembly {
            mstore(leaves, iterator)
        }
    }

    function getDigiFTDescriptions(Info memory $) internal view returns (string[] memory descriptions) {
        uint256 iterator;
        descriptions = new string[](50);
        ParameterLibrary.Parameter[] memory innerParameters;

        /// @dev approve stToken/currencyToken to SubRedManagement
        iterator = ArraysLibrary.insert(
            descriptions,
            ERC20Library.getERC20Descriptions(
                ERC20Library.Info({
                    curator: $.curator,
                    assets: ArraysLibrary.makeAddressArray(abi.encode($.stToken, $.currencyToken)),
                    to: ArraysLibrary.makeAddressArray(abi.encode($.subRedManagement, $.subRedManagement))
                })
            ),
            iterator
        );

        string memory stTokenSymbol = IERC20Metadata($.stToken).symbol();
        string memory currencyTokenSymbol = IERC20Metadata($.currencyToken).symbol();
        /// @dev subscribe stToken in SubRedManagement
        {
            innerParameters = ParameterLibrary.build("stToken", Strings.toHexString($.stToken)).add(
                "currencyToken", Strings.toHexString($.currencyToken)
            ).addAny("amount").addAny("deadline");
            descriptions[iterator++] = JsonLibrary.toJson(
                string(
                    abi.encodePacked(
                        "ISubRedManagement(SubRedManagement).subscribe(",
                        stTokenSymbol,
                        ", ",
                        currencyTokenSymbol,
                        ", anyInt, anyInt)"
                    )
                ),
                ABILibrary.getABI(ISubRedManagement.subscribe.selector),
                ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.subRedManagement), "0"),
                innerParameters
            );
        }
        /// @dev redeem stToken in SubRedManagement
        {
            innerParameters = ParameterLibrary.build("stToken", Strings.toHexString($.stToken)).add(
                "currencyToken", Strings.toHexString($.currencyToken)
            ).addAny("quantity").addAny("deadline");
            descriptions[iterator++] = JsonLibrary.toJson(
                string(
                    abi.encodePacked(
                        "ISubRedManagement(SubRedManagement).redeem(",
                        stTokenSymbol,
                        ", ",
                        currencyTokenSymbol,
                        ", anyInt, anyInt)"
                    )
                ),
                ABILibrary.getABI(ISubRedManagement.redeem.selector),
                ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.subRedManagement), "0"),
                innerParameters
            );
        }
        assembly {
            mstore(descriptions, iterator)
        }
    }

    function getDigiFTCalls(Info memory $) internal pure returns (Call[][] memory calls) {
        uint256 index;
        calls = new Call[][](50);

        /// @dev approve stToken/currencyToken to SubRedManagement
        index = ArraysLibrary.insert(
            calls,
            ERC20Library.getERC20Calls(
                ERC20Library.Info({
                    curator: $.curator,
                    assets: ArraysLibrary.makeAddressArray(abi.encode($.stToken, $.currencyToken)),
                    to: ArraysLibrary.makeAddressArray(abi.encode($.subRedManagement, $.subRedManagement))
                })
            ),
            index
        );
        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] = Call(
                $.curator,
                $.subRedManagement,
                0,
                abi.encodeCall(ISubRedManagement.subscribe, ($.stToken, $.currencyToken, 0, 0)),
                true
            );
            tmp[i++] = Call(
                $.curator,
                $.subRedManagement,
                0,
                abi.encodeCall(ISubRedManagement.subscribe, ($.stToken, $.currencyToken, 1 ether, 0)),
                true
            );
            tmp[i++] = Call(
                $.curator,
                $.subRedManagement,
                0,
                abi.encodeCall(ISubRedManagement.subscribe, ($.stToken, $.currencyToken, 0, 1234567890)),
                true
            );
            tmp[i++] = Call(
                $.curator,
                $.subRedManagement,
                1 wei,
                abi.encodeCall(ISubRedManagement.subscribe, ($.stToken, $.currencyToken, 0, 0)),
                false
            );
            tmp[i++] = Call(
                address(0xdead),
                $.subRedManagement,
                0,
                abi.encodeCall(ISubRedManagement.subscribe, ($.stToken, $.currencyToken, 0, 0)),
                false
            );
            tmp[i++] = Call(
                $.curator,
                address(0xdead),
                0,
                abi.encodeCall(ISubRedManagement.subscribe, ($.stToken, $.currencyToken, 0, 0)),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.subRedManagement,
                0,
                abi.encodeCall(ISubRedManagement.subscribe, (address(0xdead), $.currencyToken, 0, 0)),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.subRedManagement,
                0,
                abi.encodeCall(ISubRedManagement.subscribe, ($.stToken, address(0xdead), 0, 0)),
                false
            );
            assembly {
                mstore(tmp, i)
            }
            calls[index++] = tmp;
        }

        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] = Call(
                $.curator,
                $.subRedManagement,
                0,
                abi.encodeCall(ISubRedManagement.redeem, ($.stToken, $.currencyToken, 0, 0)),
                true
            );
            tmp[i++] = Call(
                $.curator,
                $.subRedManagement,
                0,
                abi.encodeCall(ISubRedManagement.redeem, ($.stToken, $.currencyToken, 1 ether, 0)),
                true
            );
            tmp[i++] = Call(
                $.curator,
                $.subRedManagement,
                0,
                abi.encodeCall(ISubRedManagement.redeem, ($.stToken, $.currencyToken, 0, 1 ether)),
                true
            );
            tmp[i++] = Call(
                $.curator,
                $.subRedManagement,
                1 wei,
                abi.encodeCall(ISubRedManagement.redeem, ($.stToken, $.currencyToken, 0, 0)),
                false
            );
            tmp[i++] = Call(
                address(0xdead),
                $.subRedManagement,
                0,
                abi.encodeCall(ISubRedManagement.redeem, ($.stToken, $.currencyToken, 0, 0)),
                false
            );
            tmp[i++] = Call(
                $.curator,
                address(0xdead),
                0,
                abi.encodeCall(ISubRedManagement.redeem, ($.stToken, $.currencyToken, 0, 0)),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.subRedManagement,
                0,
                abi.encodeCall(ISubRedManagement.redeem, (address(0xdead), $.currencyToken, 0, 0)),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.subRedManagement,
                0,
                abi.encodeCall(ISubRedManagement.redeem, ($.stToken, address(0xdead), 0, 0)),
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

        return calls;
    }
}
