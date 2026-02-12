// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/utils/Strings.sol";

import "../../ethereum/Constants.sol";
import {ABILibrary} from "../ABILibrary.sol";
import {ArraysLibrary} from "../ArraysLibrary.sol";
import {JsonLibrary} from "../JsonLibrary.sol";
import {ParameterLibrary} from "../ParameterLibrary.sol";

import "../ProofLibrary.sol";
import "../interfaces/Imports.sol";
import {ERC20Library} from "./ERC20Library.sol";

import {IMezoBridge} from "../interfaces/IMezoBridge.sol";

library MezoBridgeLibrary {
    using ParameterLibrary for ParameterLibrary.Parameter[];
    using ArraysLibrary for IVerifier.VerificationPayload[];
    using ArraysLibrary for string[];
    using ArraysLibrary for Call[][];

    struct Info {
        address curator;
        address dstSubvault;
        string dstSubvaultName;
        address[] assets;
        address bridge;
    }

    function makeDuplicates(address addr, uint256 count) internal pure returns (address[] memory addrs) {
        addrs = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            addrs[i] = addr;
        }
    }

    function getMezoBridgeProofs(BitmaskVerifier bitmaskVerifier, Info memory $)
        internal
        pure
        returns (IVerifier.VerificationPayload[] memory leaves)
    {
        leaves = new IVerifier.VerificationPayload[](20);
        uint256 iterator;

        iterator = leaves.insert(
            ERC20Library.getERC20Proofs(
                bitmaskVerifier,
                ERC20Library.Info({curator: $.curator, assets: $.assets, to: makeDuplicates($.bridge, $.assets.length)})
            ),
            iterator
        );

        for (uint256 id = 0; id < $.assets.length; id++) {
            address asset = $.assets[id];
            if (asset == Constants.TBTC) {
                // bridged as native BTC on Mezo
                leaves[iterator++] = ProofLibrary.makeVerificationPayload(
                    bitmaskVerifier,
                    $.curator,
                    $.bridge,
                    0,
                    abi.encodeCall(IMezoBridge.bridgeTBTC, (0, $.dstSubvault)),
                    ProofLibrary.makeBitmask(
                        true, true, true, true, abi.encodeCall(IMezoBridge.bridgeTBTC, (0, address(type(uint160).max)))
                    )
                );
            } else {
                // bridged as bridged version on Mezo
                // list here https://mezo.org/docs/users/resources/contracts-reference#bridged-tokens
                leaves[iterator++] = ProofLibrary.makeVerificationPayload(
                    bitmaskVerifier,
                    $.curator,
                    $.bridge,
                    0,
                    abi.encodeCall(IMezoBridge.bridgeERC20, (asset, 0, $.dstSubvault)),
                    ProofLibrary.makeBitmask(
                        true,
                        true,
                        true,
                        true,
                        abi.encodeCall(
                            IMezoBridge.bridgeERC20, (address(type(uint160).max), 0, address(type(uint160).max))
                        )
                    )
                );
            }
        }
        assembly {
            mstore(leaves, iterator)
        }
    }

    function getMezoBridgeDescriptions(Info memory $) internal view returns (string[] memory descriptions) {
        descriptions = new string[](20);
        uint256 iterator;

        iterator = descriptions.insert(
            ERC20Library.getERC20Descriptions(
                ERC20Library.Info({curator: $.curator, assets: $.assets, to: makeDuplicates($.bridge, $.assets.length)})
            ),
            iterator
        );

        for (uint256 id = 0; id < $.assets.length; id++) {
            address asset = $.assets[id];
            if (asset == Constants.TBTC) {
                // bridged as native BTC on Mezo
                descriptions[iterator++] = JsonLibrary.toJson(
                    string(
                        abi.encodePacked(
                            "IMezoBridge(",
                            Strings.toHexString($.bridge),
                            ").bridgeTBTC(anyInt, subvault=",
                            $.dstSubvaultName,
                            ")"
                        )
                    ),
                    ABILibrary.getABI(IMezoBridge.bridgeTBTC.selector),
                    ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.bridge), "0"),
                    ParameterLibrary.buildAny("amount").add("recipient", Strings.toHexString($.dstSubvault))
                );
            } else {
                // bridged as bridged version on Mezo
                // list here https://mezo.org/docs/users/resources/contracts-reference#bridged-tokens
                descriptions[iterator++] = JsonLibrary.toJson(
                    string(
                        abi.encodePacked(
                            "IMezoBridge(",
                            Strings.toHexString($.bridge),
                            ").bridgeERC20(",
                            "asset=",
                            IERC20Metadata(asset).symbol(),
                            ", anyInt, subvault=",
                            $.dstSubvaultName,
                            ")"
                        )
                    ),
                    ABILibrary.getABI(IMezoBridge.bridgeERC20.selector),
                    ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.bridge), "0"),
                    ParameterLibrary.build("asset", Strings.toHexString(asset)).addAny("amount").add(
                        "recipient", Strings.toHexString($.dstSubvault)
                    )
                );
            }
        }
        assembly {
            mstore(descriptions, iterator)
        }
    }

    function getMezoBridgeCalls(Info memory $) internal pure returns (Call[][] memory calls) {
        calls = new Call[][](20);
        uint256 index;

        index = calls.insert(
            ERC20Library.getERC20Calls(
                ERC20Library.Info({curator: $.curator, assets: $.assets, to: makeDuplicates($.bridge, $.assets.length)})
            ),
            index
        );

        for (uint256 id = 0; id < $.assets.length; id++) {
            address asset = $.assets[id];
            Call[] memory tmp = new Call[](16);
            uint256 i;

            if (asset == Constants.TBTC) {
                // bridged as native BTC on Mezo
                tmp[i++] =
                    Call($.curator, $.bridge, 0, abi.encodeCall(IMezoBridge.bridgeTBTC, (0, $.dstSubvault)), true);

                tmp[i++] =
                    Call($.curator, $.bridge, 0, abi.encodeCall(IMezoBridge.bridgeTBTC, (1 ether, $.dstSubvault)), true);

                tmp[i++] = Call(
                    $.curator, $.bridge, 1 wei, abi.encodeCall(IMezoBridge.bridgeTBTC, (1 ether, $.dstSubvault)), false
                );

                tmp[i++] = Call(
                    address(0xdead),
                    $.bridge,
                    0,
                    abi.encodeCall(IMezoBridge.bridgeTBTC, (1 ether, $.dstSubvault)),
                    false
                );

                tmp[i++] = Call(
                    $.curator,
                    address(0xdead),
                    0,
                    abi.encodeCall(IMezoBridge.bridgeTBTC, (1 ether, $.dstSubvault)),
                    false
                );

                tmp[i++] = Call(
                    $.curator, $.bridge, 0, abi.encodeCall(IMezoBridge.bridgeTBTC, (1 ether, address(0xdead))), false
                );

                tmp[i++] = Call(
                    $.curator, $.bridge, 0, abi.encode(IMezoBridge.bridgeTBTC.selector, 1 ether, $.dstSubvault), false
                );
            } else {
                // bridged as bridged version on Mezo
                // list here https://mezo.org/docs/users/resources/contracts-reference#bridged-tokens

                tmp[i++] = Call(
                    $.curator, $.bridge, 0, abi.encodeCall(IMezoBridge.bridgeERC20, (asset, 0, $.dstSubvault)), true
                );

                tmp[i++] = Call(
                    $.curator,
                    $.bridge,
                    0,
                    abi.encodeCall(IMezoBridge.bridgeERC20, (asset, 1 ether, $.dstSubvault)),
                    true
                );

                tmp[i++] = Call(
                    $.curator,
                    $.bridge,
                    1 wei,
                    abi.encodeCall(IMezoBridge.bridgeERC20, (asset, 1 ether, $.dstSubvault)),
                    false
                );

                tmp[i++] = Call(
                    address(0xdead),
                    $.bridge,
                    0,
                    abi.encodeCall(IMezoBridge.bridgeERC20, (asset, 1 ether, $.dstSubvault)),
                    false
                );

                tmp[i++] = Call(
                    $.curator,
                    address(0xdead),
                    0,
                    abi.encodeCall(IMezoBridge.bridgeERC20, (asset, 1 ether, $.dstSubvault)),
                    false
                );

                tmp[i++] = Call(
                    $.curator,
                    $.bridge,
                    0,
                    abi.encodeCall(IMezoBridge.bridgeERC20, (address(0xdead), 1 ether, $.dstSubvault)),
                    false
                );

                tmp[i++] = Call(
                    $.curator,
                    $.bridge,
                    0,
                    abi.encodeCall(IMezoBridge.bridgeERC20, (asset, 1 ether, address(0xdead))),
                    false
                );

                tmp[i++] = Call(
                    $.curator,
                    $.bridge,
                    0,
                    abi.encode(IMezoBridge.bridgeERC20.selector, asset, 1 ether, $.dstSubvault),
                    false
                );
            }

            assembly {
                mstore(tmp, i)
            }
            calls[index++] = tmp;
        }

        assembly {
            mstore(calls, index)
        }
    }
}
