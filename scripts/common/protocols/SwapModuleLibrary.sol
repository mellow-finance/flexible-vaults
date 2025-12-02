// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/utils/Strings.sol";

import "../../../src/interfaces/utils/ISwapModule.sol";
import {ABILibrary} from "../ABILibrary.sol";
import {JsonLibrary} from "../JsonLibrary.sol";
import {ParameterLibrary} from "../ParameterLibrary.sol";
import "../ProofLibrary.sol";
import "../interfaces/Imports.sol";

library SwapModuleLibrary {
    using ParameterLibrary for ParameterLibrary.Parameter[];

    struct Info {
        address subvault;
        string subvaultName;
        address swapModule;
        address[] curators;
        address[] assets;
    }

    function getSwapModuleProofs(BitmaskVerifier bitmaskVerifier, Info memory $)
        internal
        pure
        returns (IVerifier.VerificationPayload[] memory leaves)
    {
        /*  
            1. assets[i].approve(swapModule)
            2. swapModule.pushAssets(assets[i], any)
            3. swapModule.pullAssets(assets[i], any)
            
            or 

            1. swapModule.pushAssets{value: x=any}(ETH, x)
            2. swapModule.pullAssets{value: x=any}(ETH, x)
        */

        uint256 length = 3 * $.assets.length * $.curators.length;
        leaves = new IVerifier.VerificationPayload[](length);
        uint256 iterator = 0;

        for (uint256 i = 0; i < $.curators.length; i++) {
            for (uint256 j = 0; j < $.assets.length; j++) {
                if ($.assets[j] == TransferLibrary.ETH) {
                    leaves[iterator++] = ProofLibrary.makeVerificationPayload(
                        bitmaskVerifier,
                        $.curators[i],
                        $.swapModule,
                        0,
                        abi.encodeCall(ISwapModule.pushAssets, ($.assets[j], 0)),
                        ProofLibrary.makeBitmask(
                            true,
                            true,
                            false,
                            true,
                            abi.encodeCall(ISwapModule.pushAssets, (address(type(uint160).max), 0))
                        )
                    );

                    leaves[iterator++] = ProofLibrary.makeVerificationPayload(
                        bitmaskVerifier,
                        $.curators[i],
                        $.swapModule,
                        0,
                        abi.encodeCall(ISwapModule.pullAssets, ($.assets[j], 0)),
                        ProofLibrary.makeBitmask(
                            true,
                            true,
                            true,
                            true,
                            abi.encodeCall(ISwapModule.pullAssets, (address(type(uint160).max), 0))
                        )
                    );
                } else {
                    leaves[iterator++] = ProofLibrary.makeVerificationPayload(
                        bitmaskVerifier,
                        $.curators[i],
                        $.assets[j],
                        0,
                        abi.encodeCall(IERC20.approve, ($.swapModule, 0)),
                        ProofLibrary.makeBitmask(
                            true, true, true, true, abi.encodeCall(IERC20.approve, (address(type(uint160).max), 0))
                        )
                    );

                    leaves[iterator++] = ProofLibrary.makeVerificationPayload(
                        bitmaskVerifier,
                        $.curators[i],
                        $.swapModule,
                        0,
                        abi.encodeCall(ISwapModule.pushAssets, ($.assets[j], 0)),
                        ProofLibrary.makeBitmask(
                            true,
                            true,
                            true,
                            true,
                            abi.encodeCall(ISwapModule.pushAssets, (address(type(uint160).max), 0))
                        )
                    );

                    leaves[iterator++] = ProofLibrary.makeVerificationPayload(
                        bitmaskVerifier,
                        $.curators[i],
                        $.swapModule,
                        0,
                        abi.encodeCall(ISwapModule.pullAssets, ($.assets[j], 0)),
                        ProofLibrary.makeBitmask(
                            true,
                            true,
                            true,
                            true,
                            abi.encodeCall(ISwapModule.pullAssets, (address(type(uint160).max), 0))
                        )
                    );
                }
            }
        }

        assembly {
            mstore(leaves, iterator)
        }
    }

    function getSwapModuleDescriptions(Info memory $) internal view returns (string[] memory descriptions) {
        uint256 length = 3 * $.assets.length * $.curators.length;
        descriptions = new string[](length);
        uint256 iterator = 0;

        ParameterLibrary.Parameter[] memory innerParameters;

        for (uint256 i = 0; i < $.curators.length; i++) {
            for (uint256 j = 0; j < $.assets.length; j++) {
                if ($.assets[j] == TransferLibrary.ETH) {
                    string memory assetName = "ETH";
                    innerParameters = ParameterLibrary.add2("asset", Strings.toHexString($.assets[j]), "value", "any");
                    descriptions[iterator++] = JsonLibrary.toJson(
                        string(
                            abi.encodePacked(
                                "ISwapModule(",
                                Strings.toHexString($.swapModule),
                                ").pushAssets{value: any}(",
                                assetName,
                                ", msg.value)"
                            )
                        ),
                        ABILibrary.getABI(ISwapModule.pushAssets.selector),
                        ParameterLibrary.build(
                            Strings.toHexString($.curators[i]), Strings.toHexString($.swapModule), "any"
                        ),
                        innerParameters
                    );
                    descriptions[iterator++] = JsonLibrary.toJson(
                        string(
                            abi.encodePacked(
                                "ISwapModule(",
                                Strings.toHexString($.swapModule),
                                ").pullAssets(",
                                assetName,
                                ", msg.value)"
                            )
                        ),
                        ABILibrary.getABI(ISwapModule.pullAssets.selector),
                        ParameterLibrary.build(
                            Strings.toHexString($.curators[i]), Strings.toHexString($.swapModule), "0"
                        ),
                        innerParameters
                    );
                } else {
                    string memory assetName = IERC20Metadata($.assets[j]).symbol();
                    innerParameters = ParameterLibrary.add2("to", Strings.toHexString($.swapModule), "value", "any");
                    descriptions[iterator++] = JsonLibrary.toJson(
                        string(
                            abi.encodePacked(
                                "IERC20(",
                                assetName,
                                ").approve( ISwapModule(",
                                Strings.toHexString($.swapModule),
                                "), any)"
                            )
                        ),
                        ABILibrary.getABI(IERC20.approve.selector),
                        ParameterLibrary.build(
                            Strings.toHexString($.curators[i]), Strings.toHexString($.assets[j]), "0"
                        ),
                        innerParameters
                    );
                    innerParameters = ParameterLibrary.add2("asset", Strings.toHexString($.assets[j]), "value", "any");
                    descriptions[iterator++] = JsonLibrary.toJson(
                        string(
                            abi.encodePacked(
                                "ISwapModule(", Strings.toHexString($.swapModule), ").pushAssets(", assetName, ", any)"
                            )
                        ),
                        ABILibrary.getABI(ISwapModule.pushAssets.selector),
                        ParameterLibrary.build(
                            Strings.toHexString($.curators[i]), Strings.toHexString($.swapModule), "0"
                        ),
                        innerParameters
                    );
                    descriptions[iterator++] = JsonLibrary.toJson(
                        string(
                            abi.encodePacked(
                                "ISwapModule(", Strings.toHexString($.swapModule), ").pullAssets(", assetName, ", any)"
                            )
                        ),
                        ABILibrary.getABI(ISwapModule.pullAssets.selector),
                        ParameterLibrary.build(
                            Strings.toHexString($.curators[i]), Strings.toHexString($.swapModule), "0"
                        ),
                        innerParameters
                    );
                }
            }
        }

        assembly {
            mstore(descriptions, iterator)
        }
    }

    function getSwapModuleCalls(Info memory $) internal pure returns (Call[][] memory calls) {
        uint256 length = 3 * $.assets.length * $.curators.length;

        uint256 iterator = 0;
        calls = new Call[][](length);

        for (uint256 itr = 0; itr < $.curators.length; itr++) {
            for (uint256 j = 0; j < $.assets.length; j++) {
                address curator = $.curators[itr];
                if ($.assets[j] == TransferLibrary.ETH) {
                    {
                        Call[] memory tmp = new Call[](16);
                        uint256 i = 0;
                        tmp[i++] = Call(
                            curator, $.swapModule, 0, abi.encodeCall(ISwapModule.pushAssets, ($.assets[j], 0)), true
                        );
                        tmp[i++] = Call(
                            curator, $.swapModule, 1 wei, abi.encodeCall(ISwapModule.pushAssets, ($.assets[j], 0)), true
                        );
                        tmp[i++] = Call(
                            curator, $.swapModule, 0, abi.encodeCall(ISwapModule.pushAssets, ($.assets[j], 1 wei)), true
                        );

                        tmp[i++] = Call(
                            address(0xdead),
                            $.swapModule,
                            0,
                            abi.encodeCall(ISwapModule.pushAssets, ($.assets[j], 0)),
                            false
                        );
                        tmp[i++] = Call(
                            curator, address(0xdead), 0, abi.encodeCall(ISwapModule.pushAssets, ($.assets[j], 0)), false
                        );
                        tmp[i++] = Call(
                            curator,
                            $.swapModule,
                            0,
                            abi.encodeCall(ISwapModule.pushAssets, (address(0xdead), 0)),
                            false
                        );
                        tmp[i++] = Call(
                            curator, $.swapModule, 0, abi.encode(ISwapModule.pushAssets.selector, $.assets[j], 0), false
                        );
                        assembly {
                            mstore(tmp, i)
                        }
                        calls[iterator++] = tmp;
                    }

                    {
                        Call[] memory tmp = new Call[](16);
                        uint256 i = 0;
                        tmp[i++] = Call(
                            curator, $.swapModule, 0, abi.encodeCall(ISwapModule.pullAssets, ($.assets[j], 0)), true
                        );
                        tmp[i++] = Call(
                            curator,
                            $.swapModule,
                            0,
                            abi.encodeCall(ISwapModule.pullAssets, ($.assets[j], 1 ether)),
                            true
                        );

                        tmp[i++] = Call(
                            address(0xdead),
                            $.swapModule,
                            0,
                            abi.encodeCall(ISwapModule.pullAssets, ($.assets[j], 1 ether)),
                            false
                        );
                        tmp[i++] = Call(
                            curator,
                            address(0xdead),
                            0,
                            abi.encodeCall(ISwapModule.pullAssets, ($.assets[j], 1 ether)),
                            false
                        );
                        tmp[i++] = Call(
                            curator,
                            $.swapModule,
                            1 wei,
                            abi.encodeCall(ISwapModule.pullAssets, ($.assets[j], 1 ether)),
                            false
                        );
                        tmp[i++] = Call(
                            curator,
                            $.swapModule,
                            0,
                            abi.encodeCall(ISwapModule.pullAssets, (address(0xdead), 1 ether)),
                            false
                        );
                        tmp[i++] = Call(
                            curator,
                            $.swapModule,
                            0,
                            abi.encode(ISwapModule.pullAssets.selector, $.assets[j], 1 ether),
                            false
                        );

                        assembly {
                            mstore(tmp, i)
                        }
                        calls[iterator++] = tmp;
                    }
                } else {
                    {
                        Call[] memory tmp = new Call[](16);
                        uint256 i = 0;
                        tmp[i++] =
                            Call(curator, $.assets[j], 0, abi.encodeCall(IERC20.approve, ($.swapModule, 0)), true);
                        tmp[i++] =
                            Call(curator, $.assets[j], 0, abi.encodeCall(IERC20.approve, ($.swapModule, 1 ether)), true);

                        tmp[i++] = Call(
                            address(0xdead),
                            $.assets[j],
                            0,
                            abi.encodeCall(IERC20.approve, ($.swapModule, 1 ether)),
                            false
                        );
                        tmp[i++] = Call(
                            curator, address(0xdead), 0, abi.encodeCall(IERC20.approve, ($.swapModule, 1 ether)), false
                        );
                        tmp[i++] = Call(
                            curator, $.assets[j], 1 wei, abi.encodeCall(IERC20.approve, ($.swapModule, 1 ether)), false
                        );
                        tmp[i++] = Call(
                            curator, $.assets[j], 0, abi.encodeCall(IERC20.approve, (address(0xdead), 1 ether)), false
                        );
                        tmp[i++] = Call(
                            curator, $.assets[j], 0, abi.encode(IERC20.approve.selector, $.swapModule, 1 ether), false
                        );

                        assembly {
                            mstore(tmp, i)
                        }
                        calls[iterator++] = tmp;
                    }

                    {
                        Call[] memory tmp = new Call[](16);
                        uint256 i = 0;
                        tmp[i++] = Call(
                            curator, $.swapModule, 0, abi.encodeCall(ISwapModule.pushAssets, ($.assets[j], 0)), true
                        );
                        tmp[i++] = Call(
                            curator, $.swapModule, 0, abi.encodeCall(ISwapModule.pushAssets, ($.assets[j], 1 wei)), true
                        );

                        tmp[i++] = Call(
                            curator,
                            $.swapModule,
                            1 wei,
                            abi.encodeCall(ISwapModule.pushAssets, ($.assets[j], 0)),
                            false
                        );
                        tmp[i++] = Call(
                            address(0xdead),
                            $.swapModule,
                            0,
                            abi.encodeCall(ISwapModule.pushAssets, ($.assets[j], 0)),
                            false
                        );
                        tmp[i++] = Call(
                            curator, address(0xdead), 0, abi.encodeCall(ISwapModule.pushAssets, ($.assets[j], 0)), false
                        );
                        tmp[i++] = Call(
                            curator,
                            $.swapModule,
                            0,
                            abi.encodeCall(ISwapModule.pushAssets, (address(0xdead), 0)),
                            false
                        );
                        tmp[i++] = Call(
                            curator, $.swapModule, 0, abi.encode(ISwapModule.pushAssets.selector, $.assets[j], 0), false
                        );
                        assembly {
                            mstore(tmp, i)
                        }
                        calls[iterator++] = tmp;
                    }

                    {
                        Call[] memory tmp = new Call[](16);
                        uint256 i = 0;
                        tmp[i++] = Call(
                            curator, $.swapModule, 0, abi.encodeCall(ISwapModule.pullAssets, ($.assets[j], 0)), true
                        );
                        tmp[i++] = Call(
                            curator,
                            $.swapModule,
                            0,
                            abi.encodeCall(ISwapModule.pullAssets, ($.assets[j], 1 ether)),
                            true
                        );

                        tmp[i++] = Call(
                            address(0xdead),
                            $.swapModule,
                            0,
                            abi.encodeCall(ISwapModule.pullAssets, ($.assets[j], 1 ether)),
                            false
                        );
                        tmp[i++] = Call(
                            curator,
                            address(0xdead),
                            0,
                            abi.encodeCall(ISwapModule.pullAssets, ($.assets[j], 1 ether)),
                            false
                        );
                        tmp[i++] = Call(
                            curator,
                            $.swapModule,
                            1 wei,
                            abi.encodeCall(ISwapModule.pullAssets, ($.assets[j], 1 ether)),
                            false
                        );
                        tmp[i++] = Call(
                            curator,
                            $.swapModule,
                            0,
                            abi.encodeCall(ISwapModule.pullAssets, (address(0xdead), 1 ether)),
                            false
                        );
                        tmp[i++] = Call(
                            curator,
                            $.swapModule,
                            0,
                            abi.encode(ISwapModule.pullAssets.selector, $.assets[j], 1 ether),
                            false
                        );

                        assembly {
                            mstore(tmp, i)
                        }
                        calls[iterator++] = tmp;
                    }
                }
            }
        }

        assembly {
            mstore(calls, iterator)
        }
    }
}
